import AppKit
import SwiftUI

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @StateObject private var uiScale = WinampUIScale.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        WinampTypography.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.audioPlayer)
                .environmentObject(self.audioPlayer.playbackClock)
                .environmentObject(self.playlistManager)
                .environmentObject(self.uiScale)
                .preferredColorScheme(.dark)
                .background(Color.clear)
                .onAppear {
                    self.appDelegate.bind(audioPlayer: self.audioPlayer)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 275, height: 116)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play/Pause") { self.audioPlayer.togglePlayPause() }
                    .keyboardShortcut("x", modifiers: [])
                Button("Stop") { self.audioPlayer.stop() }
                    .keyboardShortcut("v", modifiers: [])
                Button("Previous Track") { self.playlistManager.previous() }
                    .keyboardShortcut("z", modifiers: [])
                Button("Next Track") { self.playlistManager.next() }
                    .keyboardShortcut("b", modifiers: [])
            }
            CommandMenu("File") {
                Button("Add Files...") { self.playlistManager.showFilePicker() }
                    .keyboardShortcut("l", modifiers: [.command])
                Button("Add Folder...") { self.playlistManager.showFolderPicker() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandMenu("Zoom") {
                ForEach(WinampUIScaleLevel.allCases) { level in
                    Button(level.label) {
                        self.uiScale.setLevel(level)
                    }
                    .disabled(self.uiScale.level == level)
                }
            }
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
    private var keyboardEventMonitor: Any?

    func bind(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Window chrome is applied in ContentView.setupWindow().
        guard !Self.isRunningUnderTest else { return }
        self.installKeyboardShortcuts()
    }

    private func installKeyboardShortcuts() {
        self.keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let window = NSApp.keyWindow, window.isKeyWindow else { return event }

            let noModifiers = event.modifierFlags.intersection([.command, .option, .control]).isEmpty
            if noModifiers, WinampPanelWindowManager.shared.isVisualizerWindow(window) {
                // F — toggle theater; Escape — exit theater only.
                if event.keyCode == 3 {
                    WinampPanelWindowManager.shared.toggleVisualizerTheater()
                    return nil
                }
                if event.keyCode == 53, WinampPanelWindowManager.shared.isVisualizerInTheater {
                    WinampPanelWindowManager.shared.exitVisualizerTheater()
                    return nil
                }
            }

            if noModifiers, WinampPlaylistKeyboard.isActive,
               WinampPanelWindowManager.shared.isPlaylistWindow(window)
            {
                switch event.keyCode {
                case 126: // up arrow
                    WinampPlaylistKeyboard.moveSelection(by: -1)
                    return nil
                case 125: // down arrow
                    WinampPlaylistKeyboard.moveSelection(by: 1)
                    return nil
                case 36: // return
                    WinampPlaylistKeyboard.playSelectedTrack()
                    return nil
                default:
                    break
                }
            }

            guard event.keyCode == 49,
                  event.modifierFlags.intersection([.command, .option, .control]).isEmpty
            else {
                return event
            }

            // Space bar play/pause — ignore when typing in a text field.
            if let firstResponder = window.firstResponder,
               firstResponder is NSTextView || firstResponder is NSTextField
            {
                return event
            }

            self?.audioPlayer?.togglePlayPause()
            return nil
        }
    }

    func applicationWillTerminate(_: Notification) {
        if let monitor = self.keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
