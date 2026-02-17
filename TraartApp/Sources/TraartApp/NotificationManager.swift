import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let categoryNewFile = "NEW_FILE"
    private static let categoryComplete = "TRANSCRIPTION_COMPLETE"
    private static let categoryFailed = "TRANSCRIPTION_FAILED"
    private static let categoryStarted = "TRANSCRIPTION_STARTED"
    private static let categorySetup = "SETUP_REQUIRED"

    private static let actionTranscribe = "TRANSCRIBE_ACTION"
    private static let actionOpen = "OPEN_ACTION"
    private static let actionRetry = "RETRY_ACTION"
    private static let actionSetup = "SETUP_ACTION"

    var onTranscribeAction: ((URL) -> Void)?
    var onOpenAction: ((URL) -> Void)?
    var onRetryAction: ((URL) -> Void)?
    var onSetupAction: (() -> Void)?

    private override init() {
        super.init()
        configureCategories()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("Traart: notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func configureCategories() {
        let transcribeAction = UNNotificationAction(
            identifier: Self.actionTranscribe,
            title: "Транскрибировать",
            options: .foreground
        )

        let openAction = UNNotificationAction(
            identifier: Self.actionOpen,
            title: "Открыть",
            options: .foreground
        )

        let retryAction = UNNotificationAction(
            identifier: Self.actionRetry,
            title: "Повторить",
            options: .foreground
        )

        let setupAction = UNNotificationAction(
            identifier: Self.actionSetup,
            title: "Настроить",
            options: .foreground
        )

        let newFileCategory = UNNotificationCategory(
            identifier: Self.categoryNewFile,
            actions: [transcribeAction],
            intentIdentifiers: []
        )

        let completeCategory = UNNotificationCategory(
            identifier: Self.categoryComplete,
            actions: [openAction],
            intentIdentifiers: []
        )

        let failedCategory = UNNotificationCategory(
            identifier: Self.categoryFailed,
            actions: [retryAction],
            intentIdentifiers: []
        )

        let startedCategory = UNNotificationCategory(
            identifier: Self.categoryStarted,
            actions: [],
            intentIdentifiers: []
        )

        let setupCategory = UNNotificationCategory(
            identifier: Self.categorySetup,
            actions: [setupAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            newFileCategory, completeCategory, failedCategory, startedCategory, setupCategory
        ])
    }

    func notifyNewFile(url: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Traart"
        content.body = "Обнаружен новый файл: \(url.lastPathComponent)"
        content.sound = .default
        content.categoryIdentifier = Self.categoryNewFile
        content.userInfo = ["filePath": url.path]
        content.threadIdentifier = "traart-files"

        let request = UNNotificationRequest(
            identifier: "newFile-\(url.lastPathComponent)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyTranscriptionStarted(job: TranscriptionJob) {
        let content = UNMutableNotificationContent()
        content.title = "Traart"
        content.body = "Транскрибация начата: \(job.sourceFileName)"
        content.sound = nil  // No sound for start — not intrusive
        content.categoryIdentifier = Self.categoryStarted
        content.threadIdentifier = "traart-transcription"

        let request = UNNotificationRequest(
            identifier: "started-\(job.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyTranscriptionComplete(job: TranscriptionJob) {
        // Remove the "started" notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["started-\(job.id.uuidString)"]
        )

        let content = UNMutableNotificationContent()
        content.title = "Traart"
        let durationStr = job.durationString.map { " за \($0)" } ?? ""

        if job.warningsCount > 0 {
            let warnWord: String
            switch job.warningsCount {
            case 1: warnWord = "предупреждение"
            case 2...4: warnWord = "предупреждения"
            default: warnWord = "предупреждений"
            }
            content.body = "Транскрибация завершена\(durationStr): \(job.sourceFileName)\n\(job.warningsCount) \(warnWord) — откройте лог для деталей"
        } else {
            content.body = "Транскрибация завершена\(durationStr): \(job.sourceFileName)"
        }

        content.sound = .default
        content.categoryIdentifier = Self.categoryComplete
        content.threadIdentifier = "traart-transcription"
        if let outputFile = job.outputFile {
            content.userInfo = ["filePath": outputFile.path]
        }

        let request = UNNotificationRequest(
            identifier: "complete-\(job.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyTranscriptionFailed(job: TranscriptionJob, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Traart"
        content.body = "Ошибка: \(job.sourceFileName)\n\(Self.humanReadableError(error))"
        content.sound = .default
        content.categoryIdentifier = Self.categoryFailed
        content.threadIdentifier = "traart-transcription"
        // Store source file for retry
        content.userInfo = ["sourceFilePath": job.sourceFile.path]

        let request = UNNotificationRequest(
            identifier: "failed-\(job.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifySetupRequired() {
        let content = UNMutableNotificationContent()
        content.title = "Traart"
        content.body = "Требуется начальная настройка"
        content.sound = .default
        content.categoryIdentifier = Self.categorySetup

        let request = UNNotificationRequest(
            identifier: "setup-required",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Human-Readable Error Mapping

    private static func humanReadableError(_ error: String) -> String {
        let lowered = error.lowercased()

        if lowered.contains("out of memory") || lowered.contains("oom") || lowered.contains("mps backend out of memory") {
            return "Не хватает оперативной памяти. Закройте другие приложения и попробуйте снова."
        }
        if lowered.contains("ffmpeg") && lowered.contains("not found") {
            return "ffmpeg не установлен. Установите: brew install ffmpeg"
        }
        if lowered.contains("no such file") || lowered.contains("file not found") {
            return "Файл не найден. Возможно, он был перемещён или удалён."
        }
        if lowered.contains("unsupported file format") || lowered.contains("invalid data found") {
            return "Формат файла не поддерживается или файл повреждён."
        }
        if lowered.contains("permission denied") || lowered.contains("operation not permitted") {
            return "Нет доступа к файлу. Проверьте права доступа в Системных настройках."
        }
        if lowered.contains("connection") || lowered.contains("network") || lowered.contains("timeout") {
            return "Ошибка сети. Проверьте подключение к интернету."
        }
        if lowered.contains("conversion failed") || lowered.contains("ffmpeg conversion") {
            return "Не удалось конвертировать файл. Возможно, файл повреждён."
        }
        if lowered.contains("python") && lowered.contains("не найдено") {
            return "Python окружение не найдено. Переустановите приложение."
        }
        if lowered.contains("скрипт") && lowered.contains("не найден") {
            return "Компонент приложения не найден. Переустановите приложение."
        }
        // Truncate long errors
        if error.count > 120 {
            return String(error.prefix(120)) + "..."
        }
        return error
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case Self.actionTranscribe:
            if let path = userInfo["filePath"] as? String {
                onTranscribeAction?(URL(fileURLWithPath: path))
            }

        case Self.actionOpen:
            if let path = userInfo["filePath"] as? String {
                onOpenAction?(URL(fileURLWithPath: path))
            }

        case Self.actionRetry:
            if let path = userInfo["sourceFilePath"] as? String {
                onRetryAction?(URL(fileURLWithPath: path))
            }

        case Self.actionSetup:
            onSetupAction?()

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body
            if let path = userInfo["filePath"] as? String {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    onOpenAction?(url)
                }
            }

        default:
            break
        }

        completionHandler()
    }
}
