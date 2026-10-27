import AppKit

/// 用 Core Graphics 画一枚电池图标：
/// - 普通状态：模板图（由系统自动适配浅色/深色菜单栏）
/// - 低电量：红色图（非模板），一眼可见
/// - 充电中：电量条里镂空一个闪电
enum BatteryIcon {
    static let canvas = CGSize(width: 26, height: 13)

    static func image(level: Int?, charging: Bool, low: Bool) -> NSImage {
        let scale: CGFloat = 2
        let pixelWidth = Int(canvas.width * scale)
        let pixelHeight = Int(canvas.height * scale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: canvas)
        }

        // 先设置 rep 的逻辑尺寸，再创建绘图上下文：
        // 上下文才会按 2x 缩放映射点坐标，否则图标会只占画布左下角一半。
        rep.size = canvas
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: canvas)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(level: level, charging: charging, color: low ? .systemRed : .black)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvas)
        image.addRepresentation(rep)
        image.isTemplate = !low
        return image
    }

    private static func draw(level: Int?, charging: Bool, color: NSColor) {
        color.setStroke()
        color.setFill()

        let body = NSRect(x: 0.75, y: 1.75, width: 20.0, height: 9.5)
        let outline = NSBezierPath(roundedRect: body, xRadius: 2.6, yRadius: 2.6)
        outline.lineWidth = 1.2
        outline.stroke()

        let nub = NSRect(x: 21.3, y: 4.35, width: 2.1, height: 4.3)
        NSBezierPath(roundedRect: nub, xRadius: 0.8, yRadius: 0.8).fill()

        guard let level else { return }

        let fraction = min(max(CGFloat(level), 0), 100) / 100
        let inset: CGFloat = 2.1
        let maxWidth = body.width - inset * 2
        let fillWidth = maxWidth * fraction

        if fillWidth > 0.6 {
            let fillRect = NSRect(
                x: body.minX + inset,
                y: body.minY + inset,
                width: fillWidth,
                height: body.height - inset * 2
            )
            color.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: 1.2, yRadius: 1.2).fill()
        }

        if charging {
            carveBolt(in: NSRect(x: body.midX - 4.6, y: body.midY - 4.4, width: 9.0, height: 8.8))
        }
    }

    /// 以 destinationOut 混合模式在电量条上"挖"出闪电形状
    private static func carveBolt(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.addPath(boltPath(in: rect))
        context.fillPath()
        context.restoreGState()
    }

    private static func boltPath(in rect: NSRect) -> CGPath {
        let w = rect.width
        let h = rect.height
        let x = rect.midX
        let y = rect.midY
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x + w * 0.12, y: y + h * 0.5))
        path.addLine(to: CGPoint(x: x - w * 0.28, y: y - h * 0.02))
        path.addLine(to: CGPoint(x: x - w * 0.02, y: y - h * 0.02))
        path.addLine(to: CGPoint(x: x - w * 0.12, y: y - h * 0.5))
        path.addLine(to: CGPoint(x: x + w * 0.28, y: y + h * 0.08))
        path.addLine(to: CGPoint(x: x + w * 0.02, y: y + h * 0.08))
        path.closeSubpath()
        return path
    }
}
