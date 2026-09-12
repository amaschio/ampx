@testable import AmpX
import XCTest

final class AmpXBootstrapTests: XCTestCase {
    func testUsesNewUIDefaultsToClassic() {
        let name = "AmpXBootstrapTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertFalse(AmpXMain.usesNewUI(defaults: defaults))
        defaults.set(true, forKey: "AmpXNewUI")
        XCTAssertTrue(AmpXMain.usesNewUI(defaults: defaults))
    }

    func testUsesNewUIAcceptsLaunchArgumentStyleValues() {
        let name = "AmpXBootstrapTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set("YES", forKey: "AmpXNewUI")
        XCTAssertTrue(AmpXMain.usesNewUI(defaults: defaults))
    }

    @MainActor
    func testStackWindowSetsMinimumContentWidth() {
        let controller = AmpXStackWindowController(state: AmpXModuleOrder(), skin: ClassicModernSkin())
        XCTAssertEqual(controller.window?.contentMinSize.width, 416.5)
    }

    @MainActor
    func testStackWindowRejectsResizeBelowMinimumWidth() {
        let controller = AmpXStackWindowController(state: AmpXModuleOrder(), skin: ClassicModernSkin())
        guard let window = controller.window else {
            return XCTFail("Expected stack window")
        }

        let proposed = controller.clampedFrameSize(
            for: window,
            to: NSSize(width: 300, height: window.frame.height)
        )
        XCTAssertEqual(proposed.width, 416.5)
    }
}
