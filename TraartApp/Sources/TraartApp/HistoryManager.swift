import Foundation

/// Manages persistent transcription history stored as JSON in Application Support.
final class HistoryManager {
    static let shared = HistoryManager()

    private static let maxJobs = 50
    private let queue = DispatchQueue(label: "com.traart.history", attributes: .concurrent)
    private var _jobs: [TranscriptionJob] = []

    private var historyFileURL: URL {
        SettingsManager.shared.appSupportDirectory.appendingPathComponent("history.json")
    }

    private init() {
        loadFromDisk()
    }

    var jobs: [TranscriptionJob] {
        queue.sync { _jobs }
    }

    /// Add a completed/failed/cancelled job to history and persist.
    func addJob(_ job: TranscriptionJob) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // Remove any existing entry with same id
            self._jobs.removeAll { $0.id == job.id }
            self._jobs.insert(job, at: 0)
            // Trim to max
            if self._jobs.count > Self.maxJobs {
                self._jobs = Array(self._jobs.prefix(Self.maxJobs))
            }
            self.saveToDisk()
        }
    }

    /// Remove a specific job from history.
    func removeJob(id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._jobs.removeAll { $0.id == id }
            self.saveToDisk()
        }
    }

    /// Clear all history.
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._jobs.removeAll()
            self.saveToDisk()
        }
    }

    /// Read full transcription text from the output file.
    func fullText(for job: TranscriptionJob) -> String? {
        guard let outputFile = job.outputFile,
              FileManager.default.fileExists(atPath: outputFile.path),
              let data = try? Data(contentsOf: outputFile),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path),
              let data = try? Data(contentsOf: historyFileURL),
              let decoded = try? JSONDecoder().decode([TranscriptionJob].self, from: data) else {
            return
        }
        _jobs = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(_jobs) else { return }
        try? data.write(to: historyFileURL, options: .atomic)
    }
}
