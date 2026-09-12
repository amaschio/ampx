@testable import AmpX
import AppKit
import XCTest

@MainActor
final class AmpXReferenceRenderingTests: XCTestCase {
    private let skin = ClassicModernSkin()

    // MARK: - Geometry regressions (production geometry, no copied rectangles)

    func testAdjacentTransportFacesDoNotIntersect() {
        for pair in zip(AmpXMetrics.playerTransport, AmpXMetrics.playerTransport.dropFirst()) {
            XCTAssertFalse(pair.0.intersects(pair.1), "Adjacent transport controls overlap")
        }
    }

    func testChannelLabelsDoNotIntersectNumericOrUnitLabels() {
        for (bitrate, sampleRate) in [("128", "48"), ("1411", "44.1"), ("320", "192")] {
            let layout = PlayerModuleContent.metadataLayout(bitrate: bitrate, sampleRate: sampleRate)
            let items = layout.items
            for item in items {
                let measured = AmpXLabel(text: item.text, color: skin.green, fontSize: item.fontSize, weight: item.weight)
                    .measuredSize(skin: skin)
                XCTAssertLessThanOrEqual(
                    measured.width, item.rect.width + 0.01,
                    "\(item.text) would wrap or clip for \(bitrate)/\(sampleRate)"
                )
            }
            for pair in items.indices.flatMap({ i in items.indices.filter { $0 > i }.map { (items[i], items[$0]) } }) {
                XCTAssertFalse(
                    pair.0.rect.intersects(pair.1.rect),
                    "\(pair.0.text) intersects \(pair.1.text) for \(bitrate)/\(sampleRate)"
                )
            }
        }
    }

    func testShortButtonTextHasPositiveUsableHeight() {
        let button = AmpXButton(skin: skin)
        button.frame = CGRect(x: 0, y: 0, width: 46.5, height: 20.5)
        button.label = "EQ"
        XCTAssertGreaterThanOrEqual(button.labelRect.height, button.labelFont.capHeight)
        XCTAssertTrue(button.bounds.contains(button.labelRect))
    }

    func testDigitCellWidthIsStableAcrossTimeFormats() {
        let frame = PlayerModuleContent.timerFrame
        let short = AmpXSegmentDigits.cells(for: "0:04", in: frame).filter { $0.character != ":" }
        let long = AmpXSegmentDigits.cells(for: "01:51", in: frame).filter { $0.character != ":" }
        let widths = Set((short + long).map { ($0.rect.width * 100).rounded() })
        XCTAssertEqual(widths.count, 1, "Digit cells stretch as the time format changes")
        XCTAssertEqual(short.last?.rect.maxX ?? 0, long.last?.rect.maxX ?? 1, accuracy: 0.01)

        let remaining = AmpXSegmentDigits.cells(for: "-12:34", in: frame)
        for pair in zip(remaining, remaining.dropFirst()) {
            XCTAssertFalse(pair.0.rect.intersects(pair.1.rect))
        }
        XCTAssertGreaterThan(remaining.first?.rect.minX ?? 0, PlayerModuleContent.playGlyphFrame.maxX)
    }

    func testSliderArtworkIsUnchangedWhenOnlyHitBoundsEnlarge() throws {
        let content = makePlayerContent()
        let slider = try XCTUnwrap(controlSliders(in: content).first)
        slider.setValue(0.4, sendChange: false)
        let track = slider.convert(slider.trackRect, to: content)
        let thumb = slider.convert(slider.thumbRect, to: content)

        slider.frame = slider.frame.insetBy(dx: -6, dy: -8)

        XCTAssertEqual(slider.convert(slider.trackRect, to: content), track)
        XCTAssertEqual(slider.convert(slider.thumbRect, to: content), thumb)
    }

    func testPointerAtThumbCenterMapsToDisplayedValue() throws {
        let content = makePlayerContent()
        for slider in controlSliders(in: content) + positionSliders(in: content) {
            for value in [0.0, 0.25, 0.5, 0.75, 1.0] {
                slider.setValue(value, sendChange: false)
                let center = CGPoint(x: slider.thumbRect.midX, y: slider.thumbRect.midY)
                XCTAssertEqual(slider.value(at: center), value, accuracy: 0.002)
            }
            XCTAssertEqual(slider.value(at: CGPoint(x: slider.bounds.minX - 20, y: slider.bounds.midY)), 0)
            XCTAssertEqual(slider.value(at: CGPoint(x: slider.bounds.maxX + 20, y: slider.bounds.midY)), 1)
        }
    }

    func testHeaderButtonsFollowReferenceOrder() {
        let player = AmpXModuleHeaderView(moduleID: .player, skin: skin)
        player.frame = CGRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: AmpXMetrics.headerHeight)
        let playerOrder = player.headerButtonLayout().sorted { $0.frame.minX < $1.frame.minX }.map(\.button)
        XCTAssertEqual(playerOrder, [.minimize, .collapse, .close])

        let equalizer = AmpXModuleHeaderView(moduleID: .equalizer, skin: skin)
        equalizer.frame = player.frame
        let equalizerOrder = equalizer.headerButtonLayout().sorted { $0.frame.minX < $1.frame.minX }.map(\.button)
        XCTAssertEqual(equalizerOrder, [.collapse, .close])
    }

    // MARK: - Deterministic reference capture

    /// Display-only values matching `screenshots/AmpX.png`. Spectrum levels/peaks are in segments (of 6).
    static let playerReference = PlayerReferencePresentation(
        trackTitle: "4. Crusher-P - Echo (3:50)",
        timeText: "01:51",
        bitrateText: "128",
        sampleRateText: "48",
        isMono: false,
        isStereo: true,
        isPlaying: true,
        spectrumLevels: [4, 4, 6, 3.3, 4, 2.4, 2.2, 2.5, 1.4, 1, 1, 1, 0.35, 0.3, 0.25, 0.15].map { $0 / 6 },
        spectrumPeaks: [4.6, 5.6, 6, 3.6, 5.6, 3.6, 3.4, 3.6, 2.4, 1.6, 2.6, 1.6, 1.4, 1.4, 1.2, 1.3].map { $0 / 6 },
        volume: 0.762,
        balance: 0.5,
        position: 0.498,
        equalizerOpen: true,
        playlistOpen: true,
        shuffleEnabled: true,
        repeatEnabled: false
    )

    func testPlayerStaticReferenceCaptureIsDeterministic() throws {
        let content = makePlayerContent()
        content.referencePresentation = Self.playerReference
        let module = AmpXModuleView(moduleID: .player, content: content, skin: skin)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: AmpXMetrics.playerHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(module)
        module.applyLayout(frame: CGRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: AmpXMetrics.playerHeight))

        let first = try capture(module)
        let second = try capture(module)
        XCTAssertEqual(first.pixelsWide, 980)
        XCTAssertEqual(first.pixelsHigh, 447)
        let firstPNG = try XCTUnwrap(first.representation(using: .png, properties: [:]))
        let secondPNG = try XCTUnwrap(second.representation(using: .png, properties: [:]))
        XCTAssertEqual(firstPNG, secondPNG, "Frozen reference presentation must render identically")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AmpXReferenceRendering")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("player-static.png")
        try firstPNG.write(to: url)
        print("AMPX_REFERENCE_CAPTURE \(url.path) backingScale=\(window.backingScaleFactor)")
        let attachment = XCTAttachment(data: firstPNG, uniformTypeIdentifier: "public.png")
        attachment.name = "player-static.png"
        attachment.lifetime = .keepAlways
        add(attachment)
        withExtendedLifetime(window) {}
    }

    private func capture(_ view: NSView) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width * 2),
            pixelsHigh: Int(view.bounds.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return try XCTUnwrap(rep.converting(to: .sRGB, renderingIntent: .default))
    }

    // MARK: - Helpers

    private func makePlayerContent() -> PlayerModuleContent {
        let content = PlayerModuleContent(
            skin: skin,
            audioPlayer: AudioPlayer(installRemoteCommands: false),
            playlistManager: PlaylistManager(
                audioPlayer: MockAudioPlayer(),
                restoreBookmarks: false,
                restorePlaylist: false,
                alertPresenter: SilentPlaylistAlertPresenter()
            ),
            onToggleModule: { _ in }
        )
        content.frame = CGRect(
            x: 0,
            y: 0,
            width: AmpXMetrics.compositionWidth,
            height: AmpXMetrics.playerHeight - AmpXMetrics.headerHeight
        )
        return content
    }

    private func controlSliders(in root: NSView) -> [AmpXSlider] {
        allSubviews(of: root).compactMap { $0 as? AmpXSlider }.filter { !($0.superview is PositionBarView) }
    }

    private func positionSliders(in root: NSView) -> [AmpXSlider] {
        allSubviews(of: root).compactMap { $0 as? AmpXSlider }.filter { $0.superview is PositionBarView }
    }

    private func allSubviews(of root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + allSubviews(of: $0) }
    }
}
