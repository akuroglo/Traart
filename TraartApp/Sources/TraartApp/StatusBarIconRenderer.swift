import AppKit

enum IconState: Equatable {
    case idle
    case transcribing(progress: Double)
    case completed
    case error
}

final class StatusBarIconRenderer {
    private static let iconSize: CGFloat = 18

    static func render(state: IconState) -> NSImage {
        switch state {
        case .idle:
            return renderIdle()
        case .transcribing(let progress):
            return renderProgress(progress)
        case .completed:
            return renderCompleted()
        case .error:
            return renderError()
        }
    }

    // MARK: - Sparkle Path

    /// Create a 4-pointed sparkle CGPath using quadratic bezier curves.
    /// Matches the sparkle icon shape (lucide sparkles).
    private static func sparkleCGPath(center: CGPoint, radius: CGFloat, waist: CGFloat = 0.18) -> CGPath {
        let r = radius
        let w = r * waist
        let cx = center.x
        let cy = center.y

        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy + r))       // top tip
        path.addQuadCurve(to: CGPoint(x: cx + r, y: cy),
                          control: CGPoint(x: cx + w, y: cy + w))    // → right tip
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - r),
                          control: CGPoint(x: cx + w, y: cy - w))    // → bottom tip
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy),
                          control: CGPoint(x: cx - w, y: cy - w))    // → left tip
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + r),
                          control: CGPoint(x: cx - w, y: cy + w))    // → back to top
        path.closeSubpath()
        return path
    }

    /// Draw small + accent marks (sparkle decorations).
    /// Positions scaled from 24x24 SVG viewBox to 18x18 AppKit coords.
    private static func drawAccentMarks(in ctx: CGContext, color: CGColor) {
        ctx.setStrokeColor(color)
        ctx.setLineCap(.round)

        // Top-right + (SVG center 21,5 → AppKit 15, 14.25)
        ctx.setLineWidth(1.2)
        ctx.move(to: CGPoint(x: 15, y: 12.75))
        ctx.addLine(to: CGPoint(x: 15, y: 15.75))
        ctx.move(to: CGPoint(x: 13.5, y: 14.25))
        ctx.addLine(to: CGPoint(x: 16.5, y: 14.25))
        ctx.strokePath()

        // Bottom-left + (SVG center 4,18 → AppKit 3, 4.5)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: 3, y: 3.75))
        ctx.addLine(to: CGPoint(x: 3, y: 5.25))
        ctx.move(to: CGPoint(x: 2.25, y: 4.5))
        ctx.addLine(to: CGPoint(x: 3.75, y: 4.5))
        ctx.strokePath()
    }

    // MARK: - Idle (template sparkle)

    private static func renderIdle() -> NSImage {
        let size = iconSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let sparkle = sparkleCGPath(center: CGPoint(x: rect.midX, y: rect.midY),
                                        radius: 7.0)
            ctx.addPath(sparkle)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()

            drawAccentMarks(in: ctx, color: NSColor.black.cgColor)

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Progress (sparkle fills from bottom)

    private static func renderProgress(_ progress: Double) -> NSImage {
        let size = iconSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let sparkle = sparkleCGPath(center: center, radius: 7.0)
            let teal = NSColor(calibratedRed: 0.0, green: 0.75, blue: 0.75, alpha: 1.0)

            // Outline (dimmed)
            ctx.addPath(sparkle)
            ctx.setStrokeColor(teal.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokePath()

            // Fill from bottom based on progress
            let clamped = min(max(progress, 0.0), 1.0)
            if clamped > 0 {
                ctx.saveGState()
                ctx.addPath(sparkle)
                ctx.clip()
                let fillHeight = rect.height * CGFloat(clamped)
                ctx.setFillColor(teal.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: rect.width, height: fillHeight))
                ctx.restoreGState()
            }

            // + marks fade in
            let markAlpha: CGFloat = clamped > 0.5 ? 1.0 : 0.35
            drawAccentMarks(in: ctx, color: teal.withAlphaComponent(markAlpha).cgColor)

            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Completed (green sparkle)

    private static func renderCompleted() -> NSImage {
        let size = iconSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let sparkle = sparkleCGPath(center: CGPoint(x: rect.midX, y: rect.midY),
                                        radius: 7.0)
            let green = NSColor(calibratedRed: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)

            ctx.addPath(sparkle)
            ctx.setFillColor(green.cgColor)
            ctx.fillPath()

            drawAccentMarks(in: ctx, color: green.cgColor)

            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Error (red sparkle)

    private static func renderError() -> NSImage {
        let size = iconSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let sparkle = sparkleCGPath(center: CGPoint(x: rect.midX, y: rect.midY),
                                        radius: 7.0)
            let red = NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)

            ctx.addPath(sparkle)
            ctx.setFillColor(red.cgColor)
            ctx.fillPath()

            drawAccentMarks(in: ctx, color: red.cgColor)

            return true
        }
        image.isTemplate = false
        return image
    }
}
