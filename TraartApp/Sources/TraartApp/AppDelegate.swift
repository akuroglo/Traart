import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var fileWatcher: FileWatcher?
    private var transcriptionManager: TranscriptionManager?
    private var setupManager: SetupManager?
    private var onboardingController: OnboardingWindowController?

    private static let onboardingKey = "hasCompletedOnboarding"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize settings
        _ = SettingsManager.shared

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

        // Onboarding or normal launch
        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            showOnboarding()
        } else if SetupManager.needsSetup {
            statusBarController?.updateStatus("Требуется настройка")
            NotificationManager.shared.notifySetupRequired()
            startSetup()
        } else {
            startFileWatcher()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
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
            self.onboardingController = nil
            if SetupManager.needsSetup {
                self.startSetup()
            } else {
                self.startFileWatcher()
            }
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

    private func startSetup() {
        guard setupManager == nil || !(setupManager?.isSettingUp ?? false) else { return }

        let sm = SetupManager()
        setupManager = sm

        statusBarController?.updateStatus("Установка окружения...")

        sm.onProgressUpdate = { [weak self] progress, status in
            self?.statusBarController?.showSetupProgress(progress, status: status)
        }

        sm.startSetup { [weak self] success in
            guard let self = self else { return }
            if success {
                self.statusBarController?.showSetupCompleted()
                self.startFileWatcher()
            } else {
                let detail = self.setupManager?.setupStatus ?? "Неизвестная ошибка"
                self.statusBarController?.showSetupFailed(error: detail)
            }
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
        // Check if setup is needed first
        if SetupManager.needsSetup {
            statusBarController?.showSetupRequired()
            NotificationManager.shared.notifySetupRequired()
            startSetup()
            return
        }

        // Remove from detected files
        fileWatcher?.removeDetectedFile(url)
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
