import AppKit

final class DetailedSettingsController {
    private var panel: NSPanel?

    // Slider references for reading values
    private var chunkDurationSlider: NSSlider?
    private var chunkOverlapSlider: NSSlider?
    private var mergeGapSlider: NSSlider?
    private var minSegmentSlider: NSSlider?
    private var expansionPadSlider: NSSlider?

    // Value labels
    private var chunkDurationLabel: NSTextField?
    private var chunkOverlapLabel: NSTextField?
    private var mergeGapLabel: NSTextField?
    private var minSegmentLabel: NSTextField?
    private var expansionPadLabel: NSTextField?

    // Preset indicator
    private var presetLabel: NSTextField?

    private var settingsObserver: Any?

    func showPanel() {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.title = "Детальные настройки транскрибации"
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = false
        p.level = .floating
        p.center()

        let contentView = NSView(frame: p.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        p.contentView = contentView

        let settings = SettingsManager.shared
        var y: CGFloat = 340

        // Preset label
        let presetText = NSTextField(labelWithString: "Пресет: \(settings.qualityPresetName)")
        presetText.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        presetText.frame = NSRect(x: 20, y: y, width: 380, height: 20)
        contentView.addSubview(presetText)
        self.presetLabel = presetText
        y -= 40

        // Chunk duration: 10–60
        y = addSliderRow(
            to: contentView, y: y,
            title: "Длина чанка (сек)",
            minValue: 10, maxValue: 60,
            currentValue: Double(settings.chunkDuration),
            tag: 1,
            integerOnly: true
        )

        // Chunk overlap: 0–10
        y = addSliderRow(
            to: contentView, y: y,
            title: "Перекрытие чанков (сек)",
            minValue: 0, maxValue: 10,
            currentValue: Double(settings.chunkOverlap),
            tag: 2,
            integerOnly: true
        )

        // Merge gap: 0.2–5.0
        y = addSliderRow(
            to: contentView, y: y,
            title: "Склейка сегментов спикера (сек)",
            minValue: 0.2, maxValue: 5.0,
            currentValue: settings.mergeGap,
            tag: 3,
            integerOnly: false
        )

        // Min segment: 0.1–1.0
        y = addSliderRow(
            to: contentView, y: y,
            title: "Мин. длина сегмента (сек)",
            minValue: 0.1, maxValue: 1.0,
            currentValue: settings.minSegmentDuration,
            tag: 4,
            integerOnly: false
        )

        // Expansion padding: 0–10
        y = addSliderRow(
            to: contentView, y: y,
            title: "Контекст для пустых сегментов (сек)",
            minValue: 0, maxValue: 10,
            currentValue: Double(settings.expansionPadding),
            tag: 5,
            integerOnly: true
        )

        // Reset button
        let resetButton = NSButton(title: "Сбросить по умолчанию", target: self, action: #selector(resetDefaults(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 20, y: 15, width: 180, height: 30)
        contentView.addSubview(resetButton)

        self.panel = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Observe settings changes from outside (e.g. slider in menu)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshValues()
        }
    }

    private func addSliderRow(
        to view: NSView,
        y: CGFloat,
        title: String,
        minValue: Double,
        maxValue: Double,
        currentValue: Double,
        tag: Int,
        integerOnly: Bool
    ) -> CGFloat {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.frame = NSRect(x: 20, y: y, width: 280, height: 16)
        view.addSubview(titleLabel)

        let valueStr = integerOnly ? "\(Int(currentValue))" : String(format: "%.2f", currentValue)
        let valueLabel = NSTextField(labelWithString: valueStr)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 340, y: y, width: 60, height: 16)
        view.addSubview(valueLabel)

        let slider = NSSlider(value: currentValue, minValue: minValue, maxValue: maxValue, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 20, y: y - 22, width: 380, height: 20)
        slider.tag = tag

        if integerOnly {
            let ticks = Int(maxValue - minValue) + 1
            if ticks <= 51 {
                slider.numberOfTickMarks = ticks
                slider.allowsTickMarkValuesOnly = true
            }
        }

        view.addSubview(slider)

        switch tag {
        case 1:
            chunkDurationSlider = slider
            chunkDurationLabel = valueLabel
        case 2:
            chunkOverlapSlider = slider
            chunkOverlapLabel = valueLabel
        case 3:
            mergeGapSlider = slider
            mergeGapLabel = valueLabel
        case 4:
            minSegmentSlider = slider
            minSegmentLabel = valueLabel
        case 5:
            expansionPadSlider = slider
            expansionPadLabel = valueLabel
        default:
            break
        }

        return y - 55
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let settings = SettingsManager.shared
        switch sender.tag {
        case 1:
            let val = Int(sender.doubleValue)
            settings.chunkDuration = val
            chunkDurationLabel?.stringValue = "\(val)"
        case 2:
            let val = Int(sender.doubleValue)
            settings.chunkOverlap = val
            chunkOverlapLabel?.stringValue = "\(val)"
        case 3:
            let val = (sender.doubleValue * 100).rounded() / 100
            settings.mergeGap = val
            mergeGapLabel?.stringValue = String(format: "%.2f", val)
        case 4:
            let val = (sender.doubleValue * 100).rounded() / 100
            settings.minSegmentDuration = val
            minSegmentLabel?.stringValue = String(format: "%.2f", val)
        case 5:
            let val = Int(sender.doubleValue)
            settings.expansionPadding = val
            expansionPadLabel?.stringValue = "\(val)"
        default:
            break
        }
        settings.detectPreset()
        presetLabel?.stringValue = "Пресет: \(settings.qualityPresetName)"
    }

    @objc private func resetDefaults(_ sender: NSButton) {
        SettingsManager.shared.applyPreset(2)  // Сбалансировано
        refreshValues()
    }

    private func refreshValues() {
        let settings = SettingsManager.shared
        chunkDurationSlider?.doubleValue = Double(settings.chunkDuration)
        chunkDurationLabel?.stringValue = "\(settings.chunkDuration)"

        chunkOverlapSlider?.doubleValue = Double(settings.chunkOverlap)
        chunkOverlapLabel?.stringValue = "\(settings.chunkOverlap)"

        mergeGapSlider?.doubleValue = settings.mergeGap
        mergeGapLabel?.stringValue = String(format: "%.2f", settings.mergeGap)

        minSegmentSlider?.doubleValue = settings.minSegmentDuration
        minSegmentLabel?.stringValue = String(format: "%.2f", settings.minSegmentDuration)

        expansionPadSlider?.doubleValue = Double(settings.expansionPadding)
        expansionPadLabel?.stringValue = "\(settings.expansionPadding)"

        presetLabel?.stringValue = "Пресет: \(settings.qualityPresetName)"
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
