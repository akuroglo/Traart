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

    /// Folders the user explicitly selected (safe to enumerate — NSOpenPanel grants TCC)
    private var userSelectedFolders: [URL] = []

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
        initialScanDone = false

        let settings = SettingsManager.shared

        // Cache watcher-relevant settings for change detection
        lastWatchedFolders = settings.watchedFolders.map { $0.path }
        lastMonitorEntireDisk = settings.monitorEntireDisk
        lastMonitoredFileTypes = settings.monitoredFileTypes

        // User-selected folders are safe to enumerate (NSOpenPanel granted TCC access)
        userSelectedFolders = settings.watchedFolders.filter { folderExists($0) }

        // Initial scan: only enumerate user-selected folders (no TCC issues)
        markExistingFiles(folders: userSelectedFolders)
        initialScanDone = true

        // Determine FSEventStream paths (safe — FSEventStream doesn't trigger TCC)
        var fseventPaths = userSelectedFolders.map { $0.path }

        if settings.monitorEntireDisk {
            // Add common directories to FSEventStream only (NOT to enumeration list)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let systemFolders = [
                home.appendingPathComponent("Downloads").path,
                home.appendingPathComponent("Documents").path,
                home.appendingPathComponent("Desktop").path,
            ]
            for path in systemFolders {
                if !fseventPaths.contains(path) {
                    fseventPaths.append(path)
                }
            }
        }

        if !fseventPaths.isEmpty {
            startFSEventStream(for: fseventPaths)
        }

        // Periodic fallback scan — only user-selected folders (safe to enumerate)
        if !userSelectedFolders.isEmpty {
            periodicTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.scanUserSelectedFolders()
            }
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

    /// Mark a file as seen so FileWatcher won't re-detect it.
    func markFileAsSeen(_ url: URL) {
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        let fileKey = "\(url.path)|\(modDate.timeIntervalSince1970)"
        stateQueue.async(flags: .barrier) { [weak self] in
            self?.seenFiles.insert(fileKey)
        }
    }

    func clearDetectedFiles() {
        stateQueue.async(flags: .barrier) { [weak self] in
            self?._detectedFiles.removeAll()
        }
    }

    @objc private func settingsChanged() {
        let settings = SettingsManager.shared
        let folders = settings.watchedFolders.map { $0.path }
        let diskMode = settings.monitorEntireDisk
        let fileTypes = settings.monitoredFileTypes

        if folders == lastWatchedFolders
            && diskMode == lastMonitorEntireDisk
            && fileTypes == lastMonitoredFileTypes {
            return
        }

        start()
    }

    // MARK: - FSEventStream

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
            3.0,
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

    /// Process individual file events from FSEventStream — no folder enumeration needed.
    fileprivate func handleFSEvents(_ paths: [String]) {
        guard initialScanDone else { return }

        watchQueue.async { [weak self] in
            guard let self = self else { return }
            var newFiles: [URL] = []

            for path in paths {
                let url = URL(fileURLWithPath: path)
                let ext = url.pathExtension.lowercased()
                guard self.activeExtensions.contains(ext) else { continue }

                // Check if file is inside a user-selected folder (safe to access attributes)
                let inUserFolder = self.userSelectedFolders.contains(where: { path.hasPrefix($0.path) })

                if inUserFolder {
                    // Full validation — we have TCC access
                    guard let rv = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]),
                          rv.isRegularFile == true else { continue }
                    let fileSize = rv.fileSize ?? 0
                    if fileSize == 0 { continue }
                    let modDate = rv.contentModificationDate ?? Date.distantPast
                    if modDate < self.startTime { continue }
                    let fileKey = "\(url.path)|\(modDate.timeIntervalSince1970)"
                    let alreadySeen = self.stateQueue.sync { self.seenFiles.contains(fileKey) }
                    if alreadySeen { continue }
                    self.stateQueue.async(flags: .barrier) { self.seenFiles.insert(fileKey) }
                } else {
                    // Auto-added folder (e.g. ~/Downloads via monitorEntireDisk)
                    // Don't access file attributes — that triggers TCC dialogs.
                    // Just use the path from FSEventStream.
                    let fileKey = url.path
                    let alreadySeen = self.stateQueue.sync { self.seenFiles.contains(fileKey) }
                    if alreadySeen { continue }
                    self.stateQueue.async(flags: .barrier) { self.seenFiles.insert(fileKey) }
                }

                newFiles.append(url)
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

    /// Debounced scan for user-selected folders only (triggered by FSEventStream for these)
    fileprivate func scheduleScanForUserFolders() {
        guard !userSelectedFolders.isEmpty else { return }
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scanUserSelectedFolders()
        }
        debounceWorkItem = workItem
        watchQueue.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    private func scanUserSelectedFolders() {
        watchQueue.async { [weak self] in
            guard let self = self else { return }
            var newFiles: [URL] = []

            for folder in self.userSelectedFolders {
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

    private func folderExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Mark pre-existing media files as "seen" without reporting them.
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

            let fileSize = resourceValues.fileSize ?? 0
            if fileSize == 0 { continue }

            let modDate = resourceValues.contentModificationDate ?? Date.distantPast
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

    // MARK: - Disk-wide monitoring (legacy Python watcher fallback)

    private func startDiskWatcher() {
        let python = SettingsManager.shared.pythonExecutable
        guard FileManager.default.fileExists(atPath: python.path) else { return }

        guard let watcherScript = EngineLocator.findScript("watcher.py") else { return }

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
            // Python watcher failed — FSEventStream is already running as primary
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

    // Extract individual file paths from FSEventStream events
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
    watcher.handleFSEvents(paths)
}
