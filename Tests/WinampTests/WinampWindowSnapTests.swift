@testable import Winamp
import XCTest

final class WinampWindowSnapTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Zoom can leave a scaled snap radius in this process — restore the base 15 pt value.
        WinampWindowSnap.snapDistance = 15
    }

    override func tearDown() {
        WinampWindowSnap.snapDistance = 15
        super.tearDown()
    }

    func testNearWithinSnapDistance() {
        XCTAssertTrue(WinampWindowSnap.near(100, 110))
        XCTAssertFalse(WinampWindowSnap.near(100, 120))
    }

    func testAbutsVerticallyStackedWindows() {
        let main = WinampWindowSnap.Box(frame: CGRect(x: 50, y: 200, width: 275, height: 116))
        let eq = WinampWindowSnap.Box(frame: CGRect(x: 50, y: 116, width: 275, height: 84))
        XCTAssertTrue(WinampWindowSnap.abuts(main, eq))
    }

    func testAbutsHorizontallyAdjacentWindows() {
        let left = WinampWindowSnap.Box(frame: CGRect(x: 0, y: 100, width: 275, height: 116))
        let right = WinampWindowSnap.Box(frame: CGRect(x: 275, y: 100, width: 275, height: 232))
        XCTAssertTrue(WinampWindowSnap.abuts(left, right))
    }

    func testAbutsReturnsFalseForSeparatedWindows() {
        let a = WinampWindowSnap.Box(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let b = WinampWindowSnap.Box(frame: CGRect(x: 500, y: 500, width: 100, height: 100))
        XCTAssertFalse(WinampWindowSnap.abuts(a, b))
    }

    func testSnappedOriginStacksBelowAnchor() throws {
        let anchor = WinampWindowSnap.Box(frame: CGRect(x: 40, y: 300, width: 275, height: 116))
        let panel = WinampWindowSnap.Box(frame: CGRect(x: 48, y: 108, width: 275, height: 200))
        let snapped = WinampWindowSnap.snappedOrigin(
            box: panel,
            origin: NSPoint(x: 48, y: 108),
            against: anchor
        )
        XCTAssertNotNil(snapped)
        XCTAssertEqual(try XCTUnwrap(snapped?.x), 40, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(snapped?.y), 100, accuracy: 0.01)
    }

    func testSnappedOriginAlignsHorizontally() throws {
        let anchor = WinampWindowSnap.Box(frame: CGRect(x: 0, y: 100, width: 275, height: 116))
        let panel = WinampWindowSnap.Box(frame: CGRect(x: 288, y: 120, width: 275, height: 232))
        let snapped = WinampWindowSnap.snappedOrigin(
            box: panel,
            origin: NSPoint(x: 288, y: 120),
            against: anchor
        )
        XCTAssertNotNil(snapped)
        XCTAssertEqual(try XCTUnwrap(snapped?.x), 275, accuracy: 0.01)
    }

    func testTraceConnectedIncludesSnappedNeighbor() {
        let main = self.makeTestWindow(frame: CGRect(x: 50, y: 200, width: 275, height: 116))
        let eq = self.makeTestWindow(frame: CGRect(x: 50, y: 116, width: 275, height: 84))
        let connected = MainActor.assumeIsolated {
            WinampWindowSnap.traceConnected(from: main, among: [main, eq])
        }
        XCTAssertEqual(Set(connected.map(ObjectIdentifier.init)), Set([main, eq].map(ObjectIdentifier.init)))
    }

    private func makeTestWindow(frame: CGRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrame(frame, display: false)
        return window
    }
}
