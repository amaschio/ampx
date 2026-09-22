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
    let faceInk = NSColor(srgbRed: 0.063, green: 0.086, blue: 0.141, alpha: 1)
    let faceInkDim = NSColor(srgbRed: 0.361, green: 0.400, blue: 0.471, alpha: 1)

    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        AmpXFonts.font(size: size, weight: weight)
    }

    func bevel(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        self.raisedFace(rect, style: .surface, in: context, backingScale: backingScale)
    }

    func inset(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let inner = AmpXPixelGrid.strokeRect(rect.insetBy(dx: 1, dy: 1), lineWidth: 1, backingScale: backingScale)
        context.setFillColor(self.panel.cgColor)
        context.fill(inner)

        context.setStrokeColor(self.borderDark.cgColor)
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
        context.setFillColor(self.yellow.cgColor)
        context.fill(line)
    }

    // MARK: - Layered materials (edge bands sampled from ReferenceMeasurementsV2 edge profiles)

    func displayWell(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let well = self.snapped(rect, backingScale: backingScale)
        let unit = self.bandUnit(for: well)
        context.setFillColor(Palette.wellBlack.cgColor)
        context.fill(well)
        self.drawBands(in: well, unit: unit, context: context, edges: Edges(
            top: [rgb(35, 43, 69), rgb(52, 64, 92), rgb(28, 35, 55)],
            left: [rgb(38, 48, 72), rgb(50, 62, 88), rgb(24, 31, 50)],
            bottom: [rgb(56, 68, 96), rgb(44, 55, 80), rgb(16, 20, 32)],
            right: [rgb(50, 62, 88), rgb(44, 55, 80), rgb(20, 26, 42)]
        ))
    }

    func panelFrame(_ rect: CGRect, contentFrame: CGRect?, in context: CGContext, backingScale: CGFloat) {
        let panelRect = self.snapped(rect, backingScale: backingScale)
        context.setFillColor(Palette.panel.cgColor)
        context.fill(panelRect)
        self.drawBands(in: panelRect, unit: 0.5, context: context, edges: Edges(
            top: [rgb(42, 51, 66), rgb(79, 92, 120), rgb(71, 84, 118), rgb(76, 90, 122), rgb(31, 44, 67)],
            left: [rgb(55, 65, 91), rgb(57, 69, 98), rgb(47, 57, 85), rgb(57, 71, 99), rgb(70, 89, 121), rgb(31, 39, 59)],
            bottom: [
                rgb(25, 31, 49), rgb(48, 59, 86), rgb(41, 52, 79), rgb(42, 53, 81),
                rgb(42, 53, 81), rgb(45, 56, 84), rgb(34, 44, 67), rgb(13, 21, 41),
            ],
            right: [rgb(40, 48, 70), rgb(57, 69, 98), rgb(47, 57, 85), rgb(57, 71, 99), rgb(64, 80, 110), rgb(31, 39, 59)]
        ))

        guard let contentFrame else { return }
        let frame = self.snapped(contentFrame, backingScale: backingScale)
        context.setFillColor(rgb(8, 12, 24).cgColor)
        context.fill(frame.insetBy(dx: -0.5, dy: -0.5))
        self.drawVerticalGradient(
            in: frame,
            stops: [(0, rgb(27, 38, 62)), (1, rgb(23, 32, 54))],
            context: context
        )
        let frameSide = [
            rgb(42, 55, 78), rgb(46, 60, 84), rgb(35, 45, 67), rgb(51, 61, 86),
            rgb(80, 91, 118), rgb(91, 104, 132), rgb(44, 55, 81),
        ]
        self.drawBands(in: frame, unit: 0.5, context: context, edges: Edges(
            top: [rgb(60, 72, 97), rgb(80, 99, 130), rgb(67, 82, 110), rgb(26, 35, 55)],
            left: frameSide,
            bottom: [rgb(81, 94, 127), rgb(101, 115, 148), rgb(47, 56, 82), rgb(11, 15, 31)],
            right: frameSide
        ))
    }

    func raisedFace(_ rect: CGRect, style: AmpXFaceStyle, in context: CGContext, backingScale: CGFloat) {
        let face = self.snapped(rect, backingScale: backingScale)
        let radius: CGFloat = style == .menu ? 3 : 2
        context.saveGState()
        context.addPath(CGPath(roundedRect: face, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()

        switch style {
        case .normal, .hovered:
            // Light steel, the same material as the slider thumbs: Winamp's grey buttons.
            let lift: CGFloat = style == .hovered ? 8 : 0
            self.drawVerticalGradient(
                in: face,
                stops: [(0, rgb(178 + lift, 188 + lift, 206 + lift)), (1, rgb(138 + lift, 149 + lift, 171 + lift))],
                context: context
            )
            self.drawBands(in: face, unit: 0.5, context: context, edges: Edges(
                top: [rgb(6, 9, 16), rgb(96, 106, 124), rgb(242, 246, 252), rgb(224, 231, 242), rgb(200, 209, 224)],
                left: [rgb(6, 9, 16), rgb(150, 160, 178), rgb(236, 241, 249), rgb(206, 214, 228)],
                bottom: [rgb(3, 5, 13), rgb(40, 47, 62), rgb(64, 73, 92), rgb(88, 98, 120), rgb(104, 114, 136), rgb(118, 129, 150)],
                right: [rgb(3, 5, 12), rgb(58, 66, 84), rgb(92, 102, 124)]
            ))
        case .pressed:
            // Darker steel with the bevel inverted (shadow on top, light along the bottom).
            self.drawVerticalGradient(
                in: face,
                stops: [(0, rgb(118, 128, 148)), (1, rgb(104, 114, 134))],
                context: context
            )
            self.drawBands(in: face, unit: 0.5, context: context, edges: Edges(
                top: [rgb(4, 6, 12), rgb(44, 52, 70), rgb(70, 80, 100), rgb(90, 100, 120)],
                left: [rgb(4, 6, 12), rgb(56, 64, 84), rgb(80, 90, 110)],
                bottom: [rgb(3, 5, 13), rgb(150, 160, 178), rgb(170, 180, 196), rgb(140, 150, 170)],
                right: [rgb(3, 5, 12), rgb(140, 150, 168), rgb(124, 134, 154)]
            ))
        case .surface:
            self.drawVerticalGradient(
                in: face,
                stops: [(0, rgb(39, 51, 76)), (1, rgb(31, 42, 64))],
                context: context
            )
            self.drawBands(in: face, unit: 0.5, context: context, edges: Edges(
                top: [rgb(6, 9, 16), rgb(25, 29, 40), rgb(110, 125, 150), rgb(111, 131, 159), rgb(89, 105, 129)],
                left: [rgb(6, 9, 16), rgb(60, 70, 90), rgb(98, 113, 139), rgb(58, 70, 94)],
                bottom: [rgb(3, 5, 13), rgb(1, 2, 8), rgb(7, 14, 26), rgb(15, 25, 41), rgb(16, 23, 40), rgb(21, 28, 46)],
                right: [rgb(3, 5, 12), rgb(14, 20, 34), rgb(26, 35, 52)]
            ))
        case .menu:
            self.drawVerticalGradient(
                in: face,
                stops: [(0, rgb(252, 165, 48)), (0.5, rgb(245, 150, 36)), (1, rgb(232, 126, 22))],
                context: context
            )
            self.drawBands(in: face, unit: 0.5, context: context, edges: Edges(
                top: [rgb(6, 6, 7), rgb(125, 116, 61), rgb(255, 230, 99), rgb(242, 170, 48)],
                left: [rgb(6, 6, 7), rgb(196, 138, 52), rgb(250, 190, 80)],
                bottom: [rgb(11, 6, 14), rgb(122, 46, 14), rgb(203, 80, 9), rgb(200, 93, 13)],
                right: [rgb(11, 6, 14), rgb(150, 70, 15), rgb(215, 110, 20)]
            ))
        }
        context.restoreGState()
    }

    func headerRule(_ rect: CGRect, in context: CGContext, backingScale: CGFloat) {
        let lineHeight = rect.height * 3.5 / 9.5
        let upper = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: lineHeight)
        let lower = CGRect(x: rect.minX, y: rect.maxY - lineHeight, width: rect.width, height: lineHeight)
        self.fillRows(in: self.snapped(upper, backingScale: backingScale), colors: [
            rgb(108, 116, 122), rgb(247, 250, 254), rgb(212, 193, 133), rgb(133, 93, 8),
            rgb(215, 194, 100), rgb(255, 255, 242), rgb(182, 185, 175),
        ], context: context)
        self.fillRows(in: self.snapped(lower, backingScale: backingScale), colors: [
            rgb(29, 33, 43), rgb(216, 218, 223), rgb(240, 224, 160), rgb(167, 112, 12),
            rgb(212, 150, 5), rgb(253, 220, 46), rgb(202, 178, 73),
        ], context: context)
    }

    func dotGrid(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        context.setFillColor(rgb(26, 33, 45).cgColor)
        var y = rect.minY + 1.15
        while y < rect.maxY {
            var x = rect.minX + 1.35
            while x < rect.maxX {
                context.fill(CGRect(x: x, y: y, width: 1.5, height: 2))
                x += 4.25
            }
            y += 5
        }
        context.restoreGState()
    }

    func sliderTrack(
        _ rect: CGRect,
        fill: AmpXTrackFill,
        fraction: Double,
        in context: CGContext,
        backingScale: CGFloat
    ) {
        let track = self.snapped(rect, backingScale: backingScale)
        let ramp = AmpXSliderColorRamp.color(for: fill, fraction: fraction)
        let color = TrackColor(r: ramp.r, g: ramp.g, b: ramp.b)

        let ring = track.insetBy(dx: -0.5, dy: -0.5)
        context.addPath(CGPath(roundedRect: ring, cornerWidth: ring.height / 2, cornerHeight: ring.height / 2, transform: nil))
        context.setFillColor(rgb(58, 70, 90).cgColor)
        context.fillPath()
        let lip = track.offsetBy(dx: 0, dy: 1)
        context.addPath(CGPath(roundedRect: lip, cornerWidth: lip.height / 2, cornerHeight: lip.height / 2, transform: nil))
        context.setFillColor(rgb(88, 106, 130).cgColor)
        context.fillPath()

        context.addPath(CGPath(roundedRect: track, cornerWidth: track.height / 2, cornerHeight: track.height / 2, transform: nil))
        context.setFillColor(rgb(2, 3, 6).cgColor)
        context.fillPath()

        let inner = track.insetBy(dx: 1.5, dy: 1.5)
        context.saveGState()
        context.addPath(CGPath(roundedRect: inner, cornerWidth: inner.height / 2, cornerHeight: inner.height / 2, transform: nil))
        context.clip()
        // Winamp's full-width bar: the ramp color spans the whole track; only its color follows the value.
        self.drawVerticalGradient(in: inner, stops: [
            (0, rgb(color.r * 0.88, color.g * 0.85, color.b)),
            (0.2, rgb(color.r, color.g, color.b)),
            (0.8, rgb(color.r, color.g, color.b)),
            (1, rgb(min(255, color.r + 8), min(255, color.g + 50), min(255, color.b + 110))),
        ], context: context)
        context.restoreGState()
    }

    func seekWell(_ well: CGRect, track: CGRect, in context: CGContext, backingScale: CGFloat) {
        let outer = self.snapped(well, backingScale: backingScale)
        let channel = self.snapped(track, backingScale: backingScale)
        context.setFillColor(rgb(17, 26, 44).cgColor)
        context.fill(outer)
        self.drawBands(in: outer, unit: 0.5, context: context, edges: Edges(
            top: [rgb(47, 59, 83), rgb(33, 44, 68), rgb(5, 9, 21), rgb(1, 0, 8), rgb(10, 13, 26)],
            left: [rgb(40, 52, 76), rgb(20, 28, 46), rgb(5, 9, 21)],
            bottom: [rgb(14, 23, 42), rgb(60, 73, 100), rgb(76, 90, 121)],
            right: [rgb(60, 73, 100), rgb(40, 52, 76), rgb(20, 28, 46)]
        ))
        let lip = CGRect(x: channel.minX, y: channel.maxY, width: channel.width, height: max(0, outer.maxY - 1.5 - channel.maxY))
        self.fillRows(in: lip, colors: [rgb(73, 88, 116), rgb(79, 95, 125)] + Array(repeating: rgb(47, 60, 87), count: 4), context: context)

        context.setFillColor(rgb(12, 18, 33).cgColor)
        context.fill(channel)
        self.drawBands(in: channel, unit: 0.5, context: context, edges: Edges(
            top: [rgb(0, 0, 2), rgb(6, 11, 20)],
            left: [rgb(0, 0, 2), rgb(8, 12, 22)],
            bottom: [rgb(23, 29, 48), rgb(10, 15, 29)],
            right: [rgb(23, 29, 48)]
        ))
    }

    func metallicThumb(_ rect: CGRect, material: AmpXThumbMaterial, in context: CGContext, backingScale: CGFloat) {
        let thumb = self.snapped(rect, backingScale: backingScale)
        switch material {
        case .steel:
            self.drawSteelThumb(thumb, context: context)
        case .steelLevel:
            drawSteelLevelThumb(thumb, context: context)
        case .gold:
            self.drawGoldThumb(thumb, context: context)
        case .goldTab:
            self.drawGoldTab(thumb, context: context)
        }
    }

    private func drawSteelThumb(_ thumb: CGRect, context: CGContext) {
        context.addPath(CGPath(roundedRect: thumb, cornerWidth: 2, cornerHeight: 2, transform: nil))
        context.setFillColor(rgb(2, 4, 8).cgColor)
        context.fillPath()

        let face = thumb.insetBy(dx: 1, dy: 1)
        context.saveGState()
        context.addPath(CGPath(roundedRect: face, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        context.clip()
        self.drawVerticalGradient(in: face, stops: [
            (0, rgb(134, 140, 148)), (0.03, rgb(234, 241, 249)), (0.1, rgb(218, 226, 240)),
            (0.25, rgb(161, 171, 191)), (0.4, rgb(143, 153, 175)), (0.8, rgb(124, 139, 166)),
            (0.93, rgb(103, 116, 139)), (1, rgb(61, 71, 95)),
        ], context: context)
        context.setFillColor(rgb(213, 222, 235).cgColor)
        context.fill(CGRect(x: face.minX, y: face.minY, width: 1, height: face.height))
        context.setFillColor(rgb(61, 71, 95).cgColor)
        context.fill(CGRect(x: face.maxX - 1, y: face.minY, width: 1, height: face.height))
        context.restoreGState()

        let grooveHeight = min(12, face.height - 6)
        for offset: CGFloat in [-3, 0, 3] {
            let groove = CGRect(
                x: thumb.midX + offset - 0.75,
                y: thumb.midY - grooveHeight / 2,
                width: 1.5,
                height: grooveHeight
            )
            context.setFillColor(rgb(169, 182, 200).cgColor)
            context.fill(groove.insetBy(dx: -0.5, dy: -0.5))
            context.setFillColor(rgb(6, 14, 33).cgColor)
            context.fill(groove)
        }
    }

    private func drawGoldThumb(_ thumb: CGRect, context: CGContext) {
        context.setFillColor(rgb(8, 5, 3).cgColor)
        context.fill(thumb)
        let outer = thumb.insetBy(dx: 1, dy: 1)
        let inner = outer.insetBy(dx: 4.25, dy: 3)

        func quad(_ points: [CGPoint], _ color: NSColor) {
            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color.cgColor)
            context.fillPath()
        }
        let tl = CGPoint(x: outer.minX, y: outer.minY), tr = CGPoint(x: outer.maxX, y: outer.minY)
        let bl = CGPoint(x: outer.minX, y: outer.maxY), br = CGPoint(x: outer.maxX, y: outer.maxY)
        let itl = CGPoint(x: inner.minX, y: inner.minY), itr = CGPoint(x: inner.maxX, y: inner.minY)
        let ibl = CGPoint(x: inner.minX, y: inner.maxY), ibr = CGPoint(x: inner.maxX, y: inner.maxY)
        quad([tl, tr, itr, itl], rgb(240, 212, 145))
        quad([tl, itl, ibl, bl], rgb(224, 192, 118))
        quad([tr, br, ibr, itr], rgb(176, 140, 64))
        quad([bl, ibl, ibr, br], rgb(170, 134, 58))

        context.setFillColor(rgb(255, 255, 211).cgColor)
        context.fill(CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 0.5))

        context.setLineWidth(0.5)
        context.setStrokeColor(rgb(255, 246, 205).cgColor)
        context.strokeLineSegments(between: [tl, itl, tr, itr])
        context.setStrokeColor(rgb(120, 90, 40).cgColor)
        context.strokeLineSegments(between: [bl, ibl, br, ibr])

        self.drawVerticalGradient(in: inner, stops: [
            (0, rgb(130, 96, 38)), (0.22, rgb(150, 115, 52)), (0.4, rgb(240, 209, 139)),
            (0.62, rgb(255, 255, 229)), (0.78, rgb(214, 182, 104)), (1, rgb(197, 163, 81)),
        ], context: context)
    }

    // MARK: - Band drawing

    private struct TrackColor {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
    }

    private struct Edges {
        var top: [NSColor]
        var left: [NSColor]
        var bottom: [NSColor]
        var right: [NSColor]
    }

    private enum Palette {
        static let panel = rgb(19, 27, 45)
        static let wellBlack = rgb(3, 5, 7)
    }

    private func bandUnit(for rect: CGRect) -> CGFloat {
        min(0.5, min(rect.width, rect.height) / 12)
    }

    /// Draws edge bands from the outside inward; each band is `unit` points wide.
    private func drawBands(in rect: CGRect, unit: CGFloat, context: CGContext, edges: Edges) {
        for (index, color) in edges.left.enumerated() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: rect.minX + CGFloat(index) * unit, y: rect.minY, width: unit, height: rect.height))
        }
        for (index, color) in edges.right.enumerated() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: rect.maxX - CGFloat(index + 1) * unit, y: rect.minY, width: unit, height: rect.height))
        }
        for (index, color) in edges.top.enumerated() {
            let inset = CGFloat(index) * unit
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: rect.minX + inset, y: rect.minY + inset, width: rect.width - inset * 2, height: unit))
        }
        for (index, color) in edges.bottom.enumerated() {
            let inset = CGFloat(index) * unit
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: rect.minX + inset, y: rect.maxY - inset - unit, width: rect.width - inset * 2, height: unit))
        }
    }

    private func fillRows(in rect: CGRect, colors: [NSColor], context: CGContext) {
        guard !colors.isEmpty else { return }
        let rowHeight = rect.height / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: rect.minX, y: rect.minY + CGFloat(index) * rowHeight, width: rect.width, height: rowHeight))
        }
    }

    private func drawVerticalGradient(in rect: CGRect, stops: [(CGFloat, NSColor)], context: CGContext) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: stops.map(\.1.cgColor) as CFArray,
            locations: stops.map(\.0)
        ) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
    }

    private func snapped(_ rect: CGRect, backingScale: CGFloat) -> CGRect {
        let minX = AmpXPixelGrid.align(rect.minX, backingScale: backingScale)
        let minY = AmpXPixelGrid.align(rect.minY, backingScale: backingScale)
        return CGRect(
            x: minX,
            y: minY,
            width: AmpXPixelGrid.align(rect.maxX, backingScale: backingScale) - minX,
            height: AmpXPixelGrid.align(rect.maxY, backingScale: backingScale) - minY
        )
    }
}

// MARK: - Playlist scrollbar tab

extension ClassicModernSkin {
    /// Gold tab sampled from the reference Playlist scrollbar thumb.
    func drawGoldTab(_ tab: CGRect, context: CGContext) {
        context.addPath(CGPath(roundedRect: tab, cornerWidth: 1, cornerHeight: 1, transform: nil))
        context.setFillColor(rgb(3, 2, 6).cgColor)
        context.fillPath()

        let face = tab.insetBy(dx: 0.5, dy: 0.5)
        self.drawVerticalGradient(in: face, stops: [
            (0, rgb(209, 201, 150)), (0.02, rgb(255, 243, 181)), (0.04, rgb(239, 220, 155)),
            (0.07, rgb(198, 168, 93)), (0.5, rgb(193, 162, 84)), (0.9, rgb(188, 157, 79)),
            (0.93, rgb(143, 117, 58)), (0.97, rgb(115, 92, 44)), (1, rgb(67, 56, 29)),
        ], context: context)
        context.setFillColor(rgb(255, 255, 247).cgColor)
        context.fill(CGRect(x: face.minX + 0.5, y: face.minY + 1, width: 0.5, height: face.height - 2))
        context.setFillColor(rgb(230, 219, 174).cgColor)
        context.fill(CGRect(x: face.minX + 1, y: face.minY + 1, width: 0.5, height: face.height - 2))
        context.setFillColor(rgb(118, 97, 48).cgColor)
        context.fill(CGRect(x: face.maxX - 1.5, y: face.minY + 1, width: 1, height: face.height - 2))
        context.setFillColor(rgb(78, 62, 33).cgColor)
        context.fill(CGRect(x: face.maxX - 0.5, y: face.minY + 1, width: 0.5, height: face.height - 2))
    }
}

// MARK: - Equalizer level sliders

extension ClassicModernSkin {
    private struct LevelRGB {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat

        func mixed(with other: LevelRGB, _ t: CGFloat) -> LevelRGB {
            LevelRGB(r: self.r + (other.r - self.r) * t, g: self.g + (other.g - self.g) * t, b: self.b + (other.b - self.b) * t)
        }

        var color: NSColor {
            rgb(self.r, self.g, self.b)
        }
    }

    func levelTrack(_ slot: CGRect, decibels: Double, in context: CGContext, backingScale: CGFloat) {
        let slot = self.snapped(slot, backingScale: backingScale)
        let radius = slot.width / 2

        func pill(_ rect: CGRect) -> CGPath {
            let r = min(radius, rect.width / 2)
            return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        }

        context.addPath(pill(slot.offsetBy(dx: 0.5, dy: 1)))
        context.setFillColor(rgb(52, 63, 86).cgColor)
        context.fillPath()
        context.addPath(pill(slot))
        context.setFillColor(rgb(2, 3, 8).cgColor)
        context.fillPath()
        context.addPath(pill(slot.insetBy(dx: 1, dy: 1)))
        context.setFillColor(rgb(14, 23, 37).cgColor)
        context.fillPath()

        let bar = slot.insetBy(dx: 2.5, dy: 3)
        let color = self.levelColor(decibels: decibels)
        let bottom = LevelRGB(r: color.r, g: color.g * 0.96, b: color.b * 0.5)
        context.saveGState()
        context.addPath(pill(bar))
        context.clip()
        self.drawVerticalGradient(in: bar, stops: [
            (0, rgb(color.r, color.g, min(255, color.b + 40))),
            (0.05, color.color),
            (1, bottom.color),
        ], context: context)
        let edge = rgb(color.r * 0.84, color.g * 0.55, color.b * 0.15).withAlphaComponent(0.8)
        context.setFillColor(edge.cgColor)
        context.fill(CGRect(x: bar.minX, y: bar.minY, width: 1, height: bar.height))
        context.fill(CGRect(x: bar.maxX - 1, y: bar.minY, width: 1, height: bar.height))
        context.setFillColor(rgb(255, 251, 225).withAlphaComponent(0.85).cgColor)
        context.fill(CGRect(x: bar.minX + 1, y: bar.minY, width: 0.5, height: bar.height))
        context.restoreGState()
    }

    /// Bar hue by gain: shared slider green at −12 dB, yellow near 0, and shared red at +12 dB.
    private func levelColor(decibels: Double) -> LevelRGB {
        let minimum = AmpXSliderColorRamp.green
        let maximum = AmpXSliderColorRamp.red
        let stops: [(decibels: Double, color: LevelRGB)] = [
            (-12, LevelRGB(r: minimum.r, g: minimum.g, b: minimum.b)), (-6, LevelRGB(r: 200, g: 236, b: 50)),
            (-3.2, LevelRGB(r: 204, g: 230, b: 42)), (-2.3, LevelRGB(r: 250, g: 222, b: 46)),
            (-1, LevelRGB(r: 234, g: 220, b: 40)), (0, LevelRGB(r: 238, g: 218, b: 36)),
            (0.4, LevelRGB(r: 241, g: 214, b: 33)), (0.8, LevelRGB(r: 253, g: 192, b: 70)),
            (1.7, LevelRGB(r: 250, g: 206, b: 50)), (3, LevelRGB(r: 251, g: 168, b: 30)),
            (12, LevelRGB(r: maximum.r, g: maximum.g, b: maximum.b)),
        ]
        let value = min(max(decibels, -12), 12)
        for (lower, upper) in zip(stops, stops.dropFirst()) where value <= upper.decibels {
            let t = CGFloat((value - lower.decibels) / (upper.decibels - lower.decibels))
            return lower.color.mixed(with: upper.color, t)
        }
        return stops[stops.count - 1].color
    }

    func drawSteelLevelThumb(_ thumb: CGRect, context: CGContext) {
        context.addPath(CGPath(roundedRect: thumb, cornerWidth: 2, cornerHeight: 2, transform: nil))
        context.setFillColor(rgb(1, 2, 5).cgColor)
        context.fillPath()

        let face = thumb.insetBy(dx: 1, dy: 1)
        context.saveGState()
        context.addPath(CGPath(roundedRect: face, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        context.clip()
        self.drawVerticalGradient(in: face, stops: [
            (0, rgb(208, 216, 222)), (0.04, rgb(227, 235, 244)), (0.12, rgb(156, 169, 188)),
            (0.2, rgb(126, 141, 165)), (0.6, rgb(117, 131, 156)), (0.86, rgb(118, 132, 157)),
            (0.93, rgb(93, 105, 127)), (1, rgb(63, 74, 95)),
        ], context: context)
        context.setFillColor(rgb(232, 243, 255).cgColor)
        context.fill(CGRect(x: face.minX, y: face.minY, width: 0.5, height: face.height))
        context.setFillColor(rgb(185, 198, 213).cgColor)
        context.fill(CGRect(x: face.minX + 0.5, y: face.minY, width: 0.5, height: face.height))
        context.setFillColor(rgb(71, 82, 106).cgColor)
        context.fill(CGRect(x: face.maxX - 1, y: face.minY, width: 1, height: face.height))
        context.restoreGState()

        for offset: CGFloat in [-3, 3] {
            let groove = CGRect(x: thumb.midX - 3.5, y: thumb.midY - 0.5 + offset - 0.75, width: 7, height: 1.5)
            context.setFillColor(rgb(177, 189, 204).cgColor)
            context.fill(CGRect(x: groove.minX, y: groove.maxY + 0.5, width: groove.width + 0.5, height: 0.75))
            context.setFillColor(rgb(8, 10, 18).cgColor)
            context.fill(groove)
        }
    }
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
