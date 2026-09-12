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
}
