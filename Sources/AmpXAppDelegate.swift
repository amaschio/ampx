import AppKit

@MainActor
final class AmpXAppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private var hostCoordinator: AmpXHostCoordinator?
    private var keyboardEventMonitor: Any?
    private let audioPlayer = AudioPlayer.shared
    private let playlistManager = PlaylistManager.shared

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
        installWindowMenu(coordinator: coordinator)
        installKeyboardShortcuts()
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

    func applicationWillTerminate(_: Notification) {
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installKeyboardShortcuts() {
        keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return AmpXKeyRouter.handle(
                event,
                window: NSApp.keyWindow,
                audioPlayer: self.audioPlayer,
                playlistManager: self.playlistManager,
                entheaTheater: self.hostCoordinator,
                moduleCommandHandler: { [weak self] command in
                    self?.hostCoordinator?.performModuleCommand(command)
                }
            )
        }
    }

    private func installWindowMenu(coordinator: AmpXHostCoordinator) {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let windowMenu = NSMenu(title: "Window")

        let moveUp = NSMenuItem(
            title: "Move Module Up",
            action: #selector(moveModuleUp(_:)),
            keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!)
        )
        moveUp.keyEquivalentModifierMask = [.command, .option]
        moveUp.target = self
        windowMenu.addItem(moveUp)

        let moveDown = NSMenuItem(
            title: "Move Module Down",
            action: #selector(moveModuleDown(_:)),
            keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!)
        )
        moveDown.keyEquivalentModifierMask = [.command, .option]
        moveDown.target = self
        windowMenu.addItem(moveDown)

        let detach = NSMenuItem(title: "Detach/Re-dock Module", action: #selector(toggleDetachModule(_:)), keyEquivalent: "d")
        detach.keyEquivalentModifierMask = [.command, .option]
        detach.target = self
        windowMenu.addItem(detach)

        let collapse = NSMenuItem(title: "Collapse/Expand Module", action: #selector(toggleCollapseModule(_:)), keyEquivalent: "c")
        collapse.keyEquivalentModifierMask = [.command, .option]
        collapse.target = self
        windowMenu.addItem(collapse)

        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu

        if let existingIndex = mainMenu.items.firstIndex(where: { $0.title == "Window" }) {
            mainMenu.removeItem(at: existingIndex)
        }
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu

        withExtendedLifetime(coordinator) {}
    }

    @objc private func moveModuleUp(_: Any?) {
        hostCoordinator?.performModuleCommand(.moveUp)
    }

    @objc private func moveModuleDown(_: Any?) {
        hostCoordinator?.performModuleCommand(.moveDown)
    }

    @objc private func toggleDetachModule(_: Any?) {
        hostCoordinator?.performModuleCommand(.toggleDetach)
    }

    @objc private func toggleCollapseModule(_: Any?) {
        hostCoordinator?.performModuleCommand(.toggleCollapse)
    }
}
