import AppKit

final class OnboardingWindowController: NSWindowController {
    var onComplete: (() -> Void)?
    var onCancel: (() -> Void)?

    private var currentPage = 0
    private let totalPages = 3
    private var pageViews: [NSView] = []
    private var dotIndicators: [NSView] = []
    private var backButton: NSButton!
    private var nextButton: NSButton!
    private var contentContainer: NSView!

    private static let tealColor = NSColor(calibratedRed: 0.0, green: 0.75, blue: 0.75, alpha: 1.0)
    private static let cyanColor = NSColor(calibratedRed: 0.0, green: 0.898, blue: 1.0, alpha: 1.0)
    private static let violetColor = NSColor(calibratedRed: 0.486, green: 0.302, blue: 0.69, alpha: 1.0)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor

        self.init(window: window)
        window.delegate = self
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        contentContainer = container

        let dotsStack = NSStackView()
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        dotsStack.orientation = .horizontal
        dotsStack.spacing = 8
        contentView.addSubview(dotsStack)

        for i in 0..<totalPages {
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = (i == 0 ? Self.tealColor : NSColor.tertiaryLabelColor).cgColor
            dotsStack.addArrangedSubview(dot)
            dotIndicators.append(dot)

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
        }

        backButton = NSButton(title: "Назад", target: self, action: #selector(goBack))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .rounded
        backButton.isHidden = true
        contentView.addSubview(backButton)

        nextButton = NSButton(title: "Далее", target: self, action: #selector(goNext))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        contentView.addSubview(nextButton)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: dotsStack.topAnchor, constant: -16),

            dotsStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotsStack.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -16),

            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            backButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])

        pageViews = [createWelcomePage(), createHowToUsePage(), createSetupPage()]
        for page in pageViews {
            page.translatesAutoresizingMaskIntoConstraints = false
            page.alphaValue = 0
            contentContainer.addSubview(page)
            NSLayoutConstraint.activate([
                page.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                page.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                page.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            ])
        }

        pageViews[0].alphaValue = 1
    }

    // MARK: - Sparkle Icon

    /// Renders a neon sparkle icon for the onboarding welcome page.
    private static func renderSparkleIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = rect.width
            let center = CGPoint(x: s / 2, y: s / 2)
            let radius = s * 0.38
            let sparkle = Self.sparklePath(center: center, radius: radius)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let cyan = CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 1.0])!
            let teal = CGColor(colorSpace: colorSpace, components: [0, 0.737, 0.831, 1.0])!
            let violet = CGColor(colorSpace: colorSpace, components: [0.486, 0.302, 0.69, 1.0])!

            // Outer glow
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: s * 0.1, color:
                CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 0.4])!)
            ctx.addPath(sparkle)
            ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0.737, 0.831, 0.1])!)
            ctx.fillPath()
            ctx.restoreGState()

            // Gradient fill
            ctx.saveGState()
            ctx.addPath(sparkle)
            ctx.clip()
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [cyan, teal, violet] as CFArray,
                locations: [0.0, 0.45, 1.0]
            ) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: s * 0.25, y: s * 0.75),
                    end: CGPoint(x: s * 0.75, y: s * 0.25),
                    options: []
                )
            }
            ctx.restoreGState()

            // Bright stroke
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: s * 0.02, color: cyan)
            ctx.addPath(sparkle)
            ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.7, 1.0, 1.0, 0.6])!)
            ctx.setLineWidth(s * 0.008)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
            ctx.restoreGState()

            // + marks
            Self.drawOnboardingAccents(in: ctx, size: s, cyan: cyan, violet: violet)

            return true
        }
        return image
    }

    private static func sparklePath(center: CGPoint, radius: CGFloat) -> CGPath {
        let r = radius
        let w = r * 0.18
        let cx = center.x
        let cy = center.y
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy + r))
        path.addQuadCurve(to: CGPoint(x: cx + r, y: cy),
                          control: CGPoint(x: cx + w, y: cy + w))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - r),
                          control: CGPoint(x: cx + w, y: cy - w))
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy),
                          control: CGPoint(x: cx - w, y: cy - w))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + r),
                          control: CGPoint(x: cx - w, y: cy + w))
        path.closeSubpath()
        return path
    }

    private static func drawOnboardingAccents(in ctx: CGContext, size s: CGFloat,
                                               cyan: CGColor, violet: CGColor) {
        // Top-right +
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: s * 0.02, color: cyan)
        ctx.setStrokeColor(cyan)
        ctx.setLineWidth(s * 0.012)
        ctx.setLineCap(.round)
        let p1 = CGPoint(x: s * 0.81, y: s * 0.81)
        let p1s = s * 0.055
        ctx.move(to: CGPoint(x: p1.x, y: p1.y - p1s))
        ctx.addLine(to: CGPoint(x: p1.x, y: p1.y + p1s))
        ctx.move(to: CGPoint(x: p1.x - p1s, y: p1.y))
        ctx.addLine(to: CGPoint(x: p1.x + p1s, y: p1.y))
        ctx.strokePath()
        ctx.restoreGState()

        // Bottom-left +
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: s * 0.015, color: violet)
        ctx.setStrokeColor(violet)
        ctx.setLineWidth(s * 0.01)
        ctx.setLineCap(.round)
        let p2 = CGPoint(x: s * 0.19, y: s * 0.19)
        let p2s = s * 0.035
        ctx.move(to: CGPoint(x: p2.x, y: p2.y - p2s))
        ctx.addLine(to: CGPoint(x: p2.x, y: p2.y + p2s))
        ctx.move(to: CGPoint(x: p2.x - p2s, y: p2.y))
        ctx.addLine(to: CGPoint(x: p2.x + p2s, y: p2.y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Page 1: Welcome

    private func createWelcomePage() -> NSView {
        let page = NSView()

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = Self.renderSparkleIcon(size: 80)
        iconView.imageScaling = .scaleProportionallyDown
        page.addSubview(iconView)

        let title = NSTextField(labelWithString: "Traart")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 32, weight: .bold)
        title.alignment = .center
        page.addSubview(title)

        let tagline = NSTextField(labelWithString: "Транскрибация речи на вашем Mac")
        tagline.translatesAutoresizingMaskIntoConstraints = false
        tagline.font = .systemFont(ofSize: 15, weight: .medium)
        tagline.textColor = Self.tealColor
        tagline.alignment = .center
        page.addSubview(tagline)

        let desc = NSTextField(wrappingLabelWithString:
            "GigaAM v3 — лучшая модель для русской речи.\n" +
            "Всё работает офлайн, ваши данные никуда не отправляются."
        )
        desc.translatesAutoresizingMaskIntoConstraints = false
        desc.font = .systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        desc.alignment = .center
        page.addSubview(desc)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: page.topAnchor, constant: 36),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            title.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            title.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),

            tagline.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            tagline.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),

            desc.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            desc.topAnchor.constraint(equalTo: tagline.bottomAnchor, constant: 16),
            desc.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
        ])

        return page
    }

    // MARK: - Page 2: How to use

    private func createHowToUsePage() -> NSView {
        let page = NSView()

        let title = NSTextField(labelWithString: "Как пользоваться")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center
        page.addSubview(title)

        let steps: [(icon: String, text: String, detail: String)] = [
            ("arrow.down.doc",
             "Перетащите файл на иконку ✦ в строке меню",
             "Или выберите файл через меню → Транскрибировать файл..."),
            ("folder.badge.plus",
             "Добавьте папку для мониторинга",
             "Новые аудио и видео файлы обнаружатся автоматически"),
            ("doc.text",
             "Получите текстовый файл",
             "Результат сохраняется рядом с исходным файлом"),
        ]

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 24
        stack.alignment = .leading
        page.addSubview(stack)

        for (i, step) in steps.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 14
            row.alignment = .top

            // Step number circle
            let numContainer = NSView()
            numContainer.translatesAutoresizingMaskIntoConstraints = false
            numContainer.wantsLayer = true
            numContainer.layer?.cornerRadius = 14
            numContainer.layer?.backgroundColor = Self.tealColor.withAlphaComponent(0.15).cgColor

            let numLabel = NSTextField(labelWithString: "\(i + 1)")
            numLabel.translatesAutoresizingMaskIntoConstraints = false
            numLabel.font = .systemFont(ofSize: 13, weight: .bold)
            numLabel.textColor = Self.tealColor
            numLabel.alignment = .center
            numContainer.addSubview(numLabel)

            NSLayoutConstraint.activate([
                numContainer.widthAnchor.constraint(equalToConstant: 28),
                numContainer.heightAnchor.constraint(equalToConstant: 28),
                numLabel.centerXAnchor.constraint(equalTo: numContainer.centerXAnchor),
                numLabel.centerYAnchor.constraint(equalTo: numContainer.centerYAnchor),
            ])

            let textStack = NSStackView()
            textStack.orientation = .vertical
            textStack.spacing = 3
            textStack.alignment = .leading

            let mainLabel = NSTextField(labelWithString: step.text)
            mainLabel.font = .systemFont(ofSize: 13, weight: .semibold)

            let detailLabel = NSTextField(labelWithString: step.detail)
            detailLabel.font = .systemFont(ofSize: 12)
            detailLabel.textColor = .secondaryLabelColor

            textStack.addArrangedSubview(mainLabel)
            textStack.addArrangedSubview(detailLabel)

            row.addArrangedSubview(numContainer)
            row.addArrangedSubview(textStack)
            stack.addArrangedSubview(row)
        }

        // Supported formats hint
        let formatsLabel = NSTextField(labelWithString: "Поддерживаемые форматы: mp3, m4a, wav, mp4, mov, webm и другие")
        formatsLabel.translatesAutoresizingMaskIntoConstraints = false
        formatsLabel.font = .systemFont(ofSize: 11)
        formatsLabel.textColor = .tertiaryLabelColor
        formatsLabel.alignment = .center
        page.addSubview(formatsLabel)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            title.topAnchor.constraint(equalTo: page.topAnchor, constant: 36),

            stack.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),

            formatsLabel.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            formatsLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 24),
        ])

        return page
    }

    // MARK: - Page 3: Setup

    private func createSetupPage() -> NSView {
        let page = NSView()

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            icon.image = img.withSymbolConfiguration(config)
            icon.contentTintColor = Self.tealColor
        }
        page.addSubview(icon)

        let title = NSTextField(labelWithString: "Почти готово!")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center
        page.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "При первом запуске будут скачаны модели (~2 ГБ).\n" +
            "Это делается один раз и занимает несколько минут.\n\n" +
            "Прогресс будет отображаться в строке меню."
        )
        desc.translatesAutoresizingMaskIntoConstraints = false
        desc.font = .systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        desc.alignment = .center
        page.addSubview(desc)

        // What will be downloaded
        let detailsStack = NSStackView()
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        detailsStack.orientation = .vertical
        detailsStack.spacing = 6
        detailsStack.alignment = .leading
        page.addSubview(detailsStack)

        let items = [
            ("checkmark.circle", "Python-окружение (автоматически)"),
            ("checkmark.circle", "Модель распознавания речи GigaAM"),
            ("checkmark.circle", "FFmpeg для обработки аудио"),
        ]

        for item in items {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8

            let checkIcon = NSImageView()
            checkIcon.translatesAutoresizingMaskIntoConstraints = false
            if let img = NSImage(systemSymbolName: item.0, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                checkIcon.image = img.withSymbolConfiguration(config)
                checkIcon.contentTintColor = Self.tealColor
            }
            NSLayoutConstraint.activate([
                checkIcon.widthAnchor.constraint(equalToConstant: 16),
                checkIcon.heightAnchor.constraint(equalToConstant: 16),
            ])

            let label = NSTextField(labelWithString: item.1)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor

            row.addArrangedSubview(checkIcon)
            row.addArrangedSubview(label)
            detailsStack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            icon.topAnchor.constraint(equalTo: page.topAnchor, constant: 36),
            icon.widthAnchor.constraint(equalToConstant: 52),
            icon.heightAnchor.constraint(equalToConstant: 52),

            title.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 14),

            desc.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            desc.widthAnchor.constraint(lessThanOrEqualToConstant: 380),

            detailsStack.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            detailsStack.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 20),
        ])

        return page
    }

    // MARK: - Navigation

    @objc private func goNext() {
        if currentPage < totalPages - 1 {
            transitionToPage(currentPage + 1)
        } else {
            window?.close()
            onComplete?()
        }
    }

    @objc private func goBack() {
        if currentPage > 0 {
            transitionToPage(currentPage - 1)
        }
    }

    private func transitionToPage(_ newPage: Int) {
        let oldPage = currentPage
        currentPage = newPage

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pageViews[oldPage].animator().alphaValue = 0
            pageViews[newPage].animator().alphaValue = 1
        })

        updateControls()
    }

    private func updateControls() {
        backButton.isHidden = (currentPage == 0)

        if currentPage == totalPages - 1 {
            nextButton.title = "Начать"
        } else {
            nextButton.title = "Далее"
        }

        for (i, dot) in dotIndicators.enumerated() {
            dot.layer?.backgroundColor = (i == currentPage ? Self.tealColor : NSColor.tertiaryLabelColor).cgColor
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - NSWindowDelegate

extension OnboardingWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if currentPage < totalPages - 1 {
            onCancel?()
        }
    }
}
