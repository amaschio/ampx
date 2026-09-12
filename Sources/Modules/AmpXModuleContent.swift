import AppKit

/// Draws module body content within its bounds without host chrome or window coupling.
class AmpXModuleContent: AmpXDrawingView {
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
        case .playlist, .enthea:
            return AmpXModuleContent(skin: skin)
        }
    }
}
