import Foundation
import CoreServices

protocol FileWatcherDelegate: AnyObject {
    func fileWatcher(_ watcher: FileWatcher, didDetectNewFiles files: [URL])
}

final class FileWatcher {
    weak var delegate: FileWatcherDelegate?

    private var eventStream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private let watchQueue = DispatchQueue(label: "com.traart.filewatcher", qos: .utility)
    private let stateQueue = DispatchQueue(label: "com.traart.filewatcher.state", attributes: .concurrent)

    private var _detectedFiles: [URL] = []
    private var seenFiles: Set<String> = [] // path + modification date key

    private var diskWatcherProcess: Process?
    private var periodicTimer: Timer?
    private var startTime: Date = Date() // Only report files modified after app start
    private var initialScanDone: Bool = false
    private var monitoredFolders: [URL] = [] // Actual folders being scanned

    // Cached watcher-relevant settings to avoid needless restarts
    private var lastWatchedFolders: [String] = []
    private var lastMonitorEntireDisk: Bool = false
    private var lastMonitoredFileTypes: String = "audio"

    private static let audioExtensions: Set<String> = [
        "wav", "mp3", "m4a", "flac", "ogg", "oga", "opus",
        "aac", "wma", "amr", "m4b", "mp2", "aiff", "aif"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mkv", "webm", "mov", "avi", "wmv", "m4v"
    ]
    private static let mediaExtensions: Set<String> = audioExtensions.union(videoExtensions)

    /// Active extensions based on user's monitoredFileTypes setting
    private var activeExtensions: Set<String> {
        switch SettingsManager.shared.monitoredFileTypes {
        case "audio": return Self.audioExtensions
        case "video": return Self.videoExtensions
        default: return Self.mediaExtensions
        }
    }

    var detectedFiles: [URL] {
        stateQueue.sync { _detectedFiles }
    }

    func start() {
        stop()
        // Don't reset startTime on settings-change restarts — keep the original
        // creation time so files created since app launch are still detected.
        // startTime is set once at FileWatcher init (line 21).
        initialScanDone = false

        let settings = SettingsManager.shared

        // Cache watcher-relevant settings for change detection
        lastWatchedFolders = settings.watchedFolders.map { $0.path }
        lastMonitorEntireDisk = settings.monitorEntireDisk
        lastMonitoredFileTypes = settings.monitoredFileTypes

        // Filter to only accessible folders to avoid repeated permission dialogs
        let accessibleFolders = settings.watchedFolders.filter { isFolderAccessible($0) }

        // Determine the actual folders to scan.
        // When monitorEntireDisk is on, scan common user directories
        // (these are the same paths FSEventStream fallback monitors).
        if settings.monitorEntireDisk {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let commonFolders = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Desktop"),
            ]
            var allFolders = accessibleFolders
            for folder in commonFolders where isFolderAccessible(folder) {
                if !allFolders.contains(where: { $0.path == folder.path }) {
                    allFolders.append(folder)
                }
            }
            monitoredFolders = allFolders
        } else {
            monitoredFolders = accessibleFolders
        }

        // Initial scan: just remember existing files, don't report them
        markExistingFiles(folders: monitoredFolders)
        initialScanDone = true

        if settings.monitorEntireDisk {
            startDiskWatcher()
        } else {
            let paths = monitoredFolders.map { $0.path }
            if !paths.isEmpty {
                startFSEventStream(for: paths)
            }
        }

        // Periodic fallback scan every 30 seconds
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.scanAllFolders()
        }

        // Observe settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsDidChange,
            object: nil
        )
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: .settingsDidChange, object: nil)
        debounceWorkItem?.cancel()

        periodicTimer?.invalidate()
        periodicTimer = nil

        stopFSEventStream()
        stopDiskWatcher()
    }

    func removeDetectedFile(_ url: URL) {
        stateQueue.async(flags: .barrier) { [weak self] in
            self?._detectedFiles.removeAll { $0 == url }
        }
    }

    func clearDetectedFiles() {
        stateQueue.async(flags: .barrier) { [weak self] in
            self?._detectedFiles.removeAll()
        }
    }

    @objc private func settingsChanged() {
        // Only restart if watcher-relevant settings actually changed.
        // Quality parameters (chunk duration, overlap, etc.) don't affect file watching.
        let settings = SettingsManager.shared
        let folders = settings.watchedFolders.map { $0.path }
        let diskMode = settings.monitorEntireDisk
        let fileTypes = settings.monitoredFileTypes

        if folders == lastWatchedFolders
            && diskMode == lastMonitorEntireDisk
            && fileTypes == lastMonitoredFileTypes {
            return // Nothing relevant changed
        }

        start() // Restart with new settings
    }

    // MARK: - FSEventStream (recursive folder monitoring)

    private func startFSEventStream(for paths: [String]) {
        let cfPaths = paths as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes) |
                    UInt32(kFSEventStreamCreateFlagFileEvents) |
                    UInt32(kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            3.0, // 3 second latency
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func stopFSEventStream() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    fileprivate func scheduleScan() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scanAllFolders()
        }
        debounceWorkItem = workItem
        watchQueue.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    private func scanAllFolders() {
        watchQueue.async { [weak self] in
            guard let self = self else { return }
            var newFiles: [URL] = []

            for folder in self.monitoredFolders where self.isFolderAccessible(folder) {
                let found = self.scanFolder(folder)
                newFiles.append(contentsOf: found)
            }

            if !newFiles.isEmpty {
                self.stateQueue.async(flags: .barrier) {
                    self._detectedFiles.append(contentsOf: newFiles)
                }
                DispatchQueue.main.async {
                    self.delegate?.fileWatcher(self, didDetectNewFiles: newFiles)
                }
            }
        }
    }

    /// Check if folder is accessible without triggering a TCC permission dialog.
    /// Uses FileManager.contentsOfDirectory which respects TCC, unlike POSIX access().
    private func isFolderAccessible(_ url: URL) -> Bool {
        // First check if the directory even exists
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else {
            return false
        }
        // Try a lightweight directory listing — triggers TCC check internally
        // without showing a dialog if access was previously denied.
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return true
        } catch {
            return false
        }
    }

    /// Mark pre-existing media files as "seen" without reporting them.
    /// Only marks files modified BEFORE startTime — files modified after
    /// startTime are left for scanFolder() to detect and report.
    private func markExistingFiles(folders: [URL]) {
        let cutoff = startTime
        watchQueue.sync { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            for folder in folders {
                guard let enumerator = fm.enumerator(
                    at: folder,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                while let url = enumerator.nextObject() as? URL {
                    guard let rv = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                          rv.isRegularFile == true else { continue }
                    let ext = url.pathExtension.lowercased()
                    guard self.activeExtensions.contains(ext) else { continue }
                    let modDate = rv.contentModificationDate ?? Date.distantPast
                    // Only mark files older than app start — new files should be reported
                    if modDate >= cutoff { continue }
                    let fileKey = "\(url.path)|\(modDate.timeIntervalSince1970)"
                    self.stateQueue.async(flags: .barrier) {
                        self.seenFiles.insert(fileKey)
                    }
                }
            }
        }
    }

    private func scanFolder(_ folder: URL) -> [URL] {
        let fm = FileManager.default
        var newFiles: [URL] = []

        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        while let url = enumerator.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]),
                  resourceValues.isRegularFile == true else { continue }

            let ext = url.pathExtension.lowercased()
            guard self.activeExtensions.contains(ext) else { continue }

            // Skip files that are still being written (size 0)
            let fileSize = resourceValues.fileSize ?? 0
            if fileSize == 0 { continue }

            let modDate = resourceValues.contentModificationDate ?? Date.distantPast

            // Only report files modified after app started
            if modDate < startTime { continue }

            let fileKey = "\(url.path)|\(modDate.timeIntervalSince1970)"

            let alreadySeen = stateQueue.sync { seenFiles.contains(fileKey) }
            if alreadySeen { continue }

            stateQueue.async(flags: .barrier) { [weak self] in
                self?.seenFiles.insert(fileKey)
            }
            newFiles.append(url)
        }

        return newFiles
    }

    // MARK: - Disk-wide monitoring via Python watcher

    private func startDiskWatcher() {
        let python = SettingsManager.shared.pythonExecutable
        guard FileManager.default.fileExists(atPath: python.path) else {
            // Fallback: monitor common directories via FSEventStream
            let commonPaths = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
            ]
            startFSEventStream(for: commonPaths)
            return
        }

        guard let watcherScript = EngineLocator.findScript("watcher.py") else {
            // Fallback to FSEventStream on common directories
            let commonPaths = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path,
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
            ]
            startFSEventStream(for: commonPaths)
            return
        }

        let process = Process()
        process.executableURL = python
        process.arguments = [watcherScript.path, "--all-disk"]

        let pipe = Pipe()
        process.standardOutput = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.parseDiskWatcherOutput(data)
        }

        process.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            self?.diskWatcherProcess = nil
        }

        do {
            try process.run()
            diskWatcherProcess = process
        } catch {
            // Fallback to FSEventStream
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            startFSEventStream(for: [home])
        }
    }

    private func stopDiskWatcher() {
        diskWatcherProcess?.terminate()
        diskWatcherProcess = nil
    }

    private func parseDiskWatcherOutput(_ data: Data) {
        guard let output = String(data: data, encoding: .utf8) else { return }
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var newFiles: [URL] = []
        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let path = json["path"] as? String else { continue }

            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension.lowercased()
            guard self.activeExtensions.contains(ext) else { continue }

            let fileKey = "\(url.path)|disk"
            let alreadySeen = stateQueue.sync { seenFiles.contains(fileKey) }
            if alreadySeen { continue }

            stateQueue.async(flags: .barrier) { [weak self] in
                self?.seenFiles.insert(fileKey)
            }
            newFiles.append(url)
        }

        if !newFiles.isEmpty {
            stateQueue.async(flags: .barrier) { [weak self] in
                self?._detectedFiles.append(contentsOf: newFiles)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.fileWatcher(self, didDetectNewFiles: newFiles)
            }
        }
    }

    deinit {
        stop()
    }
}

// MARK: - FSEventStream C Callback

private func fsEventCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
    watcher.scheduleScan()
}
