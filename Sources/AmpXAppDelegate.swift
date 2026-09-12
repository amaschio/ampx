import AppKit

@MainActor
final class AmpXAppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private var applicationController: AmpXApplicationController?
    private var keyboardEventMonitor: Any?

    func applicationDidFinishLaunching(_: Notification) {
        guard !Self.isRunningUnderTest else { return }

        AmpXTypography.registerBundledFonts()
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")

        let audioPlayer = AudioPlayer.shared
        let playlistManager = PlaylistManager.shared
        let layoutStore = AmpXLayoutStore(defaults: .standard)
        let saved = layoutStore.load()
        let hosts = AmpXHostCoordinator(
            state: saved.state,
            skin: ClassicModernSkin(),
            layoutStore: layoutStore,
            audioPlayer: audioPlayer,
            playlistManager: playlistManager
        )
        let application = AmpXApplicationController(
            audioPlayer: audioPlayer,
            playlistManager: playlistManager,
            hosts: hosts
        )
        self.applicationController = application

        NSApp.mainMenu = AmpXMenuBuilder.makeMainMenu(application: application)
        installKeyboardShortcuts()
        application.start()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            applicationController?.hosts.showStack()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        applicationController?.terminate()
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installKeyboardShortcuts() {
        keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let application = self.applicationController else { return event }
            return AmpXKeyRouter.handle(
                event,
                window: NSApp.keyWindow,
                audioPlayer: application.audioPlayer,
                playlistManager: application.playlistManager,
                entheaTheater: application.hosts,
                moduleCommandHandler: { command in
                    application.hosts.performModuleCommand(command)
                }
            )
        }
    }
}
