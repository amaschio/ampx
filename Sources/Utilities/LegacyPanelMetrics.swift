import CoreGraphics

/// Shared layout constants. Prefer `ClassicSkinMetrics` for Classic chrome geometry (275 px grid).
///
/// `panelWidth` / `mainPlayerHeight` are legacy modern-UI defaults retained only as
/// fallbacks for playlist/visualizer sizing migration — do not use them for new Classic UI.
enum LegacyPanelMetrics {
    /// Legacy modern panel width; Classic chrome uses `ClassicSkinMetrics.windowWidth` (275).
    static let panelWidth: CGFloat = 450
    /// Legacy modern main height; Classic uses shade/main sprite metrics instead.
    static let mainPlayerHeight: CGFloat = 163
    static let titleBarHeight: CGFloat = 22
    static let defaultPlaylistHeight: CGFloat = 250
    static let defaultVisualizerWidth: CGFloat = 600
    static let defaultVisualizerHeight: CGFloat = 450
    static let visualizerMinHeight: CGFloat = 200
    static let playlistRowHeight: CGFloat = 19
    static let playlistSearchHeight: CGFloat = 22
    static let transportButtonHeight: CGFloat = 14
    static let smallButtonHeight: CGFloat = 11
}
