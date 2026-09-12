import AppKit
import SwiftUI

struct ContentView: View {
    private static var positionedWindows = Set<ObjectIdentifier>()
    /// The SwiftUI `WindowGroup` player window — never restyle About / open panels as AmpX chrome.
    private static var configuredMainWindowID: ObjectIdentifier?

    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var uiScale: AmpXUIScale
    @EnvironmentObject var panelLayout: AmpXPanelLayoutState
    @State private var lastAppliedUIScale: CGFloat = 0
    @AppStorage("showRemainingTime") private var showRemainingTime = false

    private var showVisualizerBinding: Binding<Bool> {
        Binding(
            get: { self.panelLayout.showVisualizer },
            set: { self.panelLayout.showVisualizer = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if self.panelLayout.isShadeMode {
                ClassicShadeView(
                    isShadeMode: self.$panelLayout.isShadeMode,
                    showRemainingTime: self.$showRemainingTime,
                    showVisualization: self.showVisualizerBinding
                )
            } else {
                ClassicMainPlayerView(
                    showPlaylist: self.$panelLayout.showPlaylist,
                    showEqualizer: self.$panelLayout.showEqualizer,
                    isShadeMode: self.$panelLayout.isShadeMode,
                    shuffleEnabled: Binding(
                        get: { self.playlistManager.shuffleEnabled },
                        set: { self.playlistManager.shuffleEnabled = $0 }
                    ),
                    repeatEnabled: Binding(
                        get: { self.playlistManager.repeatEnabled },
                        set: { self.playlistManager.repeatEnabled = $0 }
                    ),
                    showRemainingTime: self.$showRemainingTime,
                    showVisualization: self.showVisualizerBinding
                )
            }
        }
        .frame(width: self.styledPanelWidth)
        .environment(\.winampUIScale, self.uiScale.scale)
        .fixedSize()
        .ignoresSafeArea(.all)
        .onAppear {
            self.setupWindow()
            self.lastAppliedUIScale = self.uiScale.scale
            self.panelLayout.alignPlaylistWidthToStyle(
                baseWidth: self.styledPanelWidth,
                allowShrinkFromLegacyDefault: true
            )
            self.syncPanelWindows()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow else { return }
            guard self.shouldConfigureAsMainPlayerWindow(window) else { return }
            self.configureWindow(window)
        }
        .onChange(of: self.uiScale.level) { _ in
            let newScale = self.uiScale.scale
            let oldScale = self.lastAppliedUIScale > 0 ? self.lastAppliedUIScale : newScale
            if abs(oldScale - newScale) > 0.001 {
                let factor = newScale / oldScale
                self.panelLayout.scalePlaylistDimensions(by: factor)
                self.panelLayout.scaleVisualizerDimensions(by: factor)
            }
            self.lastAppliedUIScale = newScale
            self.panelLayout.ensureMinimumPlaylistWidth(self.styledPanelWidth)
            // Panels live in separate hosting controllers — resize + re-pack after Zoom.
            AmpXPanelWindowManager.shared.applyUIScale()
            self.syncPanelWindows()
        }
        .onChange(of: self.panelLayout.isShadeMode) { newValue in
            self.applyShadeMode(newValue)
            AmpXPanelWindowManager.shared.fitMainWindowToContent()
            self.syncPanelWindows()
        }
        .onChange(of: self.panelLayout.showEqualizer) { _ in
            self.syncPanelWindows()
        }
        .onChange(of: self.panelLayout.showPlaylist) { _ in
            self.syncPanelWindows()
        }
        .onChange(of: self.panelLayout.showVisualizer) { _ in
            self.syncPanelWindows()
        }
        .onChange(of: self.panelLayout.playlistSize) { _ in
            AmpXPanelWindowManager.shared.resizePlaylistPanel()
        }
        .onChange(of: self.panelLayout.playlistMinimized) { _ in
            AmpXPanelWindowManager.shared.resizePlaylistPanel()
        }
        .onChange(of: self.panelLayout.equalizerMinimized) { _ in
            AmpXPanelWindowManager.shared.resizeEqualizerPanel()
        }
        .onChange(of: self.panelLayout.visualizerSize) { _ in
            AmpXPanelWindowManager.shared.resizeVisualizerPanel()
        }
        .onChange(of: self.panelLayout.visualizerMinimized) { _ in
            AmpXPanelWindowManager.shared.resizeVisualizerPanel()
        }
    }

    private var styledPanelWidth: CGFloat {
        ClassicSkinMetrics.scaled(ClassicSkinMetrics.windowWidth, by: self.uiScale.scale)
    }

    private func applyShadeMode(_: Bool) {
        // Classic windowshade only changes content height — keep a normal window level so the
        // strip stays in the standard layer (floating made it look detached / hard to target).
        guard let window = self.mainPlayerWindow() else { return }
        window.level = .normal
        window.collectionBehavior = []
    }

    private func mainPlayerWindow() -> NSWindow? {
        if let id = Self.configuredMainWindowID,
           let window = NSApplication.shared.windows.first(where: { ObjectIdentifier($0) == id })
        {
            return window
        }
        return NSApplication.shared.windows.first { window in
            self.shouldConfigureAsMainPlayerWindow(window) && window.isVisible
        }
    }

    /// Only the SwiftUI `WindowGroup` player may receive AmpX borderless chrome. System About /
    /// open panels are `NSPanel`s (or other titled windows) and must keep their native close button.
    private func shouldConfigureAsMainPlayerWindow(_ window: NSWindow) -> Bool {
        if AmpXPanelWindowManager.shared.isPanelWindow(window) {
            return false
        }
        if window is NSPanel {
            return false
        }
        if let known = Self.configuredMainWindowID {
            return ObjectIdentifier(window) == known
        }
        return true
    }

    private func syncPanelWindows() {
        guard let window = self.mainPlayerWindow() else { return }

        AmpXPanelWindowManager.shared.configure(
            mainWindow: window,
            layoutState: self.panelLayout,
            audioPlayer: self.audioPlayer,
            playlistManager: self.playlistManager,
            uiScale: self.uiScale
        )
    }

    private func setupWindow() {
        Task { @MainActor in
            if let window = self.mainPlayerWindow() {
                self.configureWindow(window)
            }
            self.syncPanelWindows()
        }
    }

    private func configureWindow(_ window: NSWindow) {
        guard self.shouldConfigureAsMainPlayerWindow(window) else { return }

        // `.resizable` keeps the borderless SwiftUI window able to become key; actual
        // resizing stays locked by `.windowResizability(.contentSize)`.
        AmpXWindowConfigurator.apply(to: window, resizable: true)
        Self.configuredMainWindowID = ObjectIdentifier(window)

        let windowID = ObjectIdentifier(window)
        guard !Self.positionedWindows.contains(windowID) else { return }
        Self.positionedWindows.insert(windowID)

        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame

            let x = screenFrame.midX - (windowFrame.width / 2)
            let y = screenFrame.maxY - windowFrame.height - 20

            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
