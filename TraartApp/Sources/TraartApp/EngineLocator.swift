import Foundation

/// Shared utility for locating engine scripts bundled with the app.
/// Replaces duplicated findEngineScript in FileWatcher, TranscriptionManager, SetupManager.
enum EngineLocator {
    /// Find an engine script by name (e.g. "transcribe.py", "watcher.py", "setup_env.py").
    /// Searches: executable directory, bundle resources, project directory (dev mode).
    static func findScript(_ name: String) -> URL? {
        // Check alongside the executable
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let candidate = executableDir.appendingPathComponent("engine/\(name)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Check in bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            let candidate = URL(fileURLWithPath: resourcePath).appendingPathComponent("engine/\(name)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Check in project directory hierarchy (development mode)
        let execURL = Bundle.main.executableURL ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        var searchDir = execURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = searchDir.appendingPathComponent("engine/\(name)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            searchDir = searchDir.deletingLastPathComponent()
        }

        return nil
    }
}
