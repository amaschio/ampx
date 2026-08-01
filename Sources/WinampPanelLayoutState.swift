import SwiftUI

/// Layout state shared between the main window and detachable EQ / playlist panels.
@MainActor
final class WinampPanelLayoutState: ObservableObject {
    private static let playlistHeightKey = "playlistHeight"
    private static let playlistWidthKey = "playlistWidth"

    @Published var showEqualizer = true
    @Published var showPlaylist = true
    @Published var isShadeMode = false
    @Published var playlistMinimized = false
    @Published var equalizerMinimized = false
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

    init() {
        let savedHeight = UserDefaults.standard.double(forKey: Self.playlistHeightKey)
        let height = savedHeight > 0 ? savedHeight : WinampMetrics.defaultPlaylistHeight
        let savedWidth = UserDefaults.standard.double(forKey: Self.playlistWidthKey)
        // Default to classic 275 px grid (not the legacy modern 450 px panel).
        let width = savedWidth > 0 ? savedWidth : ClassicSkinMetrics.windowWidth
        self.playlistSize = CGSize(width: width, height: height)
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
}
