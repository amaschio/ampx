import AppKit
import CoreGraphics

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
        context.setLineWidth(1)

        let inset = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)
        switch self {
        case .play:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset.minX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.midY))
            path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        case .pause:
            let barWidth = inset.width * 0.28
            let gap = inset.width * 0.18
            context.fill(CGRect(x: inset.minX, y: inset.minY, width: barWidth, height: inset.height))
            context.fill(CGRect(x: inset.minX + barWidth + gap, y: inset.minY, width: barWidth, height: inset.height))
        case .stop:
            context.fill(inset)
        case .previous:
            let triWidth = inset.width * 0.42
            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset.maxX - triWidth, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.midY))
            path.addLine(to: CGPoint(x: inset.maxX - triWidth, y: inset.maxY))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            let bar = CGRect(x: inset.minX, y: inset.minY, width: inset.width * 0.14, height: inset.height)
            context.fill(bar)
        case .next:
            let triWidth = inset.width * 0.42
            let path = CGMutablePath()
            path.move(to: CGPoint(x: inset.minX + triWidth, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.minX, y: inset.midY))
            path.addLine(to: CGPoint(x: inset.minX + triWidth, y: inset.maxY))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            let bar = CGRect(
                x: inset.maxX - inset.width * 0.14,
                y: inset.minY,
                width: inset.width * 0.14,
                height: inset.height
            )
            context.fill(bar)
        case .eject:
            let base = CGRect(
                x: inset.minX,
                y: inset.maxY - inset.height * 0.22,
                width: inset.width,
                height: inset.height * 0.22
            )
            context.fill(base)
            let tri = CGMutablePath()
            tri.move(to: CGPoint(x: inset.minX, y: inset.maxY - inset.height * 0.28))
            tri.addLine(to: CGPoint(x: inset.midX, y: inset.minY))
            tri.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY - inset.height * 0.28))
            tri.closeSubpath()
            context.addPath(tri)
            context.fillPath()
        case .`repeat`:
            let arcRect = inset.insetBy(dx: inset.width * 0.08, dy: inset.height * 0.18)
            context.addArc(
                center: CGPoint(x: arcRect.midX, y: arcRect.midY),
                radius: min(arcRect.width, arcRect.height) / 2,
                startAngle: .pi * 0.15,
                endAngle: .pi * 1.65,
                clockwise: false
            )
            context.strokePath()
            let arrow = inset.width * 0.16
            context.fill(CGRect(x: arcRect.maxX - arrow, y: arcRect.minY, width: arrow, height: arrow))
        case .menu:
            let lineHeight = max(1, inset.height * 0.1)
            let gap = inset.height * 0.18
            for row in 0..<3 {
                let y = inset.minY + CGFloat(row) * (lineHeight + gap)
                context.fill(CGRect(x: inset.minX, y: y, width: inset.width, height: lineHeight))
            }
        case .collapse:
            context.fill(CGRect(x: inset.minX, y: inset.midY - 0.5, width: inset.width, height: 1))
        case .minimize:
            context.fill(CGRect(x: inset.minX, y: inset.maxY - 1.5, width: inset.width, height: 1))
        case .close:
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: inset.minX, y: inset.minY))
            context.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            context.move(to: CGPoint(x: inset.maxX, y: inset.minY))
            context.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
            context.strokePath()
        case .grip:
            let lineHeight = max(1, inset.height * 0.08)
            let gap = inset.height * 0.16
            for row in 0..<3 {
                let y = inset.minY + CGFloat(row) * (lineHeight + gap)
                context.fill(CGRect(x: inset.minX, y: y, width: inset.width, height: lineHeight))
            }
        }

        context.restoreGState()
    }
}
