import AppKit

/// Draws module body content within its bounds without host chrome or window coupling.
class AmpXModuleContent: AmpXDrawingView {
    func focusableControls() -> [NSView] {
        subviews
            .filter { view in
                (view is AmpXButton || view is AmpXSlider || view is AmpXScrollbar) && view.acceptsFirstResponder
            }
            .sorted { lhs, rhs in
                if abs(lhs.frame.minY - rhs.frame.minY) > 0.5 {
                    return lhs.frame.minY < rhs.frame.minY
                }
                return lhs.frame.minX < rhs.frame.minX
            }
    }

    func setEffectivelyVisible(_ visible: Bool) {
        for case let continuous as AmpXContinuousView in subviews {
            continuous.setEffectivelyVisible(visible)
        }
    }

    static func make(moduleID: AmpXModuleID, skin: any AmpXSkin) -> AmpXModuleContent {
        switch moduleID {
        case .player:
            preconditionFailure("Player module content must be constructed by AmpXHostCoordinator")
        case .equalizer:
            preconditionFailure("Equalizer module content must be constructed by AmpXHostCoordinator")
        case .playlist:
            preconditionFailure("Playlist module content must be constructed by AmpXHostCoordinator")
        case .enthea:
            preconditionFailure("Enthea module content must be constructed by AmpXHostCoordinator")
        }
    }
}
