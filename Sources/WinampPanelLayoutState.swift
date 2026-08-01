import SwiftUI

/// Layout state shared between the main window and detachable EQ / playlist / visualizer panels.
@MainActor
final class WinampPanelLayoutState: ObservableObject {
    private static let playlistHeightKey = "playlistHeight"
    private static let playlistWidthKey = "playlistWidth"
    private static let showVisualizerKey = "showVisualizer"
    private static let visualizerWidthKey = "visualizerWidth"
    private static let visualizerHeightKey = "visualizerHeight"

    @Published var showEqualizer = true
    @Published var showPlaylist = true
    @Published var showVisualizer: Bool {
        didSet {
            UserDefaults.standard.set(self.showVisualizer, forKey: Self.showVisualizerKey)
        }
    }

    @Published var isShadeMode = false
    @Published var playlistMinimized = false
    @Published var equalizerMinimized = false
    @Published var visualizerMinimized = false
    @Published var playlistSize: CGSize {
        didSet {
            if oldValue.height != self.playlistSize.height {
                UserDefaults.standard.set(self.playlistSize.height, forKey: Self.playlistHeightKey)
            }
            if oldValue.width != self.playlistSize.width {
                UserDefaults.standard.set(self.playlistSize.width, forKey: Self.playlistWidthKey)
            }
        }
    }

    @Published var visualizerSize: CGSize {
        didSet {
            if oldValue.height != self.visualizerSize.height {
                UserDefaults.standard.set(self.visualizerSize.height, forKey: Self.visualizerHeightKey)
            }
            if oldValue.width != self.visualizerSize.width {
                UserDefaults.standard.set(self.visualizerSize.width, forKey: Self.visualizerWidthKey)
            }
        }
    }

    init() {
        let savedHeight = UserDefaults.standard.double(forKey: Self.playlistHeightKey)
        let height = savedHeight > 0 ? savedHeight : WinampMetrics.defaultPlaylistHeight
        let savedWidth = UserDefaults.standard.double(forKey: Self.playlistWidthKey)
        // Default to classic 275 px grid (not the legacy modern 450 px panel).
        let width = savedWidth > 0 ? savedWidth : ClassicSkinMetrics.windowWidth
        self.playlistSize = CGSize(width: width, height: height)

        self.showVisualizer = UserDefaults.standard.bool(forKey: Self.showVisualizerKey)

        let savedVizHeight = UserDefaults.standard.double(forKey: Self.visualizerHeightKey)
        let vizHeight = savedVizHeight > 0 ? savedVizHeight : WinampMetrics.defaultVisualizerHeight
        let savedVizWidth = UserDefaults.standard.double(forKey: Self.visualizerWidthKey)
        let vizWidth = savedVizWidth > 0 ? savedVizWidth : WinampMetrics.defaultVisualizerWidth
        self.visualizerSize = CGSize(width: vizWidth, height: vizHeight)
    }

    /// Ensure the playlist is at least as wide as its docking anchor (the main window). The user
    /// may drag it wider; a UI-scale change only grows it up to the new minimum and never shrinks a
    /// user-widened playlist.
    func ensureMinimumPlaylistWidth(_ minWidth: CGFloat) {
        guard self.playlistSize.width < minWidth else { return }
        self.playlistSize = CGSize(width: minWidth, height: self.playlistSize.height)
    }

    /// Scale persisted playlist dimensions when the UI zoom level changes so chrome + row metrics
    /// stay proportional (width/height are stored in points, not unscaled classic units).
    func scalePlaylistDimensions(by factor: CGFloat) {
        guard factor > 0, abs(factor - 1) > 0.001 else { return }
        self.playlistSize = CGSize(
            width: (self.playlistSize.width * factor).rounded(.toNearestOrAwayFromZero),
            height: (self.playlistSize.height * factor).rounded(.toNearestOrAwayFromZero)
        )
    }

    /// Scale persisted visualizer dimensions with UI zoom (same policy as playlist).
    func scaleVisualizerDimensions(by factor: CGFloat) {
        guard factor > 0, abs(factor - 1) > 0.001 else { return }
        self.visualizerSize = CGSize(
            width: (self.visualizerSize.width * factor).rounded(.toNearestOrAwayFromZero),
            height: (self.visualizerSize.height * factor).rounded(.toNearestOrAwayFromZero)
        )
    }

    /// Clamp a previously persisted (or modern-UI) width down to the active style's grid on first
    /// Classic launch / style switch, without fighting a user who already resized wider.
    func alignPlaylistWidthToStyle(baseWidth: CGFloat, allowShrinkFromLegacyDefault: Bool) {
        if allowShrinkFromLegacyDefault, abs(self.playlistSize.width - WinampUIScale.basePanelWidth) < 0.5 {
            self.playlistSize = CGSize(width: baseWidth, height: self.playlistSize.height)
            return
        }
        self.ensureMinimumPlaylistWidth(baseWidth)
    }

    var isEqualizerDocked: Bool {
        // EQ stays available while the main window is shaded (classic Winamp behavior).
        self.showEqualizer
    }

    var playlistSizeBinding: Binding<CGSize> {
        Binding(
            get: { self.playlistSize },
            set: { self.playlistSize = $0 }
        )
    }

    var playlistMinimizedBinding: Binding<Bool> {
        Binding(
            get: { self.playlistMinimized },
            set: { self.playlistMinimized = $0 }
        )
    }

    var visualizerSizeBinding: Binding<CGSize> {
        Binding(
            get: { self.visualizerSize },
            set: { self.visualizerSize = $0 }
        )
    }

    var visualizerMinimizedBinding: Binding<Bool> {
        Binding(
            get: { self.visualizerMinimized },
            set: { self.visualizerMinimized = $0 }
        )
    }
}
