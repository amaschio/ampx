import CoreGraphics
import Foundation

/// Pure vertical-column packing rules for the Classic main→EQ→playlist stack.
///
/// Extracted from `WinampPanelWindowManager` so membership and width policy can be
/// unit-tested without AppKit window orchestration.
enum WinampPanelColumnPack {
    /// Whether `panelID` should be repositioned by `packMainVerticalColumn`.
    ///
    /// The MilkDrop visualizer is never packed into the main column (it keeps its own
    /// width and typically docks beside main). Horizontally docked panels are skipped
    /// unless explicitly `forcing`.
    static func shouldIncludeInVerticalPack(
        panelID: WinampPanelID,
        forcing: WinampPanelID?,
        sameColumn: Bool,
        sideOfMain: Bool
    ) -> Bool {
        if panelID == .visualizer {
            return false
        }
        let force = panelID == forcing
        if sideOfMain, !sameColumn, !force {
            return false
        }
        if !force, !sameColumn {
            return false
        }
        return true
    }

    /// Width assigned when packing into the main column. Playlist may stay wider than
    /// main; EQ (and any other classic-width panel) locks to `mainWidth`.
    static func packedWidth(
        panelID: WinampPanelID,
        currentWidth: CGFloat,
        mainWidth: CGFloat
    ) -> CGFloat {
        panelID == .playlist ? currentWidth : mainWidth
    }
}
