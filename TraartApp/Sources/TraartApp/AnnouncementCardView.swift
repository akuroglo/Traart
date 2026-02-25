import AppKit

/// Custom NSView for rendering an announcement card in a menu.
/// Uses a custom view so text isn't dimmed by NSMenuItem's disabled state.
final class AnnouncementCardView: NSView {
    private let cardWidth: CGFloat = 320

    init(announcement: AnnouncementsManager.Announcement, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: cardWidth),
        ])

        // Date
        let dateLabel = makeLabel(
            text: announcement.date,
            font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            color: .tertiaryLabelColor
        )
        stack.addArrangedSubview(dateLabel)

        // Title
        let titleLabel = makeLabel(
            text: announcement.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        stack.addArrangedSubview(titleLabel)

        // Body
        let bodyLabel = makeLabel(
            text: announcement.body,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        stack.addArrangedSubview(bodyLabel)
        stack.setCustomSpacing(4, after: titleLabel)

        // Link button
        if let urlStr = announcement.url, let url = URL(string: urlStr) {
            let linkButton = NSButton(title: "Подробнее →", target: target, action: action)
            linkButton.bezelStyle = .inline
            linkButton.isBordered = false
            linkButton.contentTintColor = .controlAccentColor
            linkButton.font = .systemFont(ofSize: 12, weight: .medium)
            linkButton.cell?.representedObject = url
            stack.addArrangedSubview(linkButton)
            stack.setCustomSpacing(4, after: bodyLabel)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeLabel(text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBezeled = false
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = cardWidth - 24  // insets
        return label
    }
}
