import AppKit
import CoreGraphics

struct ClassicModernSkin: AmpXSkin {
    let background = NSColor(srgbRed: 0.043, green: 0.059, blue: 0.094, alpha: 1)
    let panel = NSColor(srgbRed: 0.082, green: 0.106, blue: 0.161, alpha: 1)
    let panelLight = NSColor(srgbRed: 0.125, green: 0.157, blue: 0.227, alpha: 1)
    let border = NSColor(srgbRed: 0.231, green: 0.275, blue: 0.361, alpha: 1)
    let borderHighlight = NSColor(srgbRed: 0.396, green: 0.443, blue: 0.529, alpha: 1)
    let borderDark = NSColor(srgbRed: 0.035, green: 0.047, blue: 0.078, alpha: 1)
    let text = NSColor(srgbRed: 0.902, green: 0.929, blue: 0.969, alpha: 1)
    let textDim = NSColor(srgbRed: 0.545, green: 0.588, blue: 0.667, alpha: 1)
    let selection = NSColor(srgbRed: 0.13, green: 0.18, blue: 0.29, alpha: 1)
    let green = NSColor(hex: 0x00FF32)
    let yellow = NSColor(hex: 0xFFD21A)
    let orange = NSColor(hex: 0xFF9D00)
    let display = NSColor(hex: 0x000000)
    let gold = NSColor(srgbRed: 0.749, green: 0.627, blue: 0.322, alpha: 1)
    let goldLight = NSColor(srgbRed: 1.0, green: 0.953, blue: 0.286, alpha: 1)

    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        AmpXFonts.font(size: size, weight: weight)
    }

    func bevel(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let outer = AmpXPixelGrid.strokeRect(rect, lineWidth: 1, backingScale: backingScale)
        context.setStrokeColor(border.cgColor)
        context.setLineWidth(1 / backingScale)
        context.stroke(outer)

        let highlight = CGRect(
            x: outer.minX,
            y: outer.minY,
            width: outer.width,
            height: max(0, 1 / backingScale)
        )
        context.setFillColor(borderHighlight.cgColor)
        context.fill(highlight)

        let shadow = CGRect(
            x: outer.minX,
            y: outer.maxY - max(0, 1 / backingScale),
            width: outer.width,
            height: max(0, 1 / backingScale)
        )
        context.setFillColor(borderDark.cgColor)
        context.fill(shadow)
    }

    func inset(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let inner = AmpXPixelGrid.strokeRect(rect.insetBy(dx: 1, dy: 1), lineWidth: 1, backingScale: backingScale)
        context.setFillColor(panel.cgColor)
        context.fill(inner)

        context.setStrokeColor(borderDark.cgColor)
        context.setLineWidth(1 / backingScale)
        context.stroke(inner)
    }

    func accentLine(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let line = CGRect(
            x: AmpXPixelGrid.align(rect.minX, backingScale: backingScale),
            y: AmpXPixelGrid.align(rect.minY, backingScale: backingScale),
            width: rect.width,
            height: max(1 / backingScale, AmpXPixelGrid.align(rect.height, backingScale: backingScale))
        )
        context.setFillColor(yellow.cgColor)
        context.fill(line)
    }

    func displayWell(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let well = AmpXPixelGrid.strokeRect(rect, lineWidth: 1, backingScale: backingScale)
        context.setFillColor(display.cgColor)
        context.fill(well)

        context.setStrokeColor(borderDark.cgColor)
        context.setLineWidth(1 / backingScale)
        context.stroke(well)
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
