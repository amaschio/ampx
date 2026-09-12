import AppKit
import CoreGraphics

final class PlayerModuleContent: AmpXModuleContent {
    private let segmentDigits: AmpXSegmentDigits

    private let volumeSlider: AmpXSlider
    private let balanceSlider: AmpXSlider
    private let positionSlider: AmpXSlider
    private let eqToggle: AmpXButton
    private let plToggle: AmpXButton
    private var transportButtons: [AmpXButton] = []

    private static let referenceTrackTitle = "4. Crusher-P - Echo (3:50)"
    private static let referenceTimer = "01:51"

    private static let leftSpectrumHeights: [Int] = [
        4, 6, 8, 10, 12, 11, 9, 7, 8, 10, 12, 13, 12, 10, 8, 6, 5, 4, 3,
    ]
    private static let rightSpectrumHeights: [Int] = [
        3, 5, 7, 9, 11, 12, 10, 8, 9, 11, 12, 11, 9, 7, 6, 5, 4, 3, 2,
    ]

    override init(skin: any AmpXSkin) {
        self.segmentDigits = AmpXSegmentDigits(skin: skin)
        self.volumeSlider = AmpXSlider(skin: skin)
        self.balanceSlider = AmpXSlider(skin: skin)
        self.positionSlider = AmpXSlider(skin: skin)
        self.eqToggle = AmpXButton(skin: skin)
        self.plToggle = AmpXButton(skin: skin)
        super.init(skin: skin)
        configureControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureControls() {
        volumeSlider.range = 0 ... 1
        volumeSlider.showsGradient = true
        volumeSlider.setValue(Self.volumeFraction, sendChange: false)

        balanceSlider.range = 0 ... 1
        balanceSlider.showsGradient = true
        balanceSlider.setValue(Self.balanceFraction, sendChange: false)

        positionSlider.range = 0 ... 1
        positionSlider.setValue(0.38, sendChange: false)

        eqToggle.label = "EQ"
        eqToggle.showsActiveIndicator = true
        eqToggle.isActive = true
        eqToggle.accessibilityTitle = "Equalizer"

        plToggle.label = "PL"
        plToggle.showsActiveIndicator = true
        plToggle.isActive = true
        plToggle.accessibilityTitle = "Playlist"

        let transportIcons: [AmpXIcon?] = [
            .previous, .play, .pause, .stop, .next, .eject, nil, .`repeat`, .menu,
        ]
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() {
            let button = AmpXButton(skin: skin)
            button.frame = frame
            if index == 6 {
                button.label = "SHUFFLE"
                button.showsActiveIndicator = true
                button.isActive = true
                button.accessibilityTitle = "Shuffle"
            } else if index == 8 {
                button.style = .menu
                button.icon = .menu
                button.accessibilityTitle = "Menu"
            } else if let icon = transportIcons[index] {
                button.icon = icon
                button.iconColor = index == 1 ? skin.green : skin.text
                button.accessibilityTitle = transportLabel(for: icon)
            }
            transportButtons.append(button)
            addSubview(button)
        }

        for control in [volumeSlider, balanceSlider, positionSlider, eqToggle, plToggle] {
            addSubview(control)
        }
        layoutControls()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        volumeSlider.frame = AmpXMetrics.playerVolume
        balanceSlider.frame = AmpXMetrics.playerBalance
        positionSlider.frame = AmpXMetrics.playerPosition
        eqToggle.frame = AmpXMetrics.playerEQToggle
        plToggle.frame = AmpXMetrics.playerPLToggle
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() where index < transportButtons.count {
            transportButtons[index].frame = frame
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.inset(bounds, in: context, backingScale: backingScale)

        skin.displayWell(AmpXMetrics.playerDisplayWell, in: context, backingScale: backingScale)
        skin.displayWell(AmpXMetrics.playerTrackWell, in: context, backingScale: backingScale)

        drawPlayGlyph(in: context)
        segmentDigits.draw(Self.referenceTimer, in: AmpXMetrics.playerTimer, context: context)
        drawSpectrum(in: context)

        drawTrackTitle(in: context)
        drawMetadata(in: context)
    }

    private static var volumeFraction: Double {
        let track = AmpXMetrics.playerVolume
        return Double((AmpXMetrics.playerVolumeThumbCenterX - track.minX) / track.width)
    }

    private static var balanceFraction: Double {
        let track = AmpXMetrics.playerBalance
        return Double((AmpXMetrics.playerBalanceThumbCenterX - track.minX) / track.width)
    }

    private func transportLabel(for icon: AmpXIcon) -> String {
        switch icon {
        case .previous: "Previous"
        case .play: "Play"
        case .pause: "Pause"
        case .stop: "Stop"
        case .next: "Next"
        case .eject: "Eject"
        case .repeat: "Repeat"
        default: "Transport"
        }
    }

    private func drawPlayGlyph(in context: CGContext) {
        AmpXIcon.play.draw(
            in: AmpXMetrics.playerPlayGlyph,
            context: context,
            skin: skin,
            color: skin.green
        )
    }

    private func drawSpectrum(in context: CGContext) {
        let well = AmpXMetrics.playerDisplayWell
        let segmentHeight = AmpXMetrics.spectrumSegmentHeight
        let segmentGap = AmpXMetrics.spectrumSegmentGap
        let columnPitch = AmpXMetrics.spectrumColumnPitch
        let baseY = well.maxY - 6

        drawSpectrumChannel(
            originX: well.minX + AmpXMetrics.spectrumLeftColumnX,
            baseY: baseY,
            heights: Self.leftSpectrumHeights,
            segmentHeight: segmentHeight,
            segmentGap: segmentGap,
            columnPitch: columnPitch,
            context: context
        )
        drawSpectrumChannel(
            originX: well.minX + AmpXMetrics.spectrumRightColumnX,
            baseY: baseY,
            heights: Self.rightSpectrumHeights,
            segmentHeight: segmentHeight,
            segmentGap: segmentGap,
            columnPitch: columnPitch,
            context: context
        )

        AmpXLabel(text: "L", color: skin.green, fontSize: 8, weight: .semibold)
            .draw(in: CGRect(x: well.minX + 4, y: baseY - 44, width: 10, height: 10), context: context, skin: skin)
        AmpXLabel(text: "R", color: skin.green, fontSize: 8, weight: .semibold)
            .draw(in: CGRect(x: well.minX + AmpXMetrics.spectrumRightColumnX - 2, y: baseY - 44, width: 10, height: 10), context: context, skin: skin)
    }

    private func drawSpectrumChannel(
        originX: CGFloat,
        baseY: CGFloat,
        heights: [Int],
        segmentHeight: CGFloat,
        segmentGap: CGFloat,
        columnPitch: CGFloat,
        context: CGContext
    ) {
        for (index, litCount) in heights.enumerated() {
            let columnX = originX + CGFloat(index) * columnPitch
            for segment in 0..<litCount {
                let y = baseY - CGFloat(segment + 1) * (segmentHeight + segmentGap)
                let color = spectrumColor(for: segment, of: 16)
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: columnX, y: y, width: 4.5, height: segmentHeight))
            }
        }
    }

    private func spectrumColor(for segment: Int, of total: Int) -> NSColor {
        let ratio = CGFloat(segment) / CGFloat(max(total - 1, 1))
        if ratio < 0.45 {
            return skin.green
        }
        if ratio < 0.75 {
            return skin.yellow
        }
        return skin.orange
    }

    private func drawTrackTitle(in context: CGContext) {
        let inset = AmpXMetrics.playerTrackWell.insetBy(dx: 5.5, dy: 7)
        AmpXLabel(text: Self.referenceTrackTitle, color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: inset, context: context, skin: skin)
    }

    private func drawMetadata(in context: CGContext) {
        let rect = AmpXMetrics.playerMetadata
        AmpXLabel(text: "128", color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: CGRect(x: rect.minX, y: rect.minY, width: 28, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "kbps", color: skin.green, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.minX + 26, y: rect.minY + 2, width: 28, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "48", color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: CGRect(x: rect.minX + 54, y: rect.minY, width: 22, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "kHz", color: skin.green, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.minX + 72, y: rect.minY + 2, width: 24, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "mono", color: skin.textDim, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.maxX - 52, y: rect.minY + 2, width: 24, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "stereo", color: skin.green, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.maxX - 28, y: rect.minY + 2, width: 28, height: rect.height), context: context, skin: skin)
    }
}
