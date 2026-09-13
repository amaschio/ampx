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
        let viewport = self.makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 1000, viewportHeight: 600)

        viewport.setScrollOffset(-50)
        XCTAssertEqual(viewport.scrollOffset, 0)

        viewport.setScrollOffset(500)
        XCTAssertEqual(viewport.scrollOffset, 400)

        viewport.setScrollOffset(200)
        XCTAssertEqual(viewport.scrollOffset, 200)
    }

    func testVisibleContentRectReflectsScrollOffset() {
        let viewport = self.makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        viewport.setScrollOffset(150)

        XCTAssertEqual(viewport.visibleContentRect, CGRect(x: 0, y: 150, width: 490, height: 400))
    }

    func testRevealScrollsToExposeRect() {
        let viewport = self.makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 1000, viewportHeight: 400)

        viewport.reveal(CGRect(x: 0, y: 700, width: 490, height: 50))
        XCTAssertEqual(viewport.scrollOffset, 350)

        viewport.reveal(CGRect(x: 0, y: 0, width: 490, height: 50))
        XCTAssertEqual(viewport.scrollOffset, 0)
    }

    func testContentHeightChangePreservesTopEdge() {
        let viewport = self.makeViewport()
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
        let viewport = self.makeViewport()
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        var observed: [CGRect] = []
        viewport.onVisibleRectChanged = { observed.append($0) }

        viewport.setScrollOffset(100)
        XCTAssertEqual(observed.last, CGRect(x: 0, y: 100, width: 490, height: 400))
    }

    func testStackContentPointIncludesScrollOffset() throws {
        let viewport = self.makeViewport(inWindowAt: NSPoint(x: 100, y: 200))
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        viewport.setScrollOffset(120)

        let viewportPoint = NSPoint(x: 50, y: 80)
        let windowPoint = viewport.convert(viewportPoint, to: nil)
        let screenPoint = try XCTUnwrap(viewport.window?.convertPoint(toScreen: windowPoint))
        let contentPoint = viewport.stackContentPoint(fromScreenPoint: screenPoint)

        XCTAssertEqual(contentPoint.x, viewportPoint.x, accuracy: 0.5)
        XCTAssertEqual(contentPoint.y, viewportPoint.y + viewport.scrollOffset, accuracy: 0.5)
    }

    func testStackContentPointRecomputesWhenScrollOffsetChanges() throws {
        let viewport = self.makeViewport(inWindowAt: NSPoint(x: 100, y: 200))
        viewport.applyLayoutMetrics(contentHeight: 800, viewportHeight: 400)
        let viewportPoint = NSPoint(x: 50, y: 80)
        let windowPoint = viewport.convert(viewportPoint, to: nil)
        let screenPoint = try XCTUnwrap(viewport.window?.convertPoint(toScreen: windowPoint))

        viewport.setScrollOffset(100)
        let before = viewport.stackContentPoint(fromScreenPoint: screenPoint)

        viewport.setScrollOffset(160)
        let after = viewport.stackContentPoint(fromScreenPoint: screenPoint)

        XCTAssertEqual(after.y - before.y, 60, accuracy: 0.5)
        XCTAssertEqual(after.x, before.x, accuracy: 0.5)
    }

    func testContainsUsesScreenConversionFromForeignWindow() throws {
        let stackWindow = NSWindow(
            contentRect: CGRect(x: 100, y: 200, width: 490, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let viewport = self.makeViewport()
        stackWindow.contentView = viewport
        viewport.frame = try XCTUnwrap(stackWindow.contentView?.bounds)

        let foreignWindow = NSWindow(
            contentRect: CGRect(x: 700, y: 500, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let overStackScreenPoint = stackWindow.convertPoint(toScreen: NSPoint(x: 245, y: 200))
        let outsideStackScreenPoint = foreignWindow.convertPoint(toScreen: NSPoint(x: 10, y: 10))

        XCTAssertTrue(viewport.contains(screenPoint: overStackScreenPoint))
        XCTAssertFalse(viewport.contains(screenPoint: outsideStackScreenPoint))
    }

    private func makeViewport(inWindowAt origin: NSPoint = .zero) -> AmpXStackViewport {
        let skin = ClassicModernSkin()
        let viewport = AmpXStackViewport(skin: skin)
        viewport.frame = CGRect(x: 0, y: 0, width: 490, height: 400)

        if origin != .zero {
            let window = NSWindow(
                contentRect: CGRect(origin: origin, size: viewport.frame.size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = viewport
            viewport.frame = window.contentView!.bounds
        }

        return viewport
    }
}
