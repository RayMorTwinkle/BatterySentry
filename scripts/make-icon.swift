import AppKit
import Foundation

// 生成 AppIcon.iconset：深色圆角底 + 低电量电池 + 红色填充

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let outputDirectory = URL(fileURLWithPath: outputPath)

struct Variant {
    let name: String
    let pixels: Int
}

let variants: [Variant] = [
    .init(name: "icon_16x16.png", pixels: 16),
    .init(name: "icon_16x16@2x.png", pixels: 32),
    .init(name: "icon_32x32.png", pixels: 32),
    .init(name: "icon_32x32@2x.png", pixels: 64),
    .init(name: "icon_128x128.png", pixels: 128),
    .init(name: "icon_128x128@2x.png", pixels: 256),
    .init(name: "icon_256x256.png", pixels: 256),
    .init(name: "icon_256x256@2x.png", pixels: 512),
    .init(name: "icon_512x512.png", pixels: 512),
    .init(name: "icon_512x512@2x.png", pixels: 1024),
]

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func makeIcon(pixels: Int) -> Data? {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.055
    let background = canvas.insetBy(dx: inset, dy: inset)
    let radius = background.width * 0.225
    let backgroundPath = NSBezierPath(roundedRect: background, xRadius: radius, yRadius: radius)

    let top = NSColor(srgbRed: 0.20, green: 0.21, blue: 0.26, alpha: 1)
    let bottom = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.08, alpha: 1)
    NSGradient(colors: [top, bottom])?.draw(in: backgroundPath, angle: -90)

    NSColor.white.withAlphaComponent(0.16).setStroke()
    backgroundPath.lineWidth = max(1, size * 0.006)
    backgroundPath.stroke()

    let batteryWidth = background.width * 0.56
    let batteryHeight = batteryWidth * 0.46
    let bodyRect = NSRect(
        x: background.midX - batteryWidth * 0.55,
        y: background.midY - batteryHeight / 2,
        width: batteryWidth,
        height: batteryHeight
    )
    let stroke = max(1.5, size * 0.017)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: batteryHeight * 0.26, yRadius: batteryHeight * 0.26)
    bodyPath.lineWidth = stroke
    NSColor.white.withAlphaComponent(0.92).setStroke()
    bodyPath.stroke()

    let nub = NSRect(
        x: bodyRect.maxX + stroke * 0.9,
        y: bodyRect.midY - batteryHeight * 0.16,
        width: batteryWidth * 0.06,
        height: batteryHeight * 0.32
    )
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: nub, xRadius: nub.width * 0.4, yRadius: nub.width * 0.4).fill()

    let padding = batteryHeight * 0.17
    let innerHeight = batteryHeight - padding * 2
    let fillWidth = max(innerHeight * 0.55, (batteryWidth - padding * 2) * 0.16)
    let fillRect = NSRect(
        x: bodyRect.minX + padding,
        y: bodyRect.minY + padding,
        width: fillWidth,
        height: innerHeight
    )
    NSColor.systemRed.setFill()
    NSBezierPath(roundedRect: fillRect, xRadius: padding * 0.5, yRadius: padding * 0.5).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for variant in variants {
    guard let data = makeIcon(pixels: variant.pixels) else { continue }
    try data.write(to: outputDirectory.appendingPathComponent(variant.name))
}

print("图标已生成: \(outputDirectory.path)")
