import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var fileWatcher: FileWatcher?
    private var transcriptionManager: TranscriptionManager?
    private var setupManager: SetupManager?
    private var onboardingController: OnboardingWindowController?

    private static let onboardingKey = "hasCompletedOnboarding"
    private var setupStartTime: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize settings
        _ = SettingsManager.shared

        // Initialize analytics
        AnalyticsManager.shared.configure()
        AnalyticsManager.shared.trackAppLaunched()

        // Load persistent history
        _ = HistoryManager.shared

        // Request notification permission
        NotificationManager.shared.requestPermission()

        // Set up notification action handlers
        NotificationManager.shared.onTranscribeAction = { [weak self] url in
            self?.transcribeFile(url)
        }
        NotificationManager.shared.onOpenAction = { url in
            NSWorkspace.shared.open(url)
        }
        NotificationManager.shared.onRetryAction = { [weak self] url in
            self?.transcribeFile(url)
        }
        NotificationManager.shared.onSetupAction = { [weak self] in
            self?.startSetup()
        }

        // Initialize transcription manager
        let tm = TranscriptionManager()
        tm.delegate = self
        transcriptionManager = tm

        // Initialize status bar
        let sbc = StatusBarController()
        sbc.onTranscribeFile = { [weak self] url in
            self?.transcribeFile(url)
        }
        sbc.onStartSetup = { [weak self] in
            self?.startSetup()
        }
        sbc.onCancelTranscription = { [weak self] in
            self?.transcriptionManager?.cancelCurrentJob()
            // Persist cancelled job to history and update UI
            if let cancelled = self?.transcriptionManager?.completedJobs.first,
               cancelled.status == .cancelled {
                HistoryManager.shared.addJob(cancelled)
            }
            self?.statusBarController?.updateCompletedJobs(HistoryManager.shared.jobs)
            self?.updateQueueDisplay()
        }
        sbc.onRetryJob = { [weak self] url in
            self?.transcribeFile(url)
        }
        sbc.onOpenOutputFolder = {
            let folder = SettingsManager.shared.outputFolder
                ?? SettingsManager.shared.watchedFolders.first
                ?? FileManager.default.homeDirectoryForCurrentUser
            NSWorkspace.shared.open(folder)
        }
        sbc.onMenuWillOpen = { [weak self] in
            self?.updateQueueDisplay()
        }

        // Load history into status bar
        sbc.updateCompletedJobs(HistoryManager.shared.jobs)

        statusBarController = sbc

        // Check for announcements
        AnnouncementsManager.shared.checkForAnnouncements()

        // Onboarding or normal launch
        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            showOnboarding()
        } else {
            checkSetupAndLaunch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AnalyticsManager.shared.trackAppTerminated()
        fileWatcher?.stop()
        transcriptionManager?.cancelCurrentJob()
        setupManager?.cancelSetup()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let controller = OnboardingWindowController()
        controller.onComplete = { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            AnalyticsManager.shared.trackOnboardingCompleted()
            self.onboardingController = nil
            self.checkSetupAndLaunch()
        }
        controller.onCancel = { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            self.statusBarController?.updateStatus("Установка не завершена")
            self.onboardingController = nil
        }
        onboardingController = controller
        controller.showWindow(nil)
    }

    // MARK: - Setup

    /// Async environment check — shows "Проверка окружения..." while running import torch in background.
    private func checkSetupAndLaunch() {
        statusBarController?.updateStatus("Проверка окружения...")
        SetupManager.checkNeedsSetup { [weak self] needsSetup in
            guard let self = self else { return }
            if needsSetup {
                self.statusBarController?.updateStatus("Требуется настройка")
                NotificationManager.shared.notifySetupRequired()
                self.startSetup()
            } else {
                self.statusBarController?.updateStatus("")
                self.startFileWatcher()
            }
        }
    }

    private func startSetup() {
        guard setupManager == nil || !(setupManager?.isSettingUp ?? false) else { return }

        let sm = SetupManager()
        setupManager = sm
        setupStartTime = Date()
        AnalyticsManager.shared.trackSetupStarted()

        statusBarController?.updateStatus("Установка окружения...")

        sm.onProgressUpdate = { [weak self] progress, status in
            self?.statusBarController?.showSetupProgress(progress, status: status)
        }

        sm.startSetup { [weak self] success in
            guard let self = self else { return }
            if success {
                let duration = Int(Date().timeIntervalSince(self.setupStartTime ?? Date()))
                AnalyticsManager.shared.trackSetupCompleted(durationSeconds: duration)
                self.statusBarController?.showSetupCompleted()
                self.startFileWatcher()
            } else {
                let detail = self.setupManager?.setupStatus ?? "Неизвестная ошибка"
                AnalyticsManager.shared.trackSetupFailed(error: detail)
                self.statusBarController?.showSetupFailed(error: detail)
            }
            self.setupStartTime = nil
            self.setupManager = nil
        }
    }

    // MARK: - File Watcher

    private func startFileWatcher() {
        let fw = FileWatcher()
        fw.delegate = self
        fw.start()
        fileWatcher = fw
        statusBarController?.updateStatus("Готово")
    }

    // MARK: - Transcription

    private func transcribeFile(_ url: URL) {
        // Fast check (no Python binary → definitely needs setup)
        if SetupManager.needsSetupFast {
            statusBarController?.showSetupRequired()
            NotificationManager.shared.notifySetupRequired()
            startSetup()
            return
        }

        // Remove from detected files and mark as seen to prevent re-detection
        fileWatcher?.removeDetectedFile(url)
        fileWatcher?.markFileAsSeen(url)
        statusBarController?.updateDetectedFiles(fileWatcher?.detectedFiles ?? [])

        // Start transcription with the configured output folder
        let outputDir = SettingsManager.shared.outputFolder
        transcriptionManager?.transcribe(file: url, outputDir: outputDir)
        updateQueueDisplay()
    }

    private func updateQueueDisplay() {
        statusBarController?.updateQueue(transcriptionManager?.queue ?? [])
    }

    // MARK: - Launch at Login

    static func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Traart: launch at login error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - FileWatcherDelegate

extension AppDelegate: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatcher, didDetectNewFiles files: [URL]) {
        statusBarController?.updateDetectedFiles(watcher.detectedFiles)

        let settings = SettingsManager.shared

        for file in files {
            NotificationManager.shared.notifyNewFile(url: file)

            // Auto-transcribe if enabled — use configured output folder
            if settings.autoTranscribe {
                AnalyticsManager.shared.trackAutoTranscribeTriggered()
                let outputDir = settings.outputFolder
                transcriptionManager?.transcribe(file: file, outputDir: outputDir)
                watcher.removeDetectedFile(file)
            }
        }

        if settings.autoTranscribe {
            statusBarController?.updateDetectedFiles(watcher.detectedFiles)
        }
    }
}

// MARK: - TranscriptionManagerDelegate

extension AppDelegate: TranscriptionManagerDelegate {
    func transcriptionManager(_ manager: TranscriptionManager, didStartJob job: TranscriptionJob) {
        NotificationManager.shared.notifyTranscriptionStarted(job: job)
        statusBarController?.showTranscriptionStarted(fileName: job.sourceFileName)
        updateQueueDisplay()
    }

    func transcriptionManager(_ manager: TranscriptionManager, didUpdateProgress job: TranscriptionJob) {
        statusBarController?.showTranscriptionProgress(job.progress, fileName: job.sourceFileName, step: job.step, etaSeconds: job.etaSeconds)
    }

    func transcriptionManager(_ manager: TranscriptionManager, didCompleteJob job: TranscriptionJob) {
        NotificationManager.shared.notifyTranscriptionComplete(job: job)
        HistoryManager.shared.addJob(job)
        statusBarController?.updateCompletedJobs(HistoryManager.shared.jobs)
        updateQueueDisplay()

        // Auto-copy for microphone recordings
        if job.sourceFile.lastPathComponent.hasPrefix("traart-recording-") {
            if let text = HistoryManager.shared.fullText(for: job) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            // Clean up temp file
            try? FileManager.default.removeItem(at: job.sourceFile)
        }

        if manager.queue.isEmpty {
            statusBarController?.showTranscriptionCompleted(fileName: job.sourceFileName)
        }
    }

    func transcriptionManager(_ manager: TranscriptionManager, didFailJob job: TranscriptionJob) {
        let errorMsg = job.error ?? "Неизвестная ошибка"
        NotificationManager.shared.notifyTranscriptionFailed(job: job, error: errorMsg)
        HistoryManager.shared.addJob(job)
        statusBarController?.updateCompletedJobs(HistoryManager.shared.jobs)
        updateQueueDisplay()
        statusBarController?.showTranscriptionFailed(fileName: job.sourceFileName, error: errorMsg)
    }
}
