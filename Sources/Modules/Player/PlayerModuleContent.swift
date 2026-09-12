import AppKit
import CoreGraphics

final class PlayerModuleContent: AmpXModuleContent {
    private let segmentDigits: AmpXSegmentDigits

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
        super.init(skin: skin)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        drawSlider(
            track: AmpXMetrics.playerVolume,
            thumbCenterX: AmpXMetrics.playerVolumeThumbCenterX,
            in: context,
            backingScale: backingScale
        )
        drawSlider(
            track: AmpXMetrics.playerBalance,
            thumbCenterX: AmpXMetrics.playerBalanceThumbCenterX,
            in: context,
            backingScale: backingScale,
            gradient: true
        )
        drawModuleToggles(in: context, backingScale: backingScale)

        drawPositionBar(in: context, backingScale: backingScale)
        drawTransport(in: context, backingScale: backingScale)
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

    private func drawSlider(
        track: CGRect,
        thumbCenterX: CGFloat,
        in context: CGContext,
        backingScale: CGFloat,
        gradient: Bool = false
    ) {
        skin.displayWell(track, in: context, backingScale: backingScale)

        if gradient {
            let colors = [skin.green.cgColor, skin.yellow.cgColor, skin.orange.cgColor] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.5, 1]
            ) {
                context.saveGState()
                context.clip(to: track.insetBy(dx: 1, dy: 1))
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: track.minX, y: track.midY),
                    end: CGPoint(x: track.maxX, y: track.midY),
                    options: []
                )
                context.restoreGState()
            }
        }

        let thumb = CGRect(
            x: thumbCenterX - 4,
            y: track.minY + 1,
            width: 8,
            height: track.height - 2
        )
        skin.bevel(thumb, in: context, backingScale: backingScale)
        context.setFillColor(skin.panelLight.cgColor)
        context.fill(thumb.insetBy(dx: 1, dy: 1))
    }

    private func drawModuleToggles(in context: CGContext, backingScale: CGFloat) {
        for (label, rect) in [
            ("EQ", AmpXMetrics.playerEQToggle),
            ("PL", AmpXMetrics.playerPLToggle),
        ] {
            skin.bevel(rect, in: context, backingScale: backingScale)
            AmpXLabel(text: label, color: skin.text, fontSize: 8, weight: .semibold)
                .draw(in: rect.insetBy(dx: 2, dy: 2), context: context, skin: skin)
            let indicator = CGRect(x: rect.maxX - 7, y: rect.midY - 2, width: 4, height: 4)
            context.setFillColor(skin.green.cgColor)
            context.fill(indicator)
        }
    }

    private func drawPositionBar(in context: CGContext, backingScale: CGFloat) {
        let track = AmpXMetrics.playerPosition
        skin.displayWell(track, in: context, backingScale: backingScale)

        let thumbX = track.minX + track.width * 0.38
        let thumb = CGRect(x: thumbX - 5, y: track.minY - 3, width: 10, height: track.height + 6)
        skin.bevel(thumb, in: context, backingScale: backingScale)
        context.setFillColor(skin.panelLight.cgColor)
        context.fill(thumb.insetBy(dx: 1, dy: 1))
    }

    private func drawTransport(in context: CGContext, backingScale: CGFloat) {
        let icons: [AmpXIcon?] = [
            .previous, .play, .pause, .stop, .next, .eject, nil, .`repeat`, .menu,
        ]

        for (index, frame) in AmpXMetrics.playerTransport.enumerated() {
            let isMenu = index == 8
            if isMenu {
                context.setFillColor(skin.orange.cgColor)
                context.fill(frame.insetBy(dx: 1, dy: 1))
            } else {
                skin.bevel(frame, in: context, backingScale: backingScale)
            }

            if index == 6 {
                AmpXLabel(text: "SHUFFLE", color: skin.text, fontSize: 7, weight: .semibold)
                    .draw(in: frame.insetBy(dx: 2, dy: 10), context: context, skin: skin)
                let indicator = CGRect(x: frame.midX - 2, y: frame.minY + 4, width: 4, height: 4)
                context.setFillColor(skin.green.cgColor)
                context.fill(indicator)
                continue
            }

            guard let icon = icons[index] else { continue }
            let iconColor = index == 1 ? skin.green : skin.text
            icon.draw(
                in: frame.insetBy(dx: 10, dy: 8),
                context: context,
                skin: skin,
                color: iconColor
            )
        }
    }
}
