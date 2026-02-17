import AppKit
import QuartzCore

final class TranscriptionProgressView: NSView {
    // MARK: - Design tokens

    private static let tealA = NSColor(calibratedRed: 0.0, green: 0.72, blue: 0.72, alpha: 1.0)
    private static let tealB = NSColor(calibratedRed: 0.0, green: 0.88, blue: 0.88, alpha: 1.0)
    private static let barHeight: CGFloat = 5
    private static let barRadius: CGFloat = 2.5
    private static let hMargin: CGFloat = 10

    // MARK: - Labels

    private let stepLabel = NSTextField(labelWithString: "")
    private let etaLabel = NSTextField(labelWithString: "")
    private let fileLabel = NSTextField(labelWithString: "")

    // MARK: - Bar

    private let trackView = NSView()
    private let fillClip = NSView()
    private let gradientLayer = CAGradientLayer()
    private let shimmerLayer = CAGradientLayer()

    // MARK: - State

    private var fillWidth: NSLayoutConstraint?
    private var currentProgress: Double = 0

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        // --- Step label: "Загрузка модели · 10%" ---
        stepLabel.font = .systemFont(ofSize: 13, weight: .medium)
        stepLabel.textColor = .labelColor
        stepLabel.lineBreakMode = .byTruncatingTail
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stepLabel)

        // --- ETA label: "~2м 15с" or "Оценка времени..." ---
        etaLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        etaLabel.textColor = .tertiaryLabelColor
        etaLabel.alignment = .right
        etaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(etaLabel)

        // --- File name ---
        fileLabel.font = .systemFont(ofSize: 11)
        fileLabel.textColor = .secondaryLabelColor
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fileLabel)

        // --- Track (background bar) ---
        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        trackView.layer?.cornerRadius = Self.barRadius
        trackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackView)

        // --- Fill clip (masks gradient + shimmer to progress width) ---
        fillClip.wantsLayer = true
        fillClip.layer?.cornerRadius = Self.barRadius
        fillClip.layer?.masksToBounds = true
        fillClip.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(fillClip)

        // --- Gradient fill ---
        gradientLayer.colors = [Self.tealA.cgColor, Self.tealB.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = Self.barRadius
        fillClip.layer?.addSublayer(gradientLayer)

        // --- Shimmer (liquid glass highlight) ---
        shimmerLayer.colors = [
            NSColor.white.withAlphaComponent(0.0).cgColor,
            NSColor.white.withAlphaComponent(0.4).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fillClip.layer?.addSublayer(shimmerLayer)

        // --- Constraints ---
        let fw = fillClip.widthAnchor.constraint(equalToConstant: 0)
        fillWidth = fw

        let h = Self.hMargin
        NSLayoutConstraint.activate([
            stepLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: h),
            stepLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            etaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -h),
            etaLabel.firstBaselineAnchor.constraint(equalTo: stepLabel.firstBaselineAnchor),
            etaLabel.leadingAnchor.constraint(greaterThanOrEqualTo: stepLabel.trailingAnchor, constant: 8),

            fileLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: h),
            fileLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -h),
            fileLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 1),

            trackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: h),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -h),
            trackView.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 5),
            trackView.heightAnchor.constraint(equalToConstant: Self.barHeight),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            fillClip.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillClip.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillClip.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            fw,
        ])
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        syncBarWidth(animated: false)
        syncLayerFrames()
        ensureAnimationsRunning()
    }

    private func syncBarWidth(animated: Bool) {
        let tw = trackView.bounds.width
        guard tw > 0 else { return }
        let minW: CGFloat = 4
        let target = max(minW, tw * CGFloat(min(max(currentProgress, 0), 1)))

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.allowsImplicitAnimation = true
                self.fillWidth?.constant = target
                self.layoutSubtreeIfNeeded()
            }
        } else {
            fillWidth?.constant = target
        }
    }

    private func syncLayerFrames() {
        let tw = trackView.bounds.width
        let bh = Self.barHeight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: max(tw, 1), height: bh)
        let sw = max(30, tw * 0.18)
        shimmerLayer.frame = CGRect(x: 0, y: 0, width: sw, height: bh)
        CATransaction.commit()
    }

    // MARK: - Public

    func update(
        fileName: String,
        progress: Double,
        step: TranscriptionJob.TranscriptionStep?,
        etaString: String?
    ) {
        currentProgress = progress
        let pct = Int(progress * 100)
        let name = step?.displayName ?? "Подготовка"
        stepLabel.stringValue = "\(name) · \(pct)%"

        if let eta = etaString {
            etaLabel.stringValue = eta
            etaLabel.textColor = .secondaryLabelColor
        } else {
            etaLabel.stringValue = "Оценка времени..."
            etaLabel.textColor = .tertiaryLabelColor
        }

        fileLabel.stringValue = fileName
        syncBarWidth(animated: true)
    }

    func stopAnimations() {
        shimmerLayer.removeAllAnimations()
        gradientLayer.removeAllAnimations()
    }

    // MARK: - Animations

    private func ensureAnimationsRunning() {
        let tw = trackView.bounds.width
        guard tw > 10 else { return }

        // Shimmer sliding across the bar
        if shimmerLayer.animation(forKey: "slide") == nil {
            let sw = shimmerLayer.bounds.width
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = -sw / 2
            anim.toValue = tw + sw / 2
            anim.duration = 1.8
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            shimmerLayer.add(anim, forKey: "slide")
        }

        // Gentle gradient color pulse
        if gradientLayer.animation(forKey: "pulse") == nil {
            let anim = CABasicAnimation(keyPath: "colors")
            anim.fromValue = [Self.tealA.cgColor, Self.tealB.cgColor]
            anim.toValue = [Self.tealB.cgColor, Self.tealA.cgColor]
            anim.duration = 2.5
            anim.autoreverses = true
            anim.repeatCount = .infinity
            gradientLayer.add(anim, forKey: "pulse")
        }
    }
}
