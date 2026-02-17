import Foundation

struct TranscriptionJob: Identifiable, Codable {
    let id: UUID
    let sourceFile: URL
    var outputFile: URL?
    var status: Status
    var progress: Double
    var step: TranscriptionStep?
    var etaSeconds: Double?
    var startTime: Date?
    var endTime: Date?
    var error: String?
    var resultText: String?
    var speakersDetected: Int?
    var warningsCount: Int = 0
    var warnings: [String] = []

    /// Per-job diarization override: nil = use global setting, true/false = force
    var forceDiarization: Bool?

    enum Status: String, Codable {
        case queued, running, completed, failed, cancelled
    }

    enum TranscriptionStep: String, Codable {
        case preparing
        case loadingModel = "loading_model"
        case diarizing
        case transcribing
        case saving
        case complete

        var displayName: String {
            switch self {
            case .preparing: return "Подготовка"
            case .loadingModel: return "Загрузка модели"
            case .diarizing: return "Диаризация"
            case .transcribing: return "Транскрибация"
            case .saving: return "Сохранение"
            case .complete: return "Готово"
            }
        }
    }

    init(sourceFile: URL) {
        self.id = UUID()
        self.sourceFile = sourceFile
        self.status = .queued
        self.progress = 0.0
    }

    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var etaString: String? {
        guard let eta = etaSeconds, eta > 0 else { return nil }
        let m = Int(eta) / 60
        let s = Int(eta) % 60
        return m > 0 ? "~\(m)м \(s)с" : "~\(s)с"
    }

    var sourceFileName: String {
        sourceFile.lastPathComponent
    }

    var outputFileName: String? {
        outputFile?.lastPathComponent
    }

    /// Human-readable duration string
    var durationString: String? {
        guard let dur = duration else { return nil }
        let minutes = Int(dur) / 60
        let seconds = Int(dur) % 60
        if minutes > 0 {
            return "\(minutes)м \(seconds)с"
        }
        return "\(seconds)с"
    }
}
