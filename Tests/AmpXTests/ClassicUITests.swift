import XCTest
@testable import AmpX

final class ClassicMarqueeTypographyTests: XCTestCase {
    func testGlyphsPreserveMappedPunctuation() {
        let glyphs = ClassicMarqueeTypography.glyphs(for: "Artist - Title (3:42)")
        XCTAssertEqual(String(glyphs), "artist - title (3:42)")
    }

    func testUnmappedCharactersBecomeSpaces() {
        let glyphs = ClassicMarqueeTypography.glyphs(for: "A#B")
        XCTAssertEqual(String(glyphs), "a b")
    }

    func testScrollPeriodUsesTextPlusSeparators() {
        let width = ClassicMarqueeTypography.scrollPeriodWidth(glyphCount: 10, scale: 2)
        // (10 + 3) * 5 * 2
        XCTAssertEqual(width, 130)
    }

    func testScrollOffsetIsZeroWhenTextFits() {
        let offset = ClassicMarqueeTypography.scrollOffset(
            elapsed: 5,
            periodWidth: 50,
            viewWidth: 100,
            scale: 1
        )
        XCTAssertEqual(offset, 0)
    }

    func testScrollOffsetLoopsOverFullPeriod() {
        let period: CGFloat = 100
        let offset = ClassicMarqueeTypography.scrollOffset(
            elapsed: 6,
            periodWidth: period,
            viewWidth: 40,
            scale: 1,
            speed: 20
        )
        // travelled = 120 → rem 20 → -20
        XCTAssertEqual(offset, -20)
    }
}

final class AmpXSkinFilmstripTests: XCTestCase {
    func testVolumeFilmstripEnds() {
        let quiet = AmpXSkinSprites.Volume.background(forNormalized: 0)
        let loud = AmpXSkinSprites.Volume.background(forNormalized: 1)
        XCTAssertEqual(quiet.y, 0)
        XCTAssertEqual(loud.y, 27 * 15)
        XCTAssertEqual(quiet.width, 68)
        XCTAssertEqual(loud.height, 13)
    }

    func testBalanceFilmstripUsesDistanceFromCenter() {
        let center = AmpXSkinSprites.Balance.background(forNormalized: 0.5)
        let left = AmpXSkinSprites.Balance.background(forNormalized: 0)
        let right = AmpXSkinSprites.Balance.background(forNormalized: 1)
        XCTAssertEqual(center.y, 0)
        XCTAssertEqual(left.y, 27 * 15)
        XCTAssertEqual(right.y, 27 * 15)
        XCTAssertEqual(center.x, 9)
        XCTAssertEqual(center.width, 38)
    }

    func testEQSliderFilmstripMatchesWebampGrid() {
        let low = AmpXSkinSprites.EQMain.sliderBackground(forNormalized: 0)
        let mid = AmpXSkinSprites.EQMain.sliderBackground(forNormalized: 0.5)
        let high = AmpXSkinSprites.EQMain.sliderBackground(forNormalized: 1)
        XCTAssertEqual(low.x, 13)
        XCTAssertEqual(low.y, 164)
        // Int((0.5 * 27).rounded()) = 14 → col 0, row 1
        XCTAssertEqual(mid.x, 13)
        XCTAssertEqual(mid.y, 164 + 65)
        // 27 → col 13, row 1
        XCTAssertEqual(high.x, 13 + 13 * 15)
        XCTAssertEqual(high.y, 164 + 65)
    }
}

final class ClassicPlaylistLayoutDefaultsTests: XCTestCase {
    @MainActor
    func testFreshPlaylistWidthDefaultsToClassicGrid() {
        let suite = "classic-playlist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let layout = AmpXPanelLayoutState(defaults: defaults)
        XCTAssertEqual(layout.playlistSize.width, ClassicSkinMetrics.windowWidth)
    }

    @MainActor
    func testAlignShrinksLegacyModernDefaultWidth() {
        let suite = "classic-align-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let layout = AmpXPanelLayoutState(defaults: defaults)
        layout.playlistSize = CGSize(width: AmpXUIScale.basePanelWidth, height: 300)
        layout.alignPlaylistWidthToStyle(
            baseWidth: ClassicSkinMetrics.windowWidth,
            allowShrinkFromLegacyDefault: true
        )
        XCTAssertEqual(layout.playlistSize.width, ClassicSkinMetrics.windowWidth)
    }

    func testPleditTileCountSkipsEmptyFlexSlot() {
        // At classic width the bottom flex tile is offered 0pt — a forced tile would overflow
        // the 275px chrome HStack and get clipped on horizontal resize.
        XCTAssertEqual(ClassicPleditTiling.tileCount(containerLength: 0, tileLength: 25), 0)
        XCTAssertEqual(ClassicPleditTiling.tileCount(containerLength: 0.4, tileLength: 25), 0)
    }

    func testPleditTileCountCoversWidenedFlexSlot() {
        XCTAssertEqual(ClassicPleditTiling.tileCount(containerLength: 25, tileLength: 25), 1)
        XCTAssertEqual(ClassicPleditTiling.tileCount(containerLength: 26, tileLength: 25), 2)
        XCTAssertEqual(ClassicPleditTiling.tileCount(containerLength: 125, tileLength: 25), 5)
    }
}

final class ClassicVisualizerLayoutDefaultsTests: XCTestCase {
    @MainActor
    func testVisualizerDefaultsHiddenWithDefaultSize() {
        let suite = "classic-viz-default-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let layout = AmpXPanelLayoutState(defaults: defaults)
        XCTAssertFalse(layout.showVisualizer)
        XCTAssertFalse(layout.visualizerInTheater)
        XCTAssertEqual(layout.visualizerSize.width, LegacyPanelMetrics.defaultVisualizerWidth)
        XCTAssertEqual(layout.visualizerSize.height, LegacyPanelMetrics.defaultVisualizerHeight)
    }

    @MainActor
    func testVisualizerSizePersists() {
        let suite = "classic-viz-size-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let layout = AmpXPanelLayoutState(defaults: defaults)
        layout.visualizerSize = CGSize(width: 640, height: 480)
        let restored = AmpXPanelLayoutState(defaults: defaults)
        XCTAssertEqual(restored.visualizerSize.width, 640)
        XCTAssertEqual(restored.visualizerSize.height, 480)
    }

    @MainActor
    func testVisualizerVisibilityPersists() {
        let suite = "classic-viz-vis-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let layout = AmpXPanelLayoutState(defaults: defaults)
        layout.showVisualizer = true
        let restored = AmpXPanelLayoutState(defaults: defaults)
        XCTAssertTrue(restored.showVisualizer)
    }

    @MainActor
    func testScaleVisualizerDimensions() {
        let suite = "classic-viz-scale-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let layout = AmpXPanelLayoutState(defaults: defaults)
        layout.visualizerSize = CGSize(width: 600, height: 450)
        layout.scaleVisualizerDimensions(by: 2)
        XCTAssertEqual(layout.visualizerSize.width, 1200)
        XCTAssertEqual(layout.visualizerSize.height, 900)
    }

    /// Theater must not remount the ENTHEA/Metal body — that resets in-page settings
    /// (mic sensitivity, reactivity, etc.) by recreating the WKWebView.
    func testVisualizerBodyStaysMountedAcrossTheaterToggle() {
        XCTAssertTrue(
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: false, theater: false)
        )
        XCTAssertTrue(
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: false, theater: true)
        )
        XCTAssertEqual(
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: false, theater: false),
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: false, theater: true)
        )
        XCTAssertFalse(
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: true, theater: false)
        )
        XCTAssertFalse(
            ClassicVisualizerPanelMounting.isBodyMounted(minimized: true, theater: true)
        )
    }

    func testVisualizerChromeInsetsZeroInTheaterOnly() {
        let docked = ClassicVisualizerPanelMounting.contentInsets(
            isTheater: false,
            scale: 1,
            sideLeft: 12,
            sideRight: 20,
            topBarHeight: 20,
            presetStripHeight: 14,
            bottomBarHeight: 38
        )
        let theater = ClassicVisualizerPanelMounting.contentInsets(
            isTheater: true,
            scale: 1,
            sideLeft: 12,
            sideRight: 20,
            topBarHeight: 20,
            presetStripHeight: 14,
            bottomBarHeight: 38
        )
        XCTAssertEqual(docked.top, 34)
        XCTAssertEqual(docked.leading, 12)
        XCTAssertEqual(docked.bottom, 38)
        XCTAssertEqual(docked.trailing, 20)
        XCTAssertEqual(theater.top, 0)
        XCTAssertEqual(theater.leading, 0)
        XCTAssertEqual(theater.bottom, 0)
        XCTAssertEqual(theater.trailing, 0)
    }
}

final class AmpXPanelPlacementTests: XCTestCase {
    func testVisualizerInitialOriginIsRightOfMain() {
        let main = CGRect(x: 100, y: 400, width: 275, height: 116)
        let size = CGSize(width: 600, height: 450)
        let origin = AmpXPanelPlacement.initialOrigin(
            panelID: .visualizer,
            panelSize: size,
            mainFrame: main,
            stackBelowOrigin: nil
        )
        XCTAssertEqual(origin.x, 375)
        XCTAssertEqual(origin.y, 66)
    }

    func testEqualizerInitialOriginStacksBelow() {
        let main = CGRect(x: 100, y: 400, width: 275, height: 116)
        let size = CGSize(width: 275, height: 116)
        let origin = AmpXPanelPlacement.initialOrigin(
            panelID: .equalizer,
            panelSize: size,
            mainFrame: main,
            stackBelowOrigin: CGPoint(x: 100, y: 284)
        )
        XCTAssertEqual(origin, CGPoint(x: 100, y: 168))
    }
}

final class AmpXUIScaleLevelMigrationTests: XCTestCase {
    func testNearestLevelMapsLegacy125PercentTo150() {
        // Former `.large = 1.25` — equidistant from 1.0 and 1.5; ties prefer larger.
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 1.25), .extraLarge)
    }

    func testNearestLevelPreservesExactLevels() {
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 1.0), .standard)
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 1.5), .extraLarge)
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 2.0), .huge)
    }

    func testNearestLevelClampsBelowAndAboveRange() {
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 0.5), .standard)
        XCTAssertEqual(AmpXUIScale.nearestLevel(to: 3.0), .huge)
    }
}
