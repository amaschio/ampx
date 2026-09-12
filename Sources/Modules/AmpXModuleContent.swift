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

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        skin.inset(bounds, in: context, backingScale: backingScale)
    }

    static func make(moduleID: AmpXModuleID, skin: any AmpXSkin) -> AmpXModuleContent {
        switch moduleID {
        case .player:
            return PlayerModuleContent(skin: skin)
        case .equalizer:
            return EqualizerModuleContent(skin: skin)
        case .playlist:
            return PlaylistModuleContent(skin: skin)
        case .enthea:
            return AmpXModuleContent(skin: skin)
        }
    }
}
