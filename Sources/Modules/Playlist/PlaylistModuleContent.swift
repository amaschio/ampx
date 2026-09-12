import AppKit
import CoreGraphics

final class PlaylistModuleContent: AmpXModuleContent {
    private struct MockTrack {
        let title: String
        let duration: String
    }

    private static let mockTracks: [MockTrack] = [
        MockTrack(title: "Mori Calliope - Go-Getters", duration: "3:15"),
        MockTrack(title: "CircusP - Goodbye", duration: "3:24"),
        MockTrack(title: "AmaLee - Siren", duration: "4:02"),
        MockTrack(title: "Crusher-P - Echo", duration: "3:50"),
        MockTrack(title: "M83 - Midnight City", duration: "4:03"),
        MockTrack(title: "Sunnexo - Please Wait", duration: "4:15"),
        MockTrack(title: "Omaru Polka - Persona", duration: "4:56"),
    ]

    private static let selectedIndex = 3

    private static let footerButtons: [(label: String, rect: CGRect)] = [
        ("ADD", CGRect(x: 0.0, y: 25.0, width: 35.0, height: 40.5)),
        ("REM", CGRect(x: 41.0, y: 25.0, width: 40.5, height: 40.5)),
        ("SEL", CGRect(x: 87.0, y: 24.5, width: 41.0, height: 41.0)),
        ("MISC", CGRect(x: 133.0, y: 25.0, width: 43.0, height: 40.5)),
        ("LIST\nOPTS", CGRect(x: 399.5, y: 21.0, width: 41.5, height: 47.5)),
    ]

    private static let timeCounterWell = CGRect(x: 186.0, y: 22.0, width: 203.0, height: 18.5)
    private static let remainingTimeWell = CGRect(x: 341.0, y: 49.0, width: 48.0, height: 18.0)

    private static let miniTransport: [(icon: AmpXIcon, rect: CGRect, active: Bool)] = [
        (.previous, CGRect(x: 187.5, y: 45.0, width: 23.0, height: 24.0), false),
        (.play, CGRect(x: 217.0, y: 46.5, width: 23.0, height: 22.5), true),
        (.pause, CGRect(x: 246.5, y: 45.0, width: 24.0, height: 24.0), false),
        (.stop, CGRect(x: 276.5, y: 45.5, width: 23.5, height: 23.5), false),
        (.next, CGRect(x: 306.5, y: 45.5, width: 24.0, height: 23.5), false),
    ]

    private let scrollbar: AmpXScrollbar
    private var footerButtonsViews: [AmpXButton] = []
    private var miniTransportButtons: [AmpXButton] = []

    override init(skin: any AmpXSkin) {
        self.scrollbar = AmpXScrollbar(skin: skin)
        super.init(skin: skin)
        configureControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureControls() {
        scrollbar.contentLength = CGFloat(Self.mockTracks.count) * AmpXMetrics.playlistRowHeight
        scrollbar.viewportLength = AmpXMetrics.playlistRows.height
        scrollbar.offset = 0

        for (label, localRect) in Self.footerButtons {
            let button = AmpXButton(skin: skin)
            button.label = label
            button.accessibilityTitle = label.replacingOccurrences(of: "\n", with: " ")
            footerButtonsViews.append(button)
            addSubview(button)
        }

        for item in Self.miniTransport {
            let button = AmpXButton(skin: skin)
            button.icon = item.icon
            button.iconColor = item.active ? skin.green : skin.text
            button.isActive = item.active
            button.accessibilityTitle = miniTransportLabel(for: item.icon)
            miniTransportButtons.append(button)
            addSubview(button)
        }

        addSubview(scrollbar)
        layoutControls()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        scrollbar.frame = AmpXMetrics.playlistScrollbar
        let footer = AmpXMetrics.playlistFooter

        for (index, localRect) in Self.footerButtons.enumerated() where index < footerButtonsViews.count {
            footerButtonsViews[index].frame = footerRect(localRect.rect, in: footer)
        }

        for (index, item) in Self.miniTransport.enumerated() where index < miniTransportButtons.count {
            miniTransportButtons[index].frame = footerRect(item.rect, in: footer)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.inset(bounds, in: context, backingScale: backingScale)

        drawRowViewport(in: context)
        drawFooterLabels(in: context, backingScale: backingScale)
    }

    private func drawRowViewport(in context: CGContext) {
        let viewport = AmpXMetrics.playlistRows
        skin.displayWell(viewport, in: context, backingScale: window?.backingScaleFactor ?? 1)

        for index in 0 ..< Self.mockTracks.count {
            let row = rowRect(index: index)
            guard viewport.intersects(row) else { continue }

            let track = Self.mockTracks[index]
            let isSelected = index == Self.selectedIndex

            if isSelected {
                context.setFillColor(skin.selection.cgColor)
                context.fill(row)
            }

            let textColor = isSelected ? skin.text : skin.green
            let titleRect = CGRect(
                x: row.minX + 4,
                y: row.minY,
                width: row.width - AmpXMetrics.playlistDurationColumnWidth - 8,
                height: row.height
            )
            AmpXLabel(
                text: "\(index + 1). \(track.title)",
                color: textColor,
                fontSize: 11,
                weight: .medium
            )
            .draw(in: titleRect, context: context, skin: skin)

            let durationRect = CGRect(
                x: row.maxX - AmpXMetrics.playlistDurationColumnWidth,
                y: row.minY,
                width: AmpXMetrics.playlistDurationColumnWidth,
                height: row.height
            )
            AmpXLabel(
                text: track.duration,
                color: textColor,
                fontSize: 11,
                weight: .medium,
                alignment: .right
            )
            .draw(in: durationRect.insetBy(dx: 4, dy: 0), context: context, skin: skin)
        }
    }

    private func drawFooterLabels(in context: CGContext, backingScale: CGFloat) {
        let footer = AmpXMetrics.playlistFooter

        let timeRect = footerRect(Self.timeCounterWell, in: footer)
        skin.displayWell(timeRect, in: context, backingScale: backingScale)
        AmpXLabel(text: "0:00/27:45", color: skin.green, fontSize: 9, weight: .medium, alignment: .center)
            .draw(in: timeRect, context: context, skin: skin)

        let remainingRect = footerRect(Self.remainingTimeWell, in: footer)
        skin.displayWell(remainingRect, in: context, backingScale: backingScale)
        AmpXLabel(text: "-02:12", color: skin.green, fontSize: 9, weight: .medium, alignment: .center)
            .draw(in: remainingRect, context: context, skin: skin)
    }

    private func rowRect(index: Int) -> CGRect {
        CGRect(
            x: AmpXMetrics.playlistRows.minX,
            y: AmpXMetrics.playlistRows.minY + CGFloat(index) * AmpXMetrics.playlistRowHeight,
            width: AmpXMetrics.playlistRows.width,
            height: AmpXMetrics.playlistRowHeight
        )
    }

    private func footerRect(_ local: CGRect, in footer: CGRect) -> CGRect {
        CGRect(
            x: footer.minX + local.minX,
            y: footer.minY + local.minY,
            width: local.width,
            height: local.height
        )
    }

    private func miniTransportLabel(for icon: AmpXIcon) -> String {
        switch icon {
        case .previous: "Previous"
        case .play: "Play"
        case .pause: "Pause"
        case .stop: "Stop"
        case .next: "Next"
        default: "Transport"
        }
    }
}
