import AppKit
import UniformTypeIdentifiers

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    // Dynamic menu items that need updates
    private var statusMenuItem: NSMenuItem?
    private var progressViewItem: NSMenuItem?
    private var progressView: TranscriptionProgressView?
    private var cancelItem: NSMenuItem?
    private var currentFileName: String = ""
    private var currentEtaString: String?
    private var currentStep: TranscriptionJob.TranscriptionStep?
    private var newFilesItem: NSMenuItem?
    private var newFilesSubmenu: NSMenu?
    private var historySubmenu: NSMenu?
    private var copyLastItem: NSMenuItem?

    // Settings submenu items
    private var autoTranscribeItem: NSMenuItem?
    private var qualitySliderItem: NSMenuItem?
    private var qualityLabelItem: NSMenuItem?
    private var dualTranscriptionItem: NSMenuItem?
    private var diarizationItem: NSMenuItem?
    private var speakersSubmenu: NSMenu?
    private var monitorDiskItem: NSMenuItem?
    private var watchedFoldersItem: NSMenuItem?
    private var formatSubmenu: NSMenu?
    private var fileTypesSubmenu: NSMenu?
    private var outputNextToFileItem: NSMenuItem?
    private var outputFolderPathItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?

    // Detailed settings panel
    private var detailedSettingsController: DetailedSettingsController?

    // Queue display
    private var queueItems: [NSMenuItem] = []

    // External handlers
    var onTranscribeFile: ((URL) -> Void)?
    var onStartSetup: (() -> Void)?
    var onCancelTranscription: (() -> Void)?
    var onRetryJob: ((URL) -> Void)?
    var onOpenOutputFolder: (() -> Void)?
    var onMenuWillOpen: (() -> Void)?

    private var detectedFiles: [URL] = []
    private var completedJobs: [TranscriptionJob] = []

    // Icon state
    private var currentIconState: IconState = .idle
    private var currentProgress: Double = 0.0
    private var isTranscribing: Bool = false
    private var isSettingUp: Bool = false
    private var hasError: Bool = false
    private var completedResetTimer: Timer?

    override init() {
        super.init()
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            setIconState(.idle)

            // Enable drag-and-drop on the status bar button
            button.window?.registerForDraggedTypes([.fileURL])
            let dragView = DragDropView(frame: button.bounds)
            dragView.autoresizingMask = [.width, .height]
            dragView.onFilesDropped = { [weak self] urls in
                for url in urls {
                    self?.onTranscribeFile?(url)
                }
            }
            button.addSubview(dragView)
        }

        buildMenu()
        statusItem?.menu = menu
        menu.delegate = self
    }

    // MARK: - Icon State

    private func setIconState(_ state: IconState) {
        currentIconState = state
        guard let button = statusItem?.button else { return }

        completedResetTimer?.invalidate()
        completedResetTimer = nil

        let image = StatusBarIconRenderer.render(state: state)
        button.image = image

        switch state {
        case .idle:
            isTranscribing = false
            hasError = false
            button.title = ""
        case .transcribing(let progress):
            isTranscribing = true
            hasError = false
            let pct = Int(progress * 100)
            let titleAttr = NSAttributedString(
                string: " \(pct)%",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
                    .baselineOffset: 0.5
                ]
            )
            button.attributedTitle = titleAttr
        case .completed:
            isTranscribing = false
            hasError = false
            button.title = ""
            // Return to idle after 3 seconds
            completedResetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.setIconState(.idle)
            }
        case .error:
            isTranscribing = false
            hasError = true
            button.title = ""
        }
    }

    private func clearErrorIconIfNeeded() {
        guard hasError, !isTranscribing else { return }
        setIconState(.idle)
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        menu.removeAllItems()

        // Progress view (hidden by default, shown during transcription)
        let pView = TranscriptionProgressView(frame: NSRect(x: 0, y: 0, width: 280, height: 58))
        let pvItem = NSMenuItem()
        pvItem.view = pView
        pvItem.isHidden = true
        self.progressView = pView
        self.progressViewItem = pvItem
        menu.addItem(pvItem)

        // Cancel (hidden by default, shown during transcription)
        let cancelItem = NSMenuItem(
            title: "Отменить транскрибацию",
            action: #selector(cancelTranscription(_:)),
            keyEquivalent: "."
        )
        cancelItem.target = self
        cancelItem.isHidden = true
        self.cancelItem = cancelItem
        menu.addItem(cancelItem)

        // Status (hidden by default, shown for setup/errors)
        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusItem.isHidden = true
        self.statusMenuItem = statusItem
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // === Copy last transcription — first visible in idle ===
        let copyItem = NSMenuItem(
            title: "Копировать последнюю транскрипцию",
            action: #selector(copyLastTranscription(_:)),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = [.command, .shift]
        copyItem.target = self
        copyItem.isEnabled = false
        if let clipboardIcon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
            clipboardIcon.isTemplate = true
            copyItem.image = clipboardIcon
        }
        self.copyLastItem = copyItem
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        // === Actions ===

        // Manual file picker
        let pickFileItem = NSMenuItem(
            title: "Транскрибировать файл...",
            action: #selector(pickFileForTranscription(_:)),
            keyEquivalent: "o"
        )
        pickFileItem.target = self
        menu.addItem(pickFileItem)

        menu.addItem(NSMenuItem.separator())

        // New files submenu (shows count)
        let newFilesItem = NSMenuItem(title: "Новые файлы", action: nil, keyEquivalent: "")
        let filesSubmenu = NSMenu()
        self.newFilesSubmenu = filesSubmenu
        self.newFilesItem = newFilesItem
        newFilesItem.submenu = filesSubmenu
        rebuildNewFilesSubmenu()
        menu.addItem(newFilesItem)

        // History submenu
        let historyItem = NSMenuItem(title: "История", action: nil, keyEquivalent: "")
        let hSubmenu = NSMenu()
        self.historySubmenu = hSubmenu
        rebuildHistorySubmenu()
        historyItem.submenu = hSubmenu
        menu.addItem(historyItem)

        // Open output folder
        let openFolderItem = NSMenuItem(
            title: "Открыть папку транскрипций",
            action: #selector(openOutputFolder(_:)),
            keyEquivalent: "O"
        )
        openFolderItem.keyEquivalentModifierMask = [.command, .shift]
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(NSMenuItem.separator())

        // === Settings submenu ===
        let settingsItem = NSMenuItem(title: "Настройки", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()
        buildSettingsSubmenu(settingsSubmenu)
        settingsItem.submenu = settingsSubmenu
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Share app — single-line button with Telegram icon (custom view, doesn't close menu)
        let shareContainer = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        let shareBtn = NSButton(title: "Рассказать другу", target: self, action: #selector(copyShareText(_:)))
        shareBtn.isBordered = false
        shareBtn.font = NSFont.menuFont(ofSize: 13)
        shareBtn.alignment = .left
        shareBtn.imagePosition = .imageLeading
        shareBtn.frame = NSRect(x: 14, y: 1, width: 230, height: 22)
        if let icon = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            shareBtn.image = icon.withSymbolConfiguration(config)
            shareBtn.contentTintColor = .systemBlue
        }
        shareContainer.addSubview(shareBtn)
        let shareItem = NSMenuItem()
        shareItem.view = shareContainer
        menu.addItem(shareItem)

        // About (includes "Поделиться логами")
        let aboutItem = NSMenuItem(
            title: "О программе",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Выход",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    /// Create a toggle menu item with custom view (doesn't close menu on click).
    private func makeToggleItem(
        title: String,
        isOn: Bool,
        action: Selector
    ) -> NSMenuItem {
        let menuItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 24))

        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.state = isOn ? .on : .off
        button.font = NSFont.menuFont(ofSize: 13)
        button.frame = NSRect(x: 18, y: 1, width: 230, height: 22)
        container.addSubview(button)

        menuItem.view = container
        return menuItem
    }

    /// Find the NSButton inside a toggle menu item's view.
    private func toggleButton(in item: NSMenuItem?) -> NSButton? {
        item?.view?.subviews.first(where: { $0 is NSButton }) as? NSButton
    }

    private func buildSettingsSubmenu(_ submenu: NSMenu) {
        let settings = SettingsManager.shared

        // Auto-transcribe toggle (custom view — doesn't close menu)
        let autoItem = makeToggleItem(
            title: "Автотранскрибация",
            isOn: settings.autoTranscribe,
            action: #selector(toggleAutoTranscribe(_:))
        )
        self.autoTranscribeItem = autoItem
        submenu.addItem(autoItem)

        submenu.addItem(NSMenuItem.separator())

        // Quality preset section
        let qualityLabel = NSMenuItem(
            title: "Качество: \(settings.qualityPresetName)",
            action: nil,
            keyEquivalent: ""
        )
        qualityLabel.isEnabled = false
        self.qualityLabelItem = qualityLabel
        submenu.addItem(qualityLabel)

        // Custom NSView with slider
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 40))

        let leftLabel = NSTextField(labelWithString: "Быстро")
        leftLabel.font = NSFont.systemFont(ofSize: 9)
        leftLabel.textColor = .secondaryLabelColor
        leftLabel.frame = NSRect(x: 20, y: 2, width: 50, height: 14)
        sliderView.addSubview(leftLabel)

        let rightLabel = NSTextField(labelWithString: "Макс. качество")
        rightLabel.font = NSFont.systemFont(ofSize: 9)
        rightLabel.textColor = .secondaryLabelColor
        rightLabel.alignment = .right
        rightLabel.frame = NSRect(x: 170, y: 2, width: 65, height: 14)
        sliderView.addSubview(rightLabel)

        let slider = NSSlider(value: Double(settings.qualityPreset), minValue: 0, maxValue: 4, target: self, action: #selector(qualitySliderChanged(_:)))
        slider.numberOfTickMarks = 5
        slider.allowsTickMarkValuesOnly = true
        slider.frame = NSRect(x: 20, y: 16, width: 215, height: 20)
        slider.tag = 999
        sliderView.addSubview(slider)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        self.qualitySliderItem = sliderItem
        submenu.addItem(sliderItem)

        // Dual transcription (visible only at max quality)
        let dualItem = makeToggleItem(
            title: "Два файла: с диаризацией и без",
            isOn: settings.dualTranscription,
            action: #selector(toggleDualTranscription(_:))
        )
        dualItem.isHidden = settings.qualityPreset != 4
        self.dualTranscriptionItem = dualItem
        submenu.addItem(dualItem)

        // Detailed settings
        let detailedItem = NSMenuItem(
            title: "Детальные настройки...",
            action: #selector(openDetailedSettings(_:)),
            keyEquivalent: ""
        )
        detailedItem.target = self
        submenu.addItem(detailedItem)

        submenu.addItem(NSMenuItem.separator())

        // Diarization toggle (custom view — doesn't close menu)
        let diarItem = makeToggleItem(
            title: "Диаризация (разделение голосов)",
            isOn: settings.enableDiarization,
            action: #selector(toggleDiarization(_:))
        )
        self.diarizationItem = diarItem
        submenu.addItem(diarItem)

        // Speakers count submenu
        let currentSpeakers = settings.expectedSpeakers
        let speakersLabel = currentSpeakers == 0 ? "Авто" : "\(currentSpeakers)"
        let speakersItem = NSMenuItem(
            title: "Спикеры: \(speakersLabel)",
            action: nil,
            keyEquivalent: ""
        )
        let spkSubmenu = NSMenu()
        self.speakersSubmenu = spkSubmenu

        let autoDetectItem = NSMenuItem(
            title: "Авто",
            action: #selector(selectSpeakers(_:)),
            keyEquivalent: ""
        )
        autoDetectItem.target = self
        autoDetectItem.tag = 0
        autoDetectItem.state = (currentSpeakers == 0) ? .on : .off
        spkSubmenu.addItem(autoDetectItem)
        spkSubmenu.addItem(NSMenuItem.separator())

        for i in 1...10 {
            let item = NSMenuItem(
                title: "\(i)",
                action: #selector(selectSpeakers(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = i
            item.state = (i == currentSpeakers) ? .on : .off
            spkSubmenu.addItem(item)
        }
        speakersItem.submenu = spkSubmenu
        submenu.addItem(speakersItem)

        // Output format submenu
        let currentFormat = settings.outputFormat
        let formatLabels: [(format: String, label: String)] = [
            ("md", "Markdown (.md)"),
            ("txt", "Текст (.txt)"),
            ("json", "JSON (.json)"),
            ("srt", "Субтитры SRT (.srt)"),
            ("vtt", "Субтитры VTT (.vtt)"),
        ]
        let formatItem = NSMenuItem(
            title: "Формат: \(formatLabels.first { $0.format == currentFormat }?.label ?? "Markdown (.md)")",
            action: nil,
            keyEquivalent: ""
        )
        let fmtSubmenu = NSMenu()
        self.formatSubmenu = fmtSubmenu
        for (i, entry) in formatLabels.enumerated() {
            let item = NSMenuItem(
                title: entry.label,
                action: #selector(selectFormat(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = i
            item.representedObject = entry.format as NSString
            item.state = (entry.format == currentFormat) ? .on : .off
            fmtSubmenu.addItem(item)
        }
        formatItem.submenu = fmtSubmenu
        submenu.addItem(formatItem)

        // File types filter
        let currentFileTypes = settings.monitoredFileTypes
        let fileTypeLabels: [(key: String, label: String)] = [
            ("audio", "Только аудио"),
            ("video", "Только видео"),
            ("all", "Аудио и видео"),
        ]
        let ftLabel = fileTypeLabels.first { $0.key == currentFileTypes }?.label ?? "Только аудио"
        let ftItem = NSMenuItem(
            title: "Типы файлов: \(ftLabel)",
            action: nil,
            keyEquivalent: ""
        )
        let ftSubmenu = NSMenu()
        self.fileTypesSubmenu = ftSubmenu
        for entry in fileTypeLabels {
            let item = NSMenuItem(
                title: entry.label,
                action: #selector(selectFileTypes(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = entry.key as NSString
            item.state = (entry.key == currentFileTypes) ? .on : .off
            ftSubmenu.addItem(item)
        }
        ftItem.submenu = ftSubmenu
        submenu.addItem(ftItem)

        submenu.addItem(NSMenuItem.separator())

        // --- Monitoring section ---
        // Toggle "Мониторить весь диск" (doesn't close menu)
        let diskItem = makeToggleItem(
            title: "Мониторить весь диск",
            isOn: settings.monitorEntireDisk,
            action: #selector(toggleMonitorDisk(_:))
        )
        self.monitorDiskItem = diskItem
        submenu.addItem(diskItem)

        // Watched folders — disabled when "весь диск" is on
        let watchedPaths = settings.watchedFolders.map { $0.lastPathComponent }
        let watchedLabel = watchedPaths.isEmpty ? "Выбрать папки..." :
            "Папки: \(watchedPaths.joined(separator: ", "))"
        let wfItem = NSMenuItem(
            title: String(watchedLabel.prefix(60)) + (watchedLabel.count > 60 ? "..." : ""),
            action: #selector(selectWatchedFolders(_:)),
            keyEquivalent: ""
        )
        wfItem.target = self
        wfItem.isEnabled = !settings.monitorEntireDisk
        self.watchedFoldersItem = wfItem
        submenu.addItem(wfItem)

        submenu.addItem(NSMenuItem.separator())

        // --- Output location section ---
        // Toggle "Сохранять рядом с файлом" (doesn't close menu)
        let nextToFileItem = makeToggleItem(
            title: "Сохранять рядом с файлом",
            isOn: settings.saveNextToFile,
            action: #selector(toggleOutputNextToFile(_:))
        )
        self.outputNextToFileItem = nextToFileItem
        submenu.addItem(nextToFileItem)

        // Output folder — disabled when "рядом с файлом" is on
        let folderLabel: String
        if let outputFolder = settings.outputFolder {
            folderLabel = "Папка: ~/\(outputFolder.lastPathComponent)"
        } else {
            folderLabel = "Выбрать папку..."
        }
        let folderItem = NSMenuItem(
            title: folderLabel,
            action: #selector(selectOutputFolder(_:)),
            keyEquivalent: ""
        )
        folderItem.target = self
        folderItem.isEnabled = !settings.saveNextToFile
        self.outputFolderPathItem = folderItem
        submenu.addItem(folderItem)

        submenu.addItem(NSMenuItem.separator())

        // Launch at login (custom view — doesn't close menu)
        let loginItem = makeToggleItem(
            title: "Запускать при входе в систему",
            isOn: settings.launchAtLogin,
            action: #selector(toggleLaunchAtLogin(_:))
        )
        self.launchAtLoginItem = loginItem
        submenu.addItem(loginItem)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        clearErrorIconIfNeeded()
        refreshMenuState()
        onMenuWillOpen?()
    }

    // MARK: - Public API for updating state

    func updateStatus(_ text: String) {
        statusMenuItem?.title = text
        statusMenuItem?.isHidden = (text == "Готово")
    }

    func updateDetectedFiles(_ files: [URL]) {
        self.detectedFiles = files
        rebuildNewFilesSubmenu()
    }

    func updateCompletedJobs(_ jobs: [TranscriptionJob]) {
        self.completedJobs = jobs
        rebuildHistorySubmenu()
        // Enable copy button if there's a completed job
        copyLastItem?.isEnabled = jobs.contains { $0.status == .completed }
    }

    func updateQueue(_ queue: [TranscriptionJob]) {
        // Remove old queue items
        for item in queueItems {
            menu.removeItem(item)
        }
        queueItems.removeAll()

        guard !queue.isEmpty, let cancel = cancelItem else { return }
        guard let baseIdx = menu.items.firstIndex(of: cancel) else { return }
        var idx = baseIdx + 1

        let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "В очереди (\(queue.count)):",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        header.isEnabled = false
        menu.insertItem(header, at: idx)
        queueItems.append(header)
        idx += 1

        for job in queue {
            let item = NSMenuItem(title: "    \(job.sourceFileName)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            menu.insertItem(item, at: idx)
            queueItems.append(item)
            idx += 1
        }
    }

    func showSetupProgress(_ progress: Double, status: String) {
        isSettingUp = true
        let pct = Int(progress * 100)
        statusMenuItem?.title = "Установка: \(pct)% — \(status)"
        statusMenuItem?.isHidden = false
        progressViewItem?.isHidden = true
        cancelItem?.isHidden = true
        currentProgress = progress
        setIconState(.transcribing(progress: progress))
    }

    func showSetupCompleted() {
        isSettingUp = false
        progressViewItem?.isHidden = true
        cancelItem?.isHidden = true
        statusMenuItem?.isHidden = true
        progressView?.stopAnimations()
        setIconState(.idle)
    }

    func showSetupFailed(error: String) {
        isSettingUp = false
        progressViewItem?.isHidden = true
        cancelItem?.isHidden = true
        progressView?.stopAnimations()
        setIconState(.error)
        statusMenuItem?.title = "Ошибка установки: \(String(error.prefix(60)))"
        statusMenuItem?.isHidden = false
    }

    func showTranscriptionStarted(fileName: String) {
        currentProgress = 0.02
        currentFileName = fileName
        currentEtaString = nil
        currentStep = nil
        progressView?.update(fileName: fileName, progress: 0.02, step: nil, etaString: nil)
        progressViewItem?.isHidden = false
        cancelItem?.isHidden = false
        statusMenuItem?.isHidden = true
        setIconState(.transcribing(progress: 0))
    }

    func showTranscriptionProgress(_ progress: Double, fileName: String, step: TranscriptionJob.TranscriptionStep? = nil, etaSeconds: Double? = nil) {
        currentProgress = progress
        currentFileName = fileName
        currentStep = step
        setIconState(.transcribing(progress: progress))

        // Compute ETA string
        if let eta = etaSeconds, eta > 0 {
            let m = Int(eta) / 60
            let s = Int(eta) % 60
            currentEtaString = m > 0 ? "~\(m)м \(s)с" : "~\(s)с"
        } else {
            currentEtaString = nil
        }

        progressView?.update(fileName: fileName, progress: progress, step: step, etaString: currentEtaString)
        progressViewItem?.isHidden = false
    }

    func showTranscriptionCompleted(fileName: String) {
        progressViewItem?.isHidden = true
        cancelItem?.isHidden = true
        statusMenuItem?.isHidden = true
        progressView?.stopAnimations()
        setIconState(.completed)
    }

    func showTranscriptionFailed(fileName: String, error: String) {
        setIconState(.error)
        progressViewItem?.isHidden = true
        cancelItem?.isHidden = true
        progressView?.stopAnimations()
        statusMenuItem?.title = "Ошибка: \(String(error.prefix(80)))"
        statusMenuItem?.isHidden = false
    }

    func showSetupRequired() {
        setIconState(.error)
        statusMenuItem?.title = "Требуется настройка"
        statusMenuItem?.isHidden = false
    }

    // MARK: - Refresh

    private func refreshMenuState() {
        let settings = SettingsManager.shared

        // Update toggle buttons inside custom views
        toggleButton(in: autoTranscribeItem)?.state = settings.autoTranscribe ? .on : .off
        toggleButton(in: diarizationItem)?.state = settings.enableDiarization ? .on : .off
        toggleButton(in: monitorDiskItem)?.state = settings.monitorEntireDisk ? .on : .off
        toggleButton(in: launchAtLoginItem)?.state = settings.launchAtLogin ? .on : .off

        // Update dual transcription visibility + state
        let isMaxQuality = settings.qualityPreset == 4
        dualTranscriptionItem?.isHidden = !isMaxQuality
        toggleButton(in: dualTranscriptionItem)?.state = settings.dualTranscription ? .on : .off

        // Update quality slider and label
        qualityLabelItem?.title = "Качество: \(settings.qualityPresetName)"
        if let sliderView = qualitySliderItem?.view,
           let slider = sliderView.subviews.first(where: { $0 is NSSlider }) as? NSSlider {
            let presetIdx = settings.qualityPreset
            slider.doubleValue = presetIdx >= 0 ? Double(presetIdx) : 2.0
        }

        // Update speakers submenu
        if let spkMenu = speakersSubmenu {
            for item in spkMenu.items {
                item.state = (item.tag == settings.expectedSpeakers) ? .on : .off
            }
            let speakersLabel = settings.expectedSpeakers == 0 ? "Авто" : "\(settings.expectedSpeakers)"
            if let parentItem = spkMenu.supermenu?.items.first(where: { $0.submenu === spkMenu }) {
                parentItem.title = "Спикеры: \(speakersLabel)"
            }
        }

        // Update format submenu
        if let fmtMenu = formatSubmenu {
            let currentFormat = settings.outputFormat
            for item in fmtMenu.items {
                item.state = ((item.representedObject as? NSString) as String? == currentFormat) ? .on : .off
            }
            if let parentItem = fmtMenu.supermenu?.items.first(where: { $0.submenu === fmtMenu }) {
                let label = fmtMenu.items.first { ($0.representedObject as? NSString) as String? == currentFormat }?.title ?? "Markdown (.md)"
                parentItem.title = "Формат: \(label)"
            }
        }

        // Update file types submenu
        if let ftMenu = fileTypesSubmenu {
            let currentFT = settings.monitoredFileTypes
            for item in ftMenu.items {
                item.state = ((item.representedObject as? NSString) as String? == currentFT) ? .on : .off
            }
            if let parentItem = ftMenu.supermenu?.items.first(where: { $0.submenu === ftMenu }) {
                let label = ftMenu.items.first { ($0.representedObject as? NSString) as String? == currentFT }?.title ?? "Только аудио"
                parentItem.title = "Типы файлов: \(label)"
            }
        }

        // Update monitoring section
        let watchedPaths = settings.watchedFolders.map { $0.lastPathComponent }
        if watchedPaths.isEmpty {
            watchedFoldersItem?.title = "Выбрать папки..."
        } else {
            let label = "Папки: \(watchedPaths.joined(separator: ", "))"
            watchedFoldersItem?.title = String(label.prefix(60)) + (label.count > 60 ? "..." : "")
        }
        watchedFoldersItem?.isEnabled = !settings.monitorEntireDisk

        // Update output location toggle and folder item
        toggleButton(in: outputNextToFileItem)?.state = settings.saveNextToFile ? .on : .off
        outputFolderPathItem?.isEnabled = !settings.saveNextToFile
        if let outputFolder = settings.outputFolder {
            outputFolderPathItem?.title = "Папка: ~/\(outputFolder.lastPathComponent)"
        } else {
            outputFolderPathItem?.title = "Выбрать папку..."
        }

        // Update transcription progress visibility (never show during setup)
        let showTranscriptionUI = isTranscribing && !isSettingUp
        progressViewItem?.isHidden = !showTranscriptionUI
        cancelItem?.isHidden = !showTranscriptionUI
        if showTranscriptionUI {
            progressView?.update(fileName: currentFileName, progress: currentProgress, step: currentStep, etaString: currentEtaString)
        }

        rebuildNewFilesSubmenu()
        rebuildHistorySubmenu()
    }

    private func rebuildNewFilesSubmenu() {
        guard let submenu = newFilesSubmenu else { return }
        submenu.removeAllItems()

        // Update parent title with count
        let count = detectedFiles.count
        if count > 0 {
            newFilesItem?.title = "Новые файлы (\(count))"
        } else {
            newFilesItem?.title = "Новые файлы"
        }

        if detectedFiles.isEmpty {
            let emptyItem = NSMenuItem(title: "(Нет новых файлов)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            // "Transcribe all" option if multiple files
            if detectedFiles.count > 1 {
                let allItem = NSMenuItem(
                    title: "Транскрибировать все (\(detectedFiles.count))",
                    action: #selector(transcribeAllDetected(_:)),
                    keyEquivalent: ""
                )
                allItem.target = self
                submenu.addItem(allItem)
                submenu.addItem(NSMenuItem.separator())
            }

            for file in detectedFiles {
                let item = NSMenuItem(
                    title: file.lastPathComponent,
                    action: #selector(transcribeFile(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = file
                submenu.addItem(item)
            }
        }
    }

    private func rebuildHistorySubmenu() {
        guard let submenu = historySubmenu else { return }
        submenu.removeAllItems()

        if completedJobs.isEmpty {
            let emptyItem = NSMenuItem(title: "(Нет истории)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
            return
        }

        for job in completedJobs.prefix(20) {
            let statusIcon: String
            switch job.status {
            case .completed:
                statusIcon = job.warningsCount > 0 ? "\u{26A0}\u{FE0F}" : "\u{2705}"
            case .failed: statusIcon = "\u{274C}"
            case .cancelled: statusIcon = "\u{23F9}"
            default: statusIcon = "\u{2753}"
            }

            let warningStr = job.warningsCount > 0 ? " [\(job.warningsCount) warn]" : ""
            let durationStr = job.durationString.map { " (\($0))" } ?? ""
            let title = "\(statusIcon) \(job.sourceFileName)\(durationStr)\(warningStr)"

            // Each history item has a submenu with actions
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let actionSubmenu = NSMenu()

            if job.status == .completed, let outputFile = job.outputFile {
                // Open file
                let openItem = NSMenuItem(
                    title: "Открыть файл",
                    action: #selector(openFile(_:)),
                    keyEquivalent: ""
                )
                openItem.target = self
                openItem.representedObject = outputFile
                actionSubmenu.addItem(openItem)

                // Reveal in Finder
                let revealItem = NSMenuItem(
                    title: "Показать в Finder",
                    action: #selector(revealInFinder(_:)),
                    keyEquivalent: ""
                )
                revealItem.target = self
                revealItem.representedObject = outputFile
                actionSubmenu.addItem(revealItem)

                // Copy text
                let copyItem = NSMenuItem(
                    title: "Копировать текст",
                    action: #selector(copyTranscriptionText(_:)),
                    keyEquivalent: ""
                )
                copyItem.target = self
                copyItem.representedObject = job.id.uuidString as NSString
                actionSubmenu.addItem(copyItem)
            }

            if job.status == .failed {
                // Show error
                if let error = job.error {
                    let errorItem = NSMenuItem(title: "Ошибка: \(String(error.prefix(80)))", action: nil, keyEquivalent: "")
                    errorItem.isEnabled = false
                    actionSubmenu.addItem(errorItem)
                }
            }

            // Re-transcribe (for any status)
            actionSubmenu.addItem(NSMenuItem.separator())
            let retryItem = NSMenuItem(
                title: "Транскрибировать заново",
                action: #selector(retryTranscription(_:)),
                keyEquivalent: ""
            )
            retryItem.target = self
            retryItem.representedObject = job.sourceFile
            actionSubmenu.addItem(retryItem)

            item.submenu = actionSubmenu
            submenu.addItem(item)
        }

        // Open log
        let logFile = SettingsManager.shared.appSupportDirectory
            .appendingPathComponent("transcription.log")
        if FileManager.default.fileExists(atPath: logFile.path) {
            submenu.addItem(NSMenuItem.separator())
            let logItem = NSMenuItem(
                title: "Открыть лог предупреждений",
                action: #selector(openTranscriptionLog(_:)),
                keyEquivalent: ""
            )
            logItem.target = self
            submenu.addItem(logItem)
        }

        // Clear history
        submenu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(
            title: "Очистить историю",
            action: #selector(clearHistory(_:)),
            keyEquivalent: ""
        )
        clearItem.target = self
        submenu.addItem(clearItem)
    }

    // MARK: - Actions

    @objc private func transcribeFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? URL else { return }
        onTranscribeFile?(file)
    }

    @objc private func transcribeAllDetected(_ sender: NSMenuItem) {
        for file in detectedFiles {
            onTranscribeFile?(file)
        }
    }

    @objc private func cancelTranscription(_ sender: NSMenuItem) {
        onCancelTranscription?()
        cancelItem?.isHidden = true
        progressViewItem?.isHidden = true
        progressView?.stopAnimations()
        setIconState(.idle)
    }

    @objc private func pickFileForTranscription(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.title = "Выберите аудио или видео файл"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        // .audio/.movie cover most formats, but .ogg, .mkv, .webm, .opus may
        // have UTTypes that don't conform to public.audio/movie — add them explicitly
        var types: [UTType] = [.audio, .movie, .video]
        for ext in ["ogg", "oga", "opus", "mkv", "webm", "wma", "amr"] {
            if let t = UTType(filenameExtension: ext), !types.contains(t) {
                types.append(t)
            }
        }
        panel.allowedContentTypes = types

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK {
            for url in panel.urls {
                onTranscribeFile?(url)
            }
        }
    }

    @objc private func openOutputFolder(_ sender: NSMenuItem) {
        onOpenOutputFolder?()
    }

    @objc private func copyLastTranscription(_ sender: NSMenuItem) {
        guard let lastCompleted = completedJobs.first(where: { $0.status == .completed }) else { return }
        if let text = HistoryManager.shared.fullText(for: lastCompleted) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    @objc private func openFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func revealInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func copyTranscriptionText(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? NSString,
              let uuid = UUID(uuidString: idString as String) else { return }
        let jobs = HistoryManager.shared.jobs
        guard let job = jobs.first(where: { $0.id == uuid }) else { return }
        if let text = HistoryManager.shared.fullText(for: job) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    @objc private func openTranscriptionLog(_ sender: NSMenuItem) {
        let logFile = SettingsManager.shared.appSupportDirectory
            .appendingPathComponent("transcription.log")
        NSWorkspace.shared.open(logFile)
    }

    @objc private func retryTranscription(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onRetryJob?(url)
    }

    @objc private func clearHistory(_ sender: NSMenuItem) {
        HistoryManager.shared.clearAll()
        completedJobs = []
        rebuildHistorySubmenu()
        copyLastItem?.isEnabled = false
    }

    // MARK: - Quality Actions

    @objc private func qualitySliderChanged(_ sender: NSSlider) {
        let index = Int(sender.doubleValue)
        SettingsManager.shared.applyPreset(index)
        qualityLabelItem?.title = "Качество: \(SettingsManager.shared.qualityPresetName)"

        // Show dual transcription option only at max quality
        let isMax = index == 4
        dualTranscriptionItem?.isHidden = !isMax
        if !isMax {
            SettingsManager.shared.dualTranscription = false
            toggleButton(in: dualTranscriptionItem)?.state = .off
        }
    }

    @objc private func openDetailedSettings(_ sender: NSMenuItem) {
        if detailedSettingsController == nil {
            detailedSettingsController = DetailedSettingsController()
        }
        detailedSettingsController?.showPanel()
    }

    // MARK: - Settings Actions

    @objc private func toggleAutoTranscribe(_ sender: Any) {
        SettingsManager.shared.autoTranscribe.toggle()
        if let btn = sender as? NSButton {
            btn.state = SettingsManager.shared.autoTranscribe ? .on : .off
        }
    }

    @objc private func toggleDualTranscription(_ sender: Any) {
        SettingsManager.shared.dualTranscription.toggle()
        if let btn = sender as? NSButton {
            btn.state = SettingsManager.shared.dualTranscription ? .on : .off
        }
    }

    @objc private func toggleDiarization(_ sender: Any) {
        SettingsManager.shared.enableDiarization.toggle()
        if let btn = sender as? NSButton {
            btn.state = SettingsManager.shared.enableDiarization ? .on : .off
        }
    }

    @objc private func selectSpeakers(_ sender: NSMenuItem) {
        SettingsManager.shared.expectedSpeakers = sender.tag
        if let spkMenu = speakersSubmenu {
            for item in spkMenu.items {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
            let label = sender.tag == 0 ? "Авто" : "\(sender.tag)"
            if let parentItem = spkMenu.supermenu?.items.first(where: { $0.submenu === spkMenu }) {
                parentItem.title = "Спикеры: \(label)"
            }
        }
    }

    @objc private func selectFormat(_ sender: NSMenuItem) {
        guard let format = sender.representedObject as? NSString else { return }
        SettingsManager.shared.outputFormat = format as String
        if let fmtMenu = formatSubmenu {
            for item in fmtMenu.items {
                item.state = (item.representedObject as? NSString == format) ? .on : .off
            }
            if let parentItem = fmtMenu.supermenu?.items.first(where: { $0.submenu === fmtMenu }) {
                parentItem.title = "Формат: \(sender.title)"
            }
        }
    }

    @objc private func selectFileTypes(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? NSString else { return }
        SettingsManager.shared.monitoredFileTypes = key as String
        if let ftMenu = fileTypesSubmenu {
            for item in ftMenu.items {
                item.state = (item.representedObject as? NSString == key) ? .on : .off
            }
            if let parentItem = ftMenu.supermenu?.items.first(where: { $0.submenu === ftMenu }) {
                parentItem.title = "Типы файлов: \(sender.title)"
            }
        }
    }

    @objc private func selectWatchedFolders(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.title = "Выберите папки для мониторинга"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true

        if let first = SettingsManager.shared.watchedFolders.first {
            panel.directoryURL = first
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK {
            SettingsManager.shared.watchedFolders = panel.urls
        }
    }

    @objc private func toggleOutputNextToFile(_ sender: Any) {
        let settings = SettingsManager.shared
        settings.saveNextToFile.toggle()
        let isOn = settings.saveNextToFile
        if let btn = sender as? NSButton {
            btn.state = isOn ? .on : .off
        }
        outputFolderPathItem?.isEnabled = !isOn
    }

    @objc private func selectOutputFolder(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.title = "Выберите папку для транскрипций"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if let current = SettingsManager.shared.outputFolder {
            panel.directoryURL = current
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            let settings = SettingsManager.shared
            settings.outputFolder = url
            settings.saveNextToFile = false
            toggleButton(in: outputNextToFileItem)?.state = .off
            outputFolderPathItem?.title = "Папка: ~/\(url.lastPathComponent)"
            outputFolderPathItem?.isEnabled = true
        }
    }

    @objc private func toggleMonitorDisk(_ sender: Any) {
        SettingsManager.shared.monitorEntireDisk.toggle()
        let isOn = SettingsManager.shared.monitorEntireDisk
        if let btn = sender as? NSButton {
            btn.state = isOn ? .on : .off
        }
        watchedFoldersItem?.isEnabled = !isOn
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any) {
        let newValue = !SettingsManager.shared.launchAtLogin
        SettingsManager.shared.launchAtLogin = newValue
        AppDelegate.updateLaunchAtLogin(enabled: newValue)
        if let btn = sender as? NSButton {
            btn.state = newValue ? .on : .off
        }
    }

    // MARK: - Share App

    @objc private func copyShareText(_ sender: NSButton) {
        let text = """
        Traart — бесплатная транскрибация аудио и видео на Mac \u{1F399}

        Работает полностью локально, без облака и подписок. Лучшая точность распознавания русской речи — в 2 раза точнее Whisper.

        traart.ru/download
        """
        // Trim leading whitespace from each line (heredoc indentation)
        let trimmed = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)

        // Visual feedback
        let original = sender.title
        sender.title = "\u{2705} Скопировано"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            sender.title = original
        }
    }

    @objc private func shareLogs(_ sender: NSMenuItem) {
        let appSupport = SettingsManager.shared.appSupportDirectory
        var sections: [String] = []

        // System info
        let processInfo = ProcessInfo.processInfo
        var sysinfo = utsname()
        uname(&sysinfo)
        let arch = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        sections.append("""
        === Traart Diagnostic Log ===
        Date: \(Date())
        App: \(appVersion) (\(buildNumber))
        macOS: \(processInfo.operatingSystemVersionString)
        Arch: \(arch)
        Python venv: \(SettingsManager.shared.pythonEnvPath.path)
        Venv exists: \(FileManager.default.fileExists(atPath: SettingsManager.shared.pythonExecutable.path))
        Standalone Python: \(FileManager.default.fileExists(atPath: appSupport.appendingPathComponent("python-standalone/bin/python3").path))
        """)

        // Setup log
        let setupLog = appSupport.appendingPathComponent("setup.log")
        if let content = try? String(contentsOf: setupLog, encoding: .utf8), !content.isEmpty {
            sections.append("=== setup.log ===\n\(content)")
        } else {
            sections.append("=== setup.log ===\n(отсутствует)")
        }

        // Transcription log
        let transcriptionLog = appSupport.appendingPathComponent("transcription.log")
        if let content = try? String(contentsOf: transcriptionLog, encoding: .utf8), !content.isEmpty {
            // Last 200 lines max
            let lines = content.components(separatedBy: .newlines)
            let tail = lines.suffix(200).joined(separator: "\n")
            sections.append("=== transcription.log (last 200 lines) ===\n\(tail)")
        } else {
            sections.append("=== transcription.log ===\n(отсутствует)")
        }

        let combined = sections.joined(separator: "\n\n")

        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("traart-diagnostic-\(Int(Date().timeIntervalSince1970)).log")
        try? combined.write(to: logFile, atomically: true, encoding: .utf8)

        // Show share sheet anchored to status bar button
        NSApp.activate(ignoringOtherApps: true)
        if let button = statusItem?.button {
            let picker = NSSharingServicePicker(items: [logFile])
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        let alert = NSAlert()
        alert.messageText = "Traart \(version)"
        alert.informativeText = """
            Автоматическая транскрибация аудио и видео на русском языке.

            Работает локально на Mac, без облака и подписок.
            Точность в 2 раза выше Whisper (GigaAM v3 + pyannote).

            traart.ru
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Открыть сайт")
        alert.addButton(withTitle: "Поделиться логами...")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://traart.ru")!)
        } else if response == .alertThirdButtonReturn {
            shareLogs(sender)
        }
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
