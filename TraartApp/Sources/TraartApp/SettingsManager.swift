import Foundation

extension Notification.Name {
    static let settingsDidChange = Notification.Name("com.traart.settingsDidChange")
}

final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.traart.settings", attributes: .concurrent)

    private enum Keys {
        static let watchedFolders = "watchedFolders"
        static let outputFolder = "outputFolder"
        static let autoTranscribe = "autoTranscribe"
        static let enableDiarization = "enableDiarization"
        static let expectedSpeakers = "expectedSpeakers"
        static let monitorEntireDisk = "monitorEntireDisk"
        static let launchAtLogin = "launchAtLogin"
        static let saveNextToFile = "saveNextToFile"
        static let outputFormat = "outputFormat"
        static let qualityPreset = "qualityPreset"
        static let chunkDuration = "chunkDuration"
        static let chunkOverlap = "chunkOverlap"
        static let mergeGap = "mergeGap"
        static let minSegmentDuration = "minSegmentDuration"
        static let expansionPadding = "expansionPadding"
        static let monitoredFileTypes = "monitoredFileTypes"
        static let dualTranscription = "dualTranscription"
    }

    private init() {
        defaults = UserDefaults(suiteName: "com.traart.app") ?? .standard
        registerDefaults()
    }

    private func registerDefaults() {
        // No default watched folders — user selects via UI (grants TCC access via NSOpenPanel)
        let encoded = try? JSONEncoder().encode([String]())
        defaults.register(defaults: [
            Keys.watchedFolders: encoded ?? Data(),
            Keys.saveNextToFile: true,
            Keys.autoTranscribe: false,
            Keys.enableDiarization: true,
            Keys.expectedSpeakers: 0,  // 0 = auto-detect
            Keys.monitorEntireDisk: false,
            Keys.launchAtLogin: false,
            Keys.outputFormat: "md",
            Keys.qualityPreset: 2,
            Keys.chunkDuration: 20,
            Keys.chunkOverlap: 4,
            Keys.mergeGap: 0.8,
            Keys.minSegmentDuration: 0.2,
            Keys.expansionPadding: 3,
            Keys.monitoredFileTypes: "audio",
            Keys.dualTranscription: false,
        ])
    }

    var watchedFolders: [URL] {
        get {
            queue.sync {
                guard let data = defaults.data(forKey: Keys.watchedFolders),
                      let paths = try? JSONDecoder().decode([String].self, from: data) else {
                    return []
                }
                return paths.map { URL(fileURLWithPath: $0) }
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                let paths = newValue.map { $0.path }
                if let data = try? JSONEncoder().encode(paths) {
                    self?.defaults.set(data, forKey: Keys.watchedFolders)
                }
                self?.postChangeNotification()
            }
        }
    }

    var outputFolder: URL? {
        get {
            queue.sync {
                guard let path = defaults.string(forKey: Keys.outputFolder) else { return nil }
                return URL(fileURLWithPath: path)
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue?.path, forKey: Keys.outputFolder)
                self?.postChangeNotification()
            }
        }
    }

    var saveNextToFile: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.saveNextToFile) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.saveNextToFile)
                self?.postChangeNotification()
            }
        }
    }

    var autoTranscribe: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.autoTranscribe) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.autoTranscribe)
                self?.postChangeNotification()
            }
        }
    }

    var enableDiarization: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.enableDiarization) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.enableDiarization)
                self?.postChangeNotification()
            }
        }
    }

    var expectedSpeakers: Int {
        get { queue.sync { defaults.integer(forKey: Keys.expectedSpeakers) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.expectedSpeakers)
                self?.postChangeNotification()
            }
        }
    }

    var monitorEntireDisk: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.monitorEntireDisk) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.monitorEntireDisk)
                self?.postChangeNotification()
            }
        }
    }

    var launchAtLogin: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.launchAtLogin) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.launchAtLogin)
                self?.postChangeNotification()
            }
        }
    }

    /// Output format: "md", "txt", or "json"
    var outputFormat: String {
        get { queue.sync { defaults.string(forKey: Keys.outputFormat) ?? "md" } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.outputFormat)
                self?.postChangeNotification()
            }
        }
    }

    // MARK: - Quality presets

    struct QualityPreset {
        let name: String
        let chunkDuration: Int
        let chunkOverlap: Int
        let mergeGap: Double
        let minSegmentDuration: Double
        let expansionPadding: Int
    }

    static let qualityPresets: [QualityPreset] = [
        QualityPreset(name: "Быстро",         chunkDuration: 25, chunkOverlap: 3, mergeGap: 1.5, minSegmentDuration: 0.3,  expansionPadding: 2),
        QualityPreset(name: "Быстрее",        chunkDuration: 20, chunkOverlap: 3, mergeGap: 1.0, minSegmentDuration: 0.25, expansionPadding: 3),
        QualityPreset(name: "Сбалансировано", chunkDuration: 20, chunkOverlap: 4, mergeGap: 0.8, minSegmentDuration: 0.2,  expansionPadding: 3),
        QualityPreset(name: "Качественнее",   chunkDuration: 15, chunkOverlap: 5, mergeGap: 0.5, minSegmentDuration: 0.15, expansionPadding: 4),
        QualityPreset(name: "Максимум",        chunkDuration: 12, chunkOverlap: 5, mergeGap: 0.3, minSegmentDuration: 0.1,  expansionPadding: 5),
    ]

    /// Quality preset index (0–4), or -1 for custom settings
    var qualityPreset: Int {
        get { queue.sync { defaults.integer(forKey: Keys.qualityPreset) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.qualityPreset)
                self?.postChangeNotification()
            }
        }
    }

    var chunkDuration: Int {
        get { queue.sync { defaults.integer(forKey: Keys.chunkDuration) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.chunkDuration)
                self?.postChangeNotification()
            }
        }
    }

    var chunkOverlap: Int {
        get { queue.sync { defaults.integer(forKey: Keys.chunkOverlap) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.chunkOverlap)
                self?.postChangeNotification()
            }
        }
    }

    var mergeGap: Double {
        get { queue.sync { defaults.double(forKey: Keys.mergeGap) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.mergeGap)
                self?.postChangeNotification()
            }
        }
    }

    var minSegmentDuration: Double {
        get { queue.sync { defaults.double(forKey: Keys.minSegmentDuration) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.minSegmentDuration)
                self?.postChangeNotification()
            }
        }
    }

    var expansionPadding: Int {
        get { queue.sync { defaults.integer(forKey: Keys.expansionPadding) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.expansionPadding)
                self?.postChangeNotification()
            }
        }
    }

    /// Apply a preset by index, updating all 5 parameters at once.
    func applyPreset(_ index: Int) {
        guard index >= 0, index < Self.qualityPresets.count else { return }
        let p = Self.qualityPresets[index]
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.defaults.set(index, forKey: Keys.qualityPreset)
            self.defaults.set(p.chunkDuration, forKey: Keys.chunkDuration)
            self.defaults.set(p.chunkOverlap, forKey: Keys.chunkOverlap)
            self.defaults.set(p.mergeGap, forKey: Keys.mergeGap)
            self.defaults.set(p.minSegmentDuration, forKey: Keys.minSegmentDuration)
            self.defaults.set(p.expansionPadding, forKey: Keys.expansionPadding)
            self.postChangeNotification()
        }
    }

    /// Name of the current quality preset, or "Свои" if custom.
    var qualityPresetName: String {
        let idx = qualityPreset
        if idx >= 0, idx < Self.qualityPresets.count {
            return Self.qualityPresets[idx].name
        }
        return "Свои"
    }

    /// Check if current parameters match any preset; if not, set preset to -1 (custom).
    func detectPreset() {
        let cd = chunkDuration
        let co = chunkOverlap
        let mg = mergeGap
        let ms = minSegmentDuration
        let ep = expansionPadding
        for (i, p) in Self.qualityPresets.enumerated() {
            if p.chunkDuration == cd && p.chunkOverlap == co
                && abs(p.mergeGap - mg) < 0.01
                && abs(p.minSegmentDuration - ms) < 0.01
                && p.expansionPadding == ep {
                qualityPreset = i
                return
            }
        }
        qualityPreset = -1
    }

    /// Create two files: with diarization and without (only at max quality)
    var dualTranscription: Bool {
        get { queue.sync { defaults.bool(forKey: Keys.dualTranscription) } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.dualTranscription)
                self?.postChangeNotification()
            }
        }
    }

    /// Monitored file types: "all", "audio", "video"
    var monitoredFileTypes: String {
        get { queue.sync { defaults.string(forKey: Keys.monitoredFileTypes) ?? "audio" } }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.defaults.set(newValue, forKey: Keys.monitoredFileTypes)
                self?.postChangeNotification()
            }
        }
    }

    /// File extension for the current output format (with dot)
    var outputFileExtension: String {
        switch outputFormat {
        case "json": return ".json"
        case "txt": return ".txt"
        case "srt": return ".srt"
        case "vtt": return ".vtt"
        default: return ".md"
        }
    }

    private func postChangeNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    var appSupportDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let traartDir = appSupport.appendingPathComponent("Traart")
        if !fm.fileExists(atPath: traartDir.path) {
            try? fm.createDirectory(at: traartDir, withIntermediateDirectories: true)
        }
        return traartDir
    }

    var pythonEnvPath: URL {
        appSupportDirectory.appendingPathComponent("python-env")
    }

    var pythonExecutable: URL {
        pythonEnvPath.appendingPathComponent("bin/python3")
    }

    var modelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("models")
    }
}
