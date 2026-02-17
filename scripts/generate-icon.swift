#!/usr/bin/env swift
/// Generates AppIcon.icns for Traart using the neon sparkle design.
/// Run: swift scripts/generate-icon.swift
/// Output: build/AppIcon.icns

import AppKit
import Foundation

// MARK: - Sparkle path

func sparklePath(center: CGPoint, radius: CGFloat, waist: CGFloat = 0.18) -> CGPath {
    let r = radius
    let w = r * waist
    let cx = center.x
    let cy = center.y

    let path = CGMutablePath()
    path.move(to: CGPoint(x: cx, y: cy + r))       // top tip (CG: Y up)
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

// MARK: - Icon rendering

func renderIcon(pixelSize: Int) -> Data? {
    let s = CGFloat(pixelSize)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    // CG coords: origin bottom-left, Y up
    // Visual top-left = (0, s), visual bottom-right = (s, 0)

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // --- Background squircle ---
    let inset = s * 0.05
    let bgRect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.04, 0.055, 0.08, 1.0])!)
    ctx.fillPath()

    // Subtle border on background
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.15, 0.18, 0.22, 1.0])!)
    ctx.setLineWidth(s * 0.003)
    ctx.strokePath()

    let center = CGPoint(x: s / 2, y: s / 2)
    let sparkleRadius = s * 0.34
    let sparkle = sparklePath(center: center, radius: sparkleRadius)

    // Colors
    let cyan = CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 1.0])!
    let teal = CGColor(colorSpace: colorSpace, components: [0, 0.737, 0.831, 1.0])!
    let violet = CGColor(colorSpace: colorSpace, components: [0.486, 0.302, 0.69, 1.0])!

    // --- Layer 1: Outer glow ---
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.08, color:
        CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 0.45])!)
    ctx.addPath(sparkle)
    ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0.737, 0.831, 0.12])!)
    ctx.fillPath()
    ctx.restoreGState()

    // --- Layer 2: Medium glow ---
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.035, color:
        CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 0.6])!)
    ctx.addPath(sparkle)
    ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0.898, 1.0, 0.08])!)
    ctx.fillPath()
    ctx.restoreGState()

    // --- Layer 3: Gradient fill ---
    ctx.saveGState()
    ctx.addPath(sparkle)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [cyan, teal, violet] as CFArray,
        locations: [0.0, 0.45, 1.0]
    )!
    // Gradient from visual top-left to bottom-right
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: s * 0.25, y: s * 0.75),
        end: CGPoint(x: s * 0.75, y: s * 0.25),
        options: []
    )
    ctx.restoreGState()

    // --- Layer 4: Bright stroke ---
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.012, color: cyan)
    ctx.addPath(sparkle)
    ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.7, 1.0, 1.0, 0.7])!)
    ctx.setLineWidth(s * 0.005)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // --- + accent marks ---
    // Top-right + (visual: upper-right → CG: high X, high Y)
    let p1 = CGPoint(x: s * 0.81, y: s * 0.81)
    let p1size = s * 0.055
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.02, color: cyan)
    ctx.setStrokeColor(cyan)
    ctx.setLineWidth(s * 0.006)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: p1.x, y: p1.y - p1size))
    ctx.addLine(to: CGPoint(x: p1.x, y: p1.y + p1size))
    ctx.move(to: CGPoint(x: p1.x - p1size, y: p1.y))
    ctx.addLine(to: CGPoint(x: p1.x + p1size, y: p1.y))
    ctx.strokePath()
    ctx.restoreGState()

    // Bottom-left + (visual: lower-left → CG: low X, low Y)
    let p2 = CGPoint(x: s * 0.19, y: s * 0.19)
    let p2size = s * 0.035
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.015, color: violet)
    ctx.setStrokeColor(violet)
    ctx.setLineWidth(s * 0.005)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: p2.x, y: p2.y - p2size))
    ctx.addLine(to: CGPoint(x: p2.x, y: p2.y + p2size))
    ctx.move(to: CGPoint(x: p2.x - p2size, y: p2.y))
    ctx.addLine(to: CGPoint(x: p2.x + p2size, y: p2.y))
    ctx.strokePath()
    ctx.restoreGState()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])
}

// MARK: - Generate iconset + icns

let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let projectDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let buildDir = projectDir.appendingPathComponent("build")
let iconsetDir = buildDir.appendingPathComponent("AppIcon.iconset")
let icnsPath = buildDir.appendingPathComponent("AppIcon.icns")

try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (name, pixels) in iconSizes {
    guard let data = renderIcon(pixelSize: pixels) else {
        print("ERROR: Failed to render \(name)")
        continue
    }
    try! data.write(to: iconsetDir.appendingPathComponent(name))
    print("  \(name) (\(pixels)x\(pixels))")
}

// Run iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try! process.run()
process.waitUntilExit()

try? FileManager.default.removeItem(at: iconsetDir)

if process.terminationStatus == 0 {
    let fileSize = try! FileManager.default.attributesOfItem(atPath: icnsPath.path)[.size] as! Int
    print("Created: \(icnsPath.path) (\(fileSize / 1024) KB)")
} else {
    print("ERROR: iconutil failed")
    exit(1)
}
