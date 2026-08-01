import XCTest
@testable import Winamp

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

final class WinampSkinFilmstripTests: XCTestCase {
    func testVolumeFilmstripEnds() {
        let quiet = WinampSkinSprites.Volume.background(forNormalized: 0)
        let loud = WinampSkinSprites.Volume.background(forNormalized: 1)
        XCTAssertEqual(quiet.y, 0)
        XCTAssertEqual(loud.y, 27 * 15)
        XCTAssertEqual(quiet.width, 68)
        XCTAssertEqual(loud.height, 13)
    }

    func testBalanceFilmstripUsesDistanceFromCenter() {
        let center = WinampSkinSprites.Balance.background(forNormalized: 0.5)
        let left = WinampSkinSprites.Balance.background(forNormalized: 0)
        let right = WinampSkinSprites.Balance.background(forNormalized: 1)
        XCTAssertEqual(center.y, 0)
        XCTAssertEqual(left.y, 27 * 15)
        XCTAssertEqual(right.y, 27 * 15)
        XCTAssertEqual(center.x, 9)
        XCTAssertEqual(center.width, 38)
    }

    func testEQSliderFilmstripMatchesWebampGrid() {
        let low = WinampSkinSprites.EQMain.sliderBackground(forNormalized: 0)
        let mid = WinampSkinSprites.EQMain.sliderBackground(forNormalized: 0.5)
        let high = WinampSkinSprites.EQMain.sliderBackground(forNormalized: 1)
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
        let key = "playlistWidth"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
        let layout = WinampPanelLayoutState()
        XCTAssertEqual(layout.playlistSize.width, ClassicSkinMetrics.windowWidth)
    }

    @MainActor
    func testAlignShrinksLegacyModernDefaultWidth() {
        let layout = WinampPanelLayoutState()
        layout.playlistSize = CGSize(width: WinampUIScale.basePanelWidth, height: 300)
        layout.alignPlaylistWidthToStyle(
            baseWidth: ClassicSkinMetrics.windowWidth,
            allowShrinkFromLegacyDefault: true
        )
        XCTAssertEqual(layout.playlistSize.width, ClassicSkinMetrics.windowWidth)
    }
}

final class ClassicVisualizerLayoutDefaultsTests: XCTestCase {
    @MainActor
    func testVisualizerDefaultsHiddenWithDefaultSize() {
        let keys = ["showVisualizer", "visualizerWidth", "visualizerHeight"]
        var previous: [String: Any] = [:]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                previous[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        defer {
            for key in keys {
                if let value = previous[key] {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        let layout = WinampPanelLayoutState()
        XCTAssertFalse(layout.showVisualizer)
        XCTAssertEqual(layout.visualizerSize.width, WinampMetrics.defaultVisualizerWidth)
        XCTAssertEqual(layout.visualizerSize.height, WinampMetrics.defaultVisualizerHeight)
    }

    @MainActor
    func testVisualizerSizePersists() {
        let keyW = "visualizerWidth"
        let keyH = "visualizerHeight"
        let previousW = UserDefaults.standard.object(forKey: keyW)
        let previousH = UserDefaults.standard.object(forKey: keyH)
        defer {
            if let previousW {
                UserDefaults.standard.set(previousW, forKey: keyW)
            } else {
                UserDefaults.standard.removeObject(forKey: keyW)
            }
            if let previousH {
                UserDefaults.standard.set(previousH, forKey: keyH)
            } else {
                UserDefaults.standard.removeObject(forKey: keyH)
            }
        }

        let layout = WinampPanelLayoutState()
        layout.visualizerSize = CGSize(width: 640, height: 480)
        let restored = WinampPanelLayoutState()
        XCTAssertEqual(restored.visualizerSize.width, 640)
        XCTAssertEqual(restored.visualizerSize.height, 480)
    }

    @MainActor
    func testVisualizerVisibilityPersists() {
        let key = "showVisualizer"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let layout = WinampPanelLayoutState()
        layout.showVisualizer = true
        let restored = WinampPanelLayoutState()
        XCTAssertTrue(restored.showVisualizer)
    }

    @MainActor
    func testScaleVisualizerDimensions() {
        let layout = WinampPanelLayoutState()
        layout.visualizerSize = CGSize(width: 600, height: 450)
        layout.scaleVisualizerDimensions(by: 2)
        XCTAssertEqual(layout.visualizerSize.width, 1200)
        XCTAssertEqual(layout.visualizerSize.height, 900)
    }
}

final class WinampPanelPlacementTests: XCTestCase {
    func testVisualizerInitialOriginIsRightOfMain() {
        let main = CGRect(x: 100, y: 400, width: 275, height: 116)
        let size = CGSize(width: 600, height: 450)
        let origin = WinampPanelPlacement.initialOrigin(
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
        let origin = WinampPanelPlacement.initialOrigin(
            panelID: .equalizer,
            panelSize: size,
            mainFrame: main,
            stackBelowOrigin: CGPoint(x: 100, y: 284)
        )
        XCTAssertEqual(origin, CGPoint(x: 100, y: 168))
    }
}

final class WinampUIScaleLevelMigrationTests: XCTestCase {
    func testNearestLevelMapsLegacy125PercentTo150() {
        // Former `.large = 1.25` — equidistant from 1.0 and 1.5; ties prefer larger.
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 1.25), .extraLarge)
    }

    func testNearestLevelPreservesExactLevels() {
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 1.0), .standard)
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 1.5), .extraLarge)
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 2.0), .huge)
    }

    func testNearestLevelClampsBelowAndAboveRange() {
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 0.5), .standard)
        XCTAssertEqual(WinampUIScale.nearestLevel(to: 3.0), .huge)
    }
}
