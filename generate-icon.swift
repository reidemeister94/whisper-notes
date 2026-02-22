#!/usr/bin/env swift
import AppKit

// MARK: - Icon drawing

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size
    let pad = s * 0.08
    let rect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let cornerRadius = s * 0.22

    // Background: dark gradient
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0),
        CGColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1.0),
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: colors as CFArray,
                               locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s / 2, y: rect.maxY),
                           end: CGPoint(x: s / 2, y: rect.minY),
                           options: [])

    // Subtle inner glow at top
    let glowColors = [
        CGColor(red: 0.3, green: 0.2, blue: 0.6, alpha: 0.15),
        CGColor(red: 0.3, green: 0.2, blue: 0.6, alpha: 0.0),
    ]
    let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: glowColors as CFArray,
                                   locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glowGradient,
                           startCenter: CGPoint(x: s / 2, y: s * 0.7),
                           startRadius: 0,
                           endCenter: CGPoint(x: s / 2, y: s * 0.7),
                           endRadius: s * 0.45,
                           options: [])

    // Waveform bars (center-top area)
    let barCount = 7
    let barWidth = s * 0.045
    let barSpacing = s * 0.065
    let totalWidth = CGFloat(barCount - 1) * barSpacing
    let startX = (s - totalWidth) / 2
    let centerY = s * 0.52

    let heights: [CGFloat] = [0.10, 0.18, 0.30, 0.38, 0.28, 0.20, 0.12]

    for i in 0..<barCount {
        let x = startX + CGFloat(i) * barSpacing
        let h = heights[i] * s
        let barRect = CGRect(x: x - barWidth / 2, y: centerY - h / 2, width: barWidth, height: h)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)

        // Gradient per bar: red accent
        ctx.saveGState()
        ctx.addPath(barPath)
        ctx.clip()

        let barColors: [CGColor]
        if i == 3 { // Center bar: brightest
            barColors = [
                CGColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),
                CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.8),
            ]
        } else if i == 2 || i == 4 {
            barColors = [
                CGColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 0.9),
                CGColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 0.6),
            ]
        } else {
            barColors = [
                CGColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.75),
                CGColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 0.45),
            ]
        }
        let barGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: barColors as CFArray,
                                      locations: [0.0, 1.0])!
        ctx.drawLinearGradient(barGradient,
                               start: CGPoint(x: x, y: barRect.maxY),
                               end: CGPoint(x: x, y: barRect.minY),
                               options: [])
        ctx.restoreGState()
    }

    // Document/text lines below the waveform
    let lineY = s * 0.24
    let lineH = s * 0.012
    let lineWidths: [CGFloat] = [0.38, 0.30, 0.34]
    let lineSpacing = s * 0.035

    for (i, w) in lineWidths.enumerated() {
        let lw = w * s
        let lx = (s - lw) / 2
        let ly = lineY - CGFloat(i) * lineSpacing
        let lineRect = CGRect(x: lx, y: ly, width: lw, height: lineH)
        let linePath = CGPath(roundedRect: lineRect, cornerWidth: lineH / 2, cornerHeight: lineH / 2, transform: nil)
        ctx.addPath(linePath)
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25 - CGFloat(i) * 0.05))
        ctx.fillPath()
    }

    // Subtle "W" watermark? No, keep it clean.

    image.unlockFocus()
    return image
}

// MARK: - Generate iconset

let projectDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetPath = projectDir.appendingPathComponent("AppIcon.iconset").path
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
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

for (name, size) in sizes {
    let icon = drawIcon(size: size)
    guard let tiff = icon.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let url = URL(fileURLWithPath: iconsetPath).appendingPathComponent(name)
    try! png.write(to: url)
    print("Generated \(name) (\(Int(size))x\(Int(size)))")
}

print("\nConverting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o",
                     projectDir.appendingPathComponent("Resources/AppIcon.icns").path]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("AppIcon.icns created successfully!")
    try? fm.removeItem(atPath: iconsetPath)
} else {
    print("iconutil failed with status \(process.terminationStatus)")
}
