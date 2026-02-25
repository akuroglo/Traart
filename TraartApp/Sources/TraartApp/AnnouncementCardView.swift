import AppKit

/// Custom NSView for rendering an announcement card in a menu.
/// Uses a custom view so text isn't dimmed by NSMenuItem's disabled state.
final class AnnouncementCardView: NSView {
    static let cardWidth: CGFloat = 300
    private static let hPad: CGFloat = 14
    private static let vPad: CGFloat = 8
    private static let textWidth: CGFloat = cardWidth - hPad * 2

    private var linkURL: URL?

    init(announcement: AnnouncementsManager.Announcement, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)

        let hPad = Self.hPad
        let textWidth = Self.textWidth
        var y: CGFloat = Self.vPad

        // Date
        let dateField = makeLabel(
            text: announcement.date,
            font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            color: .tertiaryLabelColor,
            width: textWidth
        )

        // Title
        let titleField = makeLabel(
            text: announcement.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor,
            width: textWidth
        )

        // Body
        let bodyField = makeLabel(
            text: announcement.body,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            width: textWidth
        )

        // Link button (optional)
        var linkButton: NSButton?
        if let urlStr = announcement.url, let url = URL(string: urlStr) {
            self.linkURL = url
            let btn = NSButton(title: "Подробнее →", target: self, action: #selector(linkClicked))
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.contentTintColor = .controlAccentColor
            btn.font = .systemFont(ofSize: 12, weight: .medium)
            btn.sizeToFit()
            linkButton = btn
        }

        // Layout bottom-up (NSView: y=0 is bottom)
        if let btn = linkButton {
            btn.frame.origin = NSPoint(x: hPad, y: y)
            addSubview(btn)
            y += btn.frame.height + 4
        }

        bodyField.frame.origin = NSPoint(x: hPad, y: y)
        addSubview(bodyField)
        y += bodyField.frame.height + 4

        titleField.frame.origin = NSPoint(x: hPad, y: y)
        addSubview(titleField)
        y += titleField.frame.height + 2

        dateField.frame.origin = NSPoint(x: hPad, y: y)
        addSubview(dateField)
        y += dateField.frame.height + Self.vPad

        // Separator line at the bottom of each card
        let sep = NSBox(frame: NSRect(x: hPad, y: 0, width: textWidth, height: 1))
        sep.boxType = .separator
        addSubview(sep)

        self.frame = NSRect(x: 0, y: 0, width: Self.cardWidth, height: y)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func linkClicked() {
        guard let url = linkURL else { return }
        // Close the menu before opening URL
        if let menu = enclosingMenuItem?.menu {
            menu.cancelTracking()
        }
        NSWorkspace.shared.open(url)
    }

    private func makeLabel(text: String, font: NSFont, color: NSColor, width: CGFloat) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBezeled = false
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = width
        // Calculate proper multiline height using cell
        let cellSize = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)) ?? NSSize(width: width, height: 16)
        label.frame = NSRect(x: 0, y: 0, width: width, height: cellSize.height)
        return label
    }
}
