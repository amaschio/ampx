import AppKit
import CoreGraphics

/// Vector glyphs. `rect` is the glyph's visible ink box.
enum AmpXIcon {
    case play
    case pause
    case stop
    case previous
    case next
    case eject
    case `repeat`
    case menu
    case collapse
    case minimize
    case close
    case grip

    func draw(in rect: CGRect, context: CGContext, skin: any AmpXSkin, color: NSColor? = nil) {
        let tint = color ?? skin.text
        context.saveGState()
        context.setFillColor(tint.cgColor)
        context.setStrokeColor(tint.cgColor)

        switch self {
        case .play:
            fillPolygon([
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.minX, y: rect.maxY),
            ], context: context)
        case .pause:
            let barWidth = rect.width * 0.34
            context.fill(CGRect(x: rect.minX, y: rect.minY, width: barWidth, height: rect.height))
            context.fill(CGRect(x: rect.maxX - barWidth, y: rect.minY, width: barWidth, height: rect.height))
        case .stop:
            context.fill(rect)
        case .previous:
            let barWidth = rect.width * 0.16
            context.fill(CGRect(x: rect.minX, y: rect.minY, width: barWidth, height: rect.height))
            fillPolygon([
                CGPoint(x: rect.minX + rect.width * 0.24, y: rect.midY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
            ], context: context)
        case .next:
            let barWidth = rect.width * 0.16
            context.fill(CGRect(x: rect.maxX - barWidth, y: rect.minY, width: barWidth, height: rect.height))
            fillPolygon([
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.midY),
                CGPoint(x: rect.minX, y: rect.maxY),
            ], context: context)
        case .eject:
            let barHeight = rect.height * 0.2
            fillPolygon([
                CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.6),
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.6),
            ], context: context)
            context.fill(CGRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight))
        case .repeat:
            drawRepeat(in: rect, context: context)
        case .menu:
            let barHeight = rect.height * 0.18
            for row in 0 ..< 3 {
                let y = rect.minY + (rect.height - barHeight) * CGFloat(row) / 2
                context.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: barHeight))
            }
        case .collapse:
            let line = max(1, rect.width * 0.14)
            context.setLineWidth(line)
            context.stroke(rect.insetBy(dx: line / 2, dy: line / 2))
        case .minimize:
            context.fill(rect)
            context.setFillColor(NSColor.white.withAlphaComponent(0.45).cgColor)
            context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.25))
        case .close:
            context.setLineWidth(max(1, rect.width * 0.18))
            context.setLineCap(.butt)
            context.strokeLineSegments(between: [
                CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY),
            ])
        case .grip:
            drawPulse(in: rect, context: context, tint: tint)
        }

        context.restoreGState()
    }

    private func fillPolygon(_ points: [CGPoint], context: CGContext) {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }

    private func drawRepeat(in rect: CGRect, context: CGContext) {
        let stroke = min(rect.width, rect.height) * 0.14
        let arrow = rect.height * 0.26
        let radius = rect.height * 0.28
        let top = rect.minY + arrow / 2
        let bottom = rect.maxY - arrow / 2
        let left = rect.minX + stroke / 2
        let right = rect.maxX - stroke / 2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: rect.midY + stroke / 2))
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: radius)
        path.addLine(to: CGPoint(x: right - arrow, y: top))
        path.move(to: CGPoint(x: right, y: rect.midY - stroke / 2))
        path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: left, y: bottom), radius: radius)
        path.addLine(to: CGPoint(x: left + arrow, y: bottom))
        context.setLineWidth(stroke)
        context.addPath(path)
        context.strokePath()

        fillPolygon([
            CGPoint(x: right - arrow * 1.1, y: top - arrow / 2),
            CGPoint(x: rect.maxX, y: top),
            CGPoint(x: right - arrow * 1.1, y: top + arrow / 2),
        ], context: context)
        fillPolygon([
            CGPoint(x: left + arrow * 1.1, y: bottom - arrow / 2),
            CGPoint(x: rect.minX, y: bottom),
            CGPoint(x: left + arrow * 1.1, y: bottom + arrow / 2),
        ], context: context)
    }

    /// Pulse waveform traced pixel-by-pixel from the reference header decoration (18 × 16 pt design box).
    private func drawPulse(in rect: CGRect, context: CGContext, tint: NSColor) {
        let strokes: [[CGPoint]] = [
            [CGPoint(x: 0.5, y: 7.25), CGPoint(x: 3, y: 7.25), CGPoint(x: 4.25, y: 4.25), CGPoint(x: 4.75, y: 0.6),
             CGPoint(x: 7.4, y: 0.6), CGPoint(x: 7.4, y: 10.8)],
            [CGPoint(x: 7.4, y: 4.75), CGPoint(x: 10.1, y: 4.75), CGPoint(x: 10.1, y: 13.75), CGPoint(x: 12.8, y: 13.75),
             CGPoint(x: 12.8, y: 10), CGPoint(x: 14.3, y: 7.4), CGPoint(x: 17.7, y: 7.4)],
            [CGPoint(x: 7.4, y: 9), CGPoint(x: 10.1, y: 9)],
        ]
        let scaleX = rect.width / 18
        let scaleY = rect.height / 16
        let path = CGMutablePath()
        for stroke in strokes {
            path.addLines(between: stroke.map { CGPoint(x: rect.minX + $0.x * scaleX, y: rect.minY + $0.y * scaleY) })
        }
        context.setLineJoin(.miter)
        context.setLineCap(.square)
        context.addPath(path)
        context.setLineWidth(2.4 * scaleX)
        context.setStrokeColor(NSColor(srgbRed: 0.05, green: 0.06, blue: 0.08, alpha: 0.85).cgColor)
        context.strokePath()
        context.addPath(path)
        context.setLineWidth(1.4 * scaleX)
        context.setStrokeColor(tint.cgColor)
        context.strokePath()
    }
}
