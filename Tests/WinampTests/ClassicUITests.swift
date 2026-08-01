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
