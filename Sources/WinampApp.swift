import AppKit
import SwiftUI

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @StateObject private var uiScale = WinampUIScale.shared
    @StateObject private var panelLayout = WinampPanelLayoutState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        WinampTypography.registerBundledFonts()
        // Fixed-size Classic chrome — hide the system "Enter Full Screen" View item.
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.audioPlayer)
                .environmentObject(self.audioPlayer.playbackClock)
                .environmentObject(self.playlistManager)
                .environmentObject(self.uiScale)
                .environmentObject(self.panelLayout)
                .preferredColorScheme(.dark)
                .background(Color.clear)
                .onAppear {
                    self.appDelegate.bind(
                        audioPlayer: self.audioPlayer,
                        playlistManager: self.playlistManager
                    )
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 275, height: 116)
        .commands {
            WinampCommands(
                audioPlayer: self.audioPlayer,
                playlistManager: self.playlistManager,
                uiScale: self.uiScale,
                panelLayout: self.panelLayout
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private weak var audioPlayer: AudioPlayer?
    private weak var playlistManager: PlaylistManager?
    private var keyboardEventMonitor: Any?

    func bind(audioPlayer: AudioPlayer, playlistManager: PlaylistManager) {
        self.audioPlayer = audioPlayer
        self.playlistManager = playlistManager
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Window chrome is applied in ContentView.setupWindow().
        guard !Self.isRunningUnderTest else { return }
        self.installKeyboardShortcuts()
    }

    private func installKeyboardShortcuts() {
        self.keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            WinampHotkeys.handle(
                event,
                audioPlayer: self?.audioPlayer,
                playlistManager: self?.playlistManager
            )
        }
    }

    func applicationWillTerminate(_: Notification) {
        if let monitor = self.keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
