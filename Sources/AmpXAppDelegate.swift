import AppKit

@MainActor
final class AmpXAppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private var stackWindowController: AmpXStackWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isRunningUnderTest else { return }

        AmpXTypography.registerBundledFonts()
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")

        let state = AmpXModuleOrder()
        let skin = ClassicModernSkin()
        let controller = AmpXStackWindowController(state: state, skin: skin)
        self.stackWindowController = controller
        controller.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
