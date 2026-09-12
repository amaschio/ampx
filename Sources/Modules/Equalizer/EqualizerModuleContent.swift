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

    private let onToggle: AmpXButton
    private let autoToggle: AmpXButton
    private let presetsButton: AmpXButton
    private let preampSlider: AmpXSlider
    private var bandSliders: [AmpXSlider] = []

    override init(skin: any AmpXSkin) {
        self.onToggle = AmpXButton(skin: skin)
        self.autoToggle = AmpXButton(skin: skin)
        self.presetsButton = AmpXButton(skin: skin)
        self.preampSlider = AmpXSlider(skin: skin)
        super.init(skin: skin)
        configureControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureControls() {
        onToggle.label = "ON"
        onToggle.showsActiveIndicator = true
        onToggle.isActive = true
        onToggle.accessibilityTitle = "Equalizer on"

        autoToggle.label = "AUTO"
        autoToggle.showsActiveIndicator = true
        autoToggle.isActive = false
        autoToggle.accessibilityTitle = "Equalizer auto"

        presetsButton.label = "PRESETS"
        presetsButton.accessibilityTitle = "Equalizer presets"

        preampSlider.isVertical = true
        preampSlider.range = -1 ... 1
        preampSlider.step = 1.0 / 12.0
        preampSlider.showsGradient = true
        preampSlider.showsThumbGrip = true
        preampSlider.setValue(Double(Self.mockPreamp), sendChange: false)
        preampSlider.accessibilityTitle = "Preamp"

        let row = AmpXMetrics.eqBandRow
        for index in 0 ..< AmpXEQBands.bandCount {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            let track = CGRect(
                x: centerX - Self.sliderTrackWidth / 2,
                y: row.minY,
                width: Self.sliderTrackWidth,
                height: row.height
            )
            let slider = AmpXSlider(skin: skin)
            slider.frame = track
            slider.isVertical = true
            slider.range = -1 ... 1
            slider.step = 1.0 / 12.0
            slider.showsGradient = true
            slider.showsThumbGrip = true
            slider.setValue(Double(Self.mockBands[index]), sendChange: false)
            slider.accessibilityTitle = "\(AmpXEQBands.displayLabels[index]) band"
            bandSliders.append(slider)
            addSubview(slider)
        }

        for control in [onToggle, autoToggle, presetsButton, preampSlider] {
            addSubview(control)
        }
        layoutControls()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        onToggle.frame = Self.eqOnToggle
        autoToggle.frame = Self.eqAutoToggle
        presetsButton.frame = Self.eqPresetsButton
        preampSlider.frame = AmpXMetrics.eqPreamp

        let row = AmpXMetrics.eqBandRow
        for index in 0 ..< bandSliders.count {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            bandSliders[index].frame = CGRect(
                x: centerX - Self.sliderTrackWidth / 2,
                y: row.minY,
                width: Self.sliderTrackWidth,
                height: row.height
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.inset(bounds, in: context, backingScale: backingScale)

        drawCurveWell(in: context, backingScale: backingScale)
        drawDecibelScale(in: context)
        drawHorizontalGuides(in: context)
        drawSliderLabels(in: context)
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
