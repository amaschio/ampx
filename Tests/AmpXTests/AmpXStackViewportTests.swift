@testable import AmpX
import XCTest

@MainActor
final class AmpXStackViewportTests: XCTestCase {
    func testMaximumScaleShortScreenOverflowLayout() {
        var state = AmpXModuleOrder()
        state.reopen(.enthea)
        let result = AmpXLayout.calculate(
            state: state,
            width: 661.5,
            playlistViewportHeight: 180,
            availableHeight: 600
        )
        XCTAssertEqual(result.playlistViewportHeight, 66)
        XCTAssertTrue(result.scrolls)
        XCTAssertEqual(result.viewportHeight, 600)
        XCTAssertGreaterThan(result.contentHeight, result.viewportHeight)
    }

    func testScrollOffsetClampsToContentLimits() {
        let viewport = makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 1000, viewportHeight: 600)

        viewport.setScrollOffset(-50)
        XCTAssertEqual(viewport.scrollOffset, 0)

        viewport.setScrollOffset(500)
        XCTAssertEqual(viewport.scrollOffset, 400)

        viewport.setScrollOffset(200)
        XCTAssertEqual(viewport.scrollOffset, 200)
    }

    func testVisibleContentRectReflectsScrollOffset() {
        let viewport = makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        viewport.setScrollOffset(150)

        XCTAssertEqual(viewport.visibleContentRect, CGRect(x: 0, y: 150, width: 490, height: 400))
    }

    func testRevealScrollsToExposeRect() {
        let viewport = makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 1000, viewportHeight: 400)

        viewport.reveal(CGRect(x: 0, y: 700, width: 490, height: 50))
        XCTAssertEqual(viewport.scrollOffset, 350)

        viewport.reveal(CGRect(x: 0, y: 0, width: 490, height: 50))
        XCTAssertEqual(viewport.scrollOffset, 0)
    }

    func testContentHeightChangePreservesTopEdge() {
        let viewport = makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 1000, viewportHeight: 400)
        viewport.setScrollOffset(300)

        viewport.applyLayoutMetrics(contentHeight: 500, viewportHeight: 400)
        XCTAssertEqual(viewport.scrollOffset, 100)
    }

    func testRestoredScreenSpaceReturnsPreferredPlaylistViewport() {
        var state = AmpXModuleOrder()
        state.reopen(.enthea)

        let cramped = AmpXLayout.calculate(
            state: state,
            width: 661.5,
            playlistViewportHeight: 180,
            availableHeight: 600
        )
        XCTAssertEqual(cramped.playlistViewportHeight, 66)

        let restored = AmpXLayout.calculate(
            state: state,
            width: 661.5,
            playlistViewportHeight: 180,
            availableHeight: 2000
        )
        XCTAssertEqual(restored.playlistViewportHeight, 180)
        XCTAssertFalse(restored.scrolls)
    }

    func testOnVisibleRectChangedFiresWhenOffsetChanges() {
        let viewport = makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        var observed: [CGRect] = []
        viewport.onVisibleRectChanged = { observed.append($0) }

        viewport.setScrollOffset(100)
        XCTAssertEqual(observed.last, CGRect(x: 0, y: 100, width: 490, height: 400))
    }

    private func makeViewport() -> AmpXStackViewport {
        let skin = ClassicModernSkin()
        let viewport = AmpXStackViewport(skin: skin)
        viewport.frame = CGRect(x: 0, y: 0, width: 490, height: 400)
        return viewport
    }
}
