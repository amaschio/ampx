import AppKit

@MainActor
final class AmpXAppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private var hostCoordinator: AmpXHostCoordinator?

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isRunningUnderTest else { return }

        AmpXTypography.registerBundledFonts()
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")

        let layoutStore = AmpXLayoutStore(defaults: .standard)
        let saved = layoutStore.load()
        let coordinator = AmpXHostCoordinator(
            state: saved.state,
            skin: ClassicModernSkin(),
            layoutStore: layoutStore
        )
        self.hostCoordinator = coordinator
        coordinator.showStack()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            hostCoordinator?.showStack()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
