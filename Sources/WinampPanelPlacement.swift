import CoreGraphics

/// Pure initial-origin rules for managed panels (no AppKit). Used by the window manager and unit tests.
enum WinampPanelPlacement {
    /// Origin for a panel with no persisted offset.
    ///
    /// - Visualizer: flush to the right of `mainFrame`, top-aligned.
    /// - Others: stack below `stackBelowOrigin` (or below main if nil).
    static func initialOrigin(
        panelID: WinampPanelID,
        panelSize: CGSize,
        mainFrame: CGRect,
        stackBelowOrigin: CGPoint?
    ) -> CGPoint {
        if panelID == .visualizer {
            return CGPoint(
                x: mainFrame.maxX,
                y: mainFrame.maxY - panelSize.height
            )
        }
        if let below = stackBelowOrigin {
            return CGPoint(x: below.x, y: below.y - panelSize.height)
        }
        return CGPoint(x: mainFrame.minX, y: mainFrame.minY - panelSize.height)
    }
}
