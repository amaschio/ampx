import AppKit
import CoreGraphics

final class EqualizerModuleContent: AmpXModuleContent {
    /// Normalized display gains derived from reference PNG thumb positions (not audio settings).
    private static let mockBands: [Float] = [
        0.333, 0.583, 0.167, -0.167, -0.5, -0.583, -0.083, 0.417, 0.667, 0.75,
    ]

    private static let mockPreamp: Float = 0

    private static let eqOnToggle = CGRect(x: 15.0, y: 14.0, width: 26.0, height: 18.0)
    private static let eqAutoToggle = CGRect(x: 43.0, y: 14.0, width: 32.0, height: 18.0)
    private static let eqPresetsButton = CGRect(x: 418.0, y: 14.0, width: 54.0, height: 18.0)

    private static let sliderTrackWidth: CGFloat = 18
    private static let sliderThumbHeight: CGFloat = 8

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.inset(bounds, in: context, backingScale: backingScale)

        drawToggle(label: "ON", rect: Self.eqOnToggle, active: true, in: context, backingScale: backingScale)
        drawToggle(label: "AUTO", rect: Self.eqAutoToggle, active: false, in: context, backingScale: backingScale)
        drawPresetsButton(in: context, backingScale: backingScale)
        drawCurveWell(in: context, backingScale: backingScale)
        drawDecibelScale(in: context)
        drawHorizontalGuides(in: context)
        drawVerticalSlider(
            track: AmpXMetrics.eqPreamp,
            value: Self.mockPreamp,
            in: context,
            backingScale: backingScale
        )
        drawBandSliders(in: context, backingScale: backingScale)
        drawSliderLabels(in: context)
    }

    private func drawToggle(
        label: String,
        rect: CGRect,
        active: Bool,
        in context: CGContext,
        backingScale: CGFloat
    ) {
        skin.bevel(rect, in: context, backingScale: backingScale)
        AmpXLabel(text: label, color: skin.text, fontSize: 8, weight: .semibold)
            .draw(in: rect.insetBy(dx: 2, dy: 3), context: context, skin: skin)

        if active {
            let indicator = CGRect(x: rect.maxX - 7, y: rect.midY - 2, width: 4, height: 4)
            context.setFillColor(skin.green.cgColor)
            context.fill(indicator)
        } else {
            context.setFillColor(skin.textDim.cgColor)
            context.fillEllipse(in: CGRect(x: rect.maxX - 7, y: rect.midY - 2, width: 4, height: 4))
        }
    }

    private func drawPresetsButton(in context: CGContext, backingScale: CGFloat) {
        let rect = Self.eqPresetsButton
        skin.bevel(rect, in: context, backingScale: backingScale)
        AmpXLabel(text: "PRESETS", color: skin.text, fontSize: 7, weight: .semibold)
            .draw(in: rect.insetBy(dx: 3, dy: 3), context: context, skin: skin)
    }

    private func drawCurveWell(in context: CGContext, backingScale: CGFloat) {
        let well = AmpXMetrics.eqCurve
        skin.displayWell(well, in: context, backingScale: backingScale)

        let midY = well.midY
        var x = well.minX + 1
        while x < well.maxX - 1 {
            context.setFillColor(skin.textDim.withAlphaComponent(0.55).cgColor)
            context.fill(CGRect(x: x, y: midY, width: 1, height: 1))
            x += 3
        }

        let points = AmpXEQBands.responseCurvePoints(
            bandValues: Self.mockBands,
            preampValue: Self.mockPreamp,
            width: well.width,
            height: well.height
        )
        context.saveGState()
        context.translateBy(x: well.minX, y: well.minY)
        context.addPath(CatmullRomSpline.path(through: points).cgPath)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        let colors = [skin.yellow.cgColor, skin.orange.cgColor] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: well.width, y: 0),
                options: []
            )
        }
        context.restoreGState()
    }

    private func drawDecibelScale(in context: CGContext) {
        let track = AmpXMetrics.eqPreamp
        let labels: [(String, CGFloat)] = [
            ("+12 dB", track.minY + 2),
            ("0 dB", track.midY - 4),
            ("-12 dB", track.maxY - 12),
        ]
        for (text, y) in labels {
            AmpXLabel(text: text, color: skin.orange, fontSize: 7, weight: .medium)
                .draw(in: CGRect(x: track.maxX + 2, y: y, width: 28, height: 10), context: context, skin: skin)
        }
    }

    private func drawHorizontalGuides(in context: CGContext) {
        let row = AmpXMetrics.eqBandRow
        let track = AmpXMetrics.eqPreamp
        let guideYs = [
            track.minY + 2,
            track.midY,
            track.maxY - 2,
        ]
        context.saveGState()
        context.setStrokeColor(skin.textDim.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [2, 2])
        for y in guideYs {
            context.move(to: CGPoint(x: row.minX, y: y))
            context.addLine(to: CGPoint(x: row.maxX, y: y))
        }
        context.strokePath()
        context.restoreGState()
    }

    private func drawBandSliders(in context: CGContext, backingScale: CGFloat) {
        let row = AmpXMetrics.eqBandRow
        for index in 0 ..< AmpXEQBands.bandCount {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            let track = CGRect(
                x: centerX - Self.sliderTrackWidth / 2,
                y: row.minY,
                width: Self.sliderTrackWidth,
                height: row.height
            )
            drawVerticalSlider(track: track, value: Self.mockBands[index], in: context, backingScale: backingScale)
        }
    }

    private func drawVerticalSlider(
        track: CGRect,
        value: Float,
        in context: CGContext,
        backingScale: CGFloat
    ) {
        skin.displayWell(track, in: context, backingScale: backingScale)

        let colors = [skin.orange.cgColor, skin.yellow.cgColor, skin.green.cgColor] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.5, 1]
        ) {
            context.saveGState()
            context.clip(to: track.insetBy(dx: 1, dy: 1))
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: track.midX, y: track.minY),
                end: CGPoint(x: track.midX, y: track.maxY),
                options: []
            )
            context.restoreGState()
        }

        let thumbCenterY = thumbCenterY(in: track, normalizedValue: value)
        let thumb = CGRect(
            x: track.midX - 5,
            y: thumbCenterY - Self.sliderThumbHeight / 2,
            width: 10,
            height: Self.sliderThumbHeight
        )
        skin.bevel(thumb, in: context, backingScale: backingScale)
        context.setFillColor(skin.panelLight.cgColor)
        context.fill(thumb.insetBy(dx: 1, dy: 1))
        context.setFillColor(skin.borderDark.cgColor)
        context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY - 1, width: thumb.width - 4, height: 1))
        context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY + 1, width: thumb.width - 4, height: 1))
    }

    private func thumbCenterY(in track: CGRect, normalizedValue: Float) -> CGFloat {
        let travel = track.height - Self.sliderThumbHeight
        let progress = (CGFloat(normalizedValue) + 1) / 2
        return track.minY + (1 - progress) * travel + Self.sliderThumbHeight / 2
    }

    private func drawSliderLabels(in context: CGContext) {
        let row = AmpXMetrics.eqBandRow
        let preampLabel = CGRect(
            x: AmpXMetrics.eqPreamp.minX - 4,
            y: row.maxY + 2,
            width: AmpXMetrics.eqPreamp.width + 8,
            height: 12
        )
        AmpXLabel(text: "PREAMP", color: skin.orange, fontSize: 7, weight: .medium, alignment: .center)
            .draw(in: preampLabel, context: context, skin: skin)

        for index in 0 ..< AmpXEQBands.bandCount {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            let labelRect = CGRect(x: centerX - 16, y: row.maxY + 2, width: 32, height: 12)
            AmpXLabel(
                text: AmpXEQBands.displayLabels[index],
                color: skin.orange,
                fontSize: 7,
                weight: .medium,
                alignment: .center
            )
            .draw(in: labelRect, context: context, skin: skin)
        }
    }
}
