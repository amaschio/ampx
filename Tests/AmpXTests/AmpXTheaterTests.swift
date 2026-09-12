@testable import AmpX
import XCTest

@MainActor
final class AmpXTheaterTests: XCTestCase {
    func testTheaterPreservesHostIdentityAndPresentation() throws {
        let hosts = AmpXHostCoordinator(state: AmpXModuleOrder(), skin: ClassicModernSkin())
        hosts.reopenModule(.enthea)
        let view = try XCTUnwrap(hosts.moduleView(for: .enthea))
        let identity = ObjectIdentifier(view.content)
        let previousFrame = view.frame
        var presentation: NSApplication.PresentationOptions = []
        let controller = AmpXTheaterController(
            hosts: hosts,
            screenFrame: { CGRect(x: 0, y: 0, width: 1200, height: 800) },
            getPresentation: { presentation },
            setPresentation: { presentation = $0 }
        )
        controller.enter()
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(view.content.bounds.size, CGSize(width: 1200, height: 800))
        XCTAssertTrue(presentation.contains(.autoHideDock))
        controller.exit()
        XCTAssertEqual(ObjectIdentifier(view.content), identity)
        XCTAssertEqual(view.frame, previousFrame)
        XCTAssertEqual(presentation, [])
    }

    func testTheaterPreservesDetachedHostIdentityAndWindowFrame() throws {
        let hosts = AmpXHostCoordinator(state: AmpXModuleOrder(), skin: ClassicModernSkin())
        hosts.reopenModule(.enthea)
        hosts.showStack()
        hosts.detach(.enthea, at: CGPoint(x: 400, y: 500), inheritedWidth: 490)

        let view = try XCTUnwrap(hosts.moduleView(for: .enthea))
        let identity = ObjectIdentifier(view.content)
        let previousWindowFrame = try XCTUnwrap(hosts.detachedWindowFrame(for: .enthea))

        var presentation: NSApplication.PresentationOptions = []
        let controller = AmpXTheaterController(
            hosts: hosts,
            screenFrame: { CGRect(x: 0, y: 0, width: 1200, height: 800) },
            getPresentation: { presentation },
            setPresentation: { presentation = $0 }
        )

        controller.enter()
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(view.content.bounds.size, CGSize(width: 1200, height: 800))

        controller.exit()
        XCTAssertEqual(ObjectIdentifier(view.content), identity)

        let restoredWindowFrame = try XCTUnwrap(hosts.detachedWindowFrame(for: .enthea))
        let clampedPrevious = AmpXLayoutStore.clampedToVisibleFrame(
            previousWindowFrame,
            screen: NSScreen.main!
        )
        XCTAssertEqual(restoredWindowFrame.origin.x, clampedPrevious.origin.x, accuracy: 1)
        XCTAssertEqual(restoredWindowFrame.origin.y, clampedPrevious.origin.y, accuracy: 1)
        XCTAssertEqual(restoredWindowFrame.width, clampedPrevious.width, accuracy: 1)
        XCTAssertEqual(restoredWindowFrame.height, clampedPrevious.height, accuracy: 1)
        XCTAssertEqual(presentation, [])
    }
}
