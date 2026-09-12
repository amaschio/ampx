@testable import AmpX
import XCTest

final class AmpXLayoutTests: XCTestCase {
    func testScaleClampsToReferenceBounds() {
        XCTAssertEqual(AmpXLayout.scale(width: 490), 1)
        XCTAssertEqual(AmpXLayout.scale(width: 416.5), 0.85)
        XCTAssertEqual(AmpXLayout.scale(width: 980), 1.35)
    }

    func testPlayerOnlyLayoutAtUnitScale() {
        var state = AmpXModuleOrder()
        state.close(.equalizer)
        state.close(.playlist)
        let layout = AmpXLayout.calculate(
            state: state,
            width: 490,
            playlistViewportHeight: 180,
            availableHeight: 1000
        )
        XCTAssertEqual(layout.scale, 1)
        XCTAssertEqual(layout.contentHeight, 223.5)
        XCTAssertEqual(layout.viewportHeight, 223.5)
        XCTAssertFalse(layout.scrolls)
        XCTAssertEqual(layout.frames.count, 1)
        XCTAssertEqual(layout.frames[.player]?.minX, 0)
        XCTAssertEqual(layout.frames[.player]?.width, 490)
        XCTAssertEqual(layout.frames[.player]?.height, 223.5)
    }

    func testWideLayoutCentersCompositionAtMaxScale() {
        var state = AmpXModuleOrder()
        state.close(.equalizer)
        state.close(.playlist)
        let wide = AmpXLayout.calculate(
            state: state,
            width: 800,
            playlistViewportHeight: 180,
            availableHeight: 1000
        )
        XCTAssertEqual(wide.scale, 1.35)
        XCTAssertEqual(wide.frames[.player]!.minX, (800 - 490 * 1.35) / 2, accuracy: 0.0001)
        XCTAssertEqual(wide.frames[.player]!.width, 490 * 1.35, accuracy: 0.0001)
    }

    func testTableDrivenLayouts() {
        let cases: [(name: String, state: AmpXModuleOrder, expectedHeight: CGFloat, moduleCount: Int)] = [
            (
                "full default stack",
                AmpXModuleOrder(),
                223.5 + 6 + 225.5 + 6 + 305,
                3
            ),
            (
                "collapsed equalizer",
                {
                    var state = AmpXModuleOrder()
                    state.setCollapsed(.equalizer, true)
                    return state
                }(),
                223.5 + 6 + AmpXMetrics.headerHeight + 6 + 305,
                3
            ),
            (
                "player only",
                {
                    var state = AmpXModuleOrder()
                    state.close(.equalizer)
                    state.close(.playlist)
                    return state
                }(),
                223.5,
                1
            ),
        ]

        for testCase in cases {
            let layout = AmpXLayout.calculate(
                state: testCase.state,
                width: 490,
                playlistViewportHeight: AmpXMetrics.defaultPlaylistViewportHeight,
                availableHeight: 10_000
            )
            XCTAssertEqual(
                layout.contentHeight,
                testCase.expectedHeight,
                accuracy: 0.0001,
                "Unexpected content height for \(testCase.name)"
            )
            XCTAssertEqual(
                layout.frames.count,
                testCase.moduleCount,
                "Unexpected module count for \(testCase.name)"
            )
        }
    }

    func testIgnoresDetachedAndClosedModulesInStackLayout() {
        var state = AmpXModuleOrder()
        state.detach(.playlist)
        state.close(.equalizer)
        let layout = AmpXLayout.calculate(
            state: state,
            width: 490,
            playlistViewportHeight: 180,
            availableHeight: 1000
        )
        XCTAssertEqual(layout.frames.count, 1)
        XCTAssertNotNil(layout.frames[.player])
        XCTAssertNil(layout.frames[.playlist])
        XCTAssertNil(layout.frames[.equalizer])
    }

    func testOverflowShrinksPlaylistViewportBeforeScrolling() {
        var state = AmpXModuleOrder()
        state.reopen(.enthea)
        let result = AmpXLayout.calculate(
            state: state,
            width: 661.5,
            playlistViewportHeight: 180,
            availableHeight: 600
        )
        XCTAssertEqual(result.scale, 1.35)
        XCTAssertEqual(result.playlistViewportHeight, 66)
        XCTAssertTrue(result.scrolls)
        XCTAssertEqual(result.viewportHeight, 600)
        XCTAssertGreaterThan(result.contentHeight, result.viewportHeight)
    }

    func testCustomPlaylistViewportAdjustsPlaylistModuleHeight() {
        let state = AmpXModuleOrder()
        let layout = AmpXLayout.calculate(
            state: state,
            width: 490,
            playlistViewportHeight: 120,
            availableHeight: 10_000
        )
        let expectedPlaylistHeight = AmpXMetrics.headerHeight
            + AmpXMetrics.playlistNonRowChrome
            + 120
        XCTAssertEqual(layout.frames[.playlist]?.height, expectedPlaylistHeight)
        XCTAssertEqual(layout.playlistViewportHeight, 120)
    }
}
