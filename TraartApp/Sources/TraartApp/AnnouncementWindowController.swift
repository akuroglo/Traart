import AppKit

/// A floating panel that displays the latest announcement with rich content and action buttons.
final class AnnouncementWindowController: NSWindowController {
    static let shared = AnnouncementWindowController()

    private var currentAnnouncement: AnnouncementsManager.Announcement?
    private let contentStack = NSStackView()
    private let scrollView = NSScrollView()

    private static let windowWidth: CGFloat = 460
    private static let maxWindowHeight: CGFloat = 520
    private static let padding: CGFloat = 24

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.title = "Traart"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.center()

        super.init(window: panel)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupViews() {
        guard let panel = window else { return }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding,
            bottom: Self.padding, right: Self.padding
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = contentStack
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(scrollView)

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                contentStack.widthAnchor.constraint(equalToConstant: Self.windowWidth),
            ])
        }
    }

    // MARK: - Public

    func show(announcement: AnnouncementsManager.Announcement) {
        currentAnnouncement = announcement
        rebuildContent(announcement)

        // Size window to fit content, capped at max height
        contentStack.layoutSubtreeIfNeeded()
        let fittingHeight = min(contentStack.fittingSize.height + 20, Self.maxWindowHeight)
        window?.setContentSize(NSSize(width: Self.windowWidth, height: fittingHeight))
        window?.center()

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    func showLatest() {
        if let announcement = AnnouncementsManager.shared.latestAnnouncement {
            show(announcement: announcement)
        } else {
            // Fetch and show
            AnnouncementsManager.shared.fetchLatest { [weak self] announcement in
                guard let self, let announcement else { return }
                self.show(announcement: announcement)
            }
        }
    }

    // MARK: - Build Content

    private func rebuildContent(_ announcement: AnnouncementsManager.Announcement) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let textWidth = Self.windowWidth - Self.padding * 2

        // Badge + Title row
        let titleText: String
        if let badge = announcement.badge {
            titleText = "\(badge)  \(announcement.title)"
        } else {
            titleText = announcement.title
        }
        let titleLabel = makeLabel(titleText, font: .systemFont(ofSize: 18, weight: .bold), color: .labelColor, width: textWidth)
        contentStack.addArrangedSubview(titleLabel)

        // Date
        let dateLabel = makeLabel(announcement.date, font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: .tertiaryLabelColor, width: textWidth)
        contentStack.addArrangedSubview(dateLabel)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalToConstant: textWidth).isActive = true

        // Detail body (long text) or fallback to body
        let bodyText = announcement.detail ?? announcement.body
        let paragraphs = bodyText.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("> ") {
                // Quoted block — render as a copyable card
                let quoteText = String(trimmed.dropFirst(2))
                let quoteView = makeQuoteBlock(quoteText, width: textWidth)
                contentStack.addArrangedSubview(quoteView)
            } else {
                let label = makeLabel(trimmed, font: .systemFont(ofSize: 14), color: .secondaryLabelColor, width: textWidth, selectable: true)
                contentStack.addArrangedSubview(label)
            }
        }

        // Action buttons
        let actions = announcement.actions ?? []
        if !actions.isEmpty || announcement.url != nil {
            contentStack.addArrangedSubview(makeSpacer(8))

            let buttonRow = NSStackView()
            buttonRow.orientation = .horizontal
            buttonRow.spacing = 12
            buttonRow.alignment = .centerY

            if actions.isEmpty, let urlStr = announcement.url, let url = URL(string: urlStr) {
                // Fallback: single "Подробнее" button from legacy url field
                let btn = makeActionButton(title: "Подробнее", url: url, isPrimary: true)
                buttonRow.addArrangedSubview(btn)
            } else {
                for action in actions {
                    let isPrimary = action.style == "primary"
                    if let urlStr = action.url, let url = URL(string: urlStr) {
                        let btn = makeActionButton(title: action.title, url: url, isPrimary: isPrimary)
                        buttonRow.addArrangedSubview(btn)
                    } else if action.style == "secondary" {
                        // "Later" / dismiss button
                        let btn = NSButton(title: action.title, target: self, action: #selector(dismissClicked))
                        btn.bezelStyle = .rounded
                        btn.controlSize = .large
                        buttonRow.addArrangedSubview(btn)
                    }
                }
            }

            contentStack.addArrangedSubview(buttonRow)
        }
    }

    // MARK: - UI Helpers

    private func makeLabel(_ text: String, font: NSFont, color: NSColor, width: CGFloat, selectable: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isEditable = false
        label.isSelectable = selectable
        label.drawsBackground = false
        label.isBezeled = false
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = width
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: width).isActive = true
        return label
    }

    private func makeQuoteBlock(_ text: String, width: CGFloat) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let innerWidth = width - 32

        let quoteLabel = NSTextField(wrappingLabelWithString: text)
        quoteLabel.font = .systemFont(ofSize: 13)
        quoteLabel.textColor = .labelColor
        quoteLabel.isEditable = false
        quoteLabel.isSelectable = true
        quoteLabel.drawsBackground = false
        quoteLabel.isBezeled = false
        quoteLabel.lineBreakMode = .byWordWrapping
        quoteLabel.preferredMaxLayoutWidth = innerWidth
        quoteLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(quoteLabel)

        let copyBtn = NSButton(image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Копировать")!, target: self, action: #selector(copyQuote(_:)))
        copyBtn.bezelStyle = .inline
        copyBtn.isBordered = false
        copyBtn.toolTip = "Копировать текст"
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        copyBtn.identifier = NSUserInterfaceItemIdentifier(text)
        container.addSubview(copyBtn)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: width),
            quoteLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            quoteLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            quoteLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
            quoteLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            copyBtn.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            copyBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        return container
    }

    private func makeActionButton(title: String, url: URL, isPrimary: Bool) -> NSButton {
        let btn = NSButton(title: title, target: self, action: #selector(actionButtonClicked(_:)))
        btn.bezelStyle = .rounded
        btn.controlSize = .large
        if isPrimary {
            btn.keyEquivalent = "\r"
            btn.contentTintColor = .white
            btn.bezelColor = .controlAccentColor
        }
        btn.identifier = NSUserInterfaceItemIdentifier(url.absoluteString)
        return btn
    }

    private func makeSpacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: - Actions

    @objc private func actionButtonClicked(_ sender: NSButton) {
        guard let urlString = sender.identifier?.rawValue,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyQuote(_ sender: NSButton) {
        guard let text = sender.identifier?.rawValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Visual feedback
        let original = sender.image
        sender.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sender.image = original
        }
    }

    @objc private func dismissClicked(_ sender: NSButton) {
        close()
    }
}
