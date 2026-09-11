import AppKit

/// Borderless panel window that can still take keyboard focus (playlist search,
/// keyboard navigation). Plain borderless `NSWindow`s refuse key/main status.
final class AmpXPanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

/// Shared borderless window chrome for main and panel windows.
@MainActor
enum AmpXWindowConfigurator {
    static func apply(to window: NSWindow, resizable: Bool = true) {
        // Borderless (no `.titled`) so the window has square corners and no native
        // titlebar strip, like the classic Winamp skin. A plain borderless window
        // only accepts key status with `.resizable` set (or a `canBecomeKey`
        // override, as `AmpXPanelWindow` provides for the panels).
        var styleMask: NSWindow.StyleMask = [.borderless, .miniaturizable]
        if resizable {
            styleMask.insert(.resizable)
        }
        window.styleMask = styleMask

        window.collectionBehavior = []
        window.toolbar = nil

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.backgroundColor = AmpXColors.nsTitleBar
        window.isOpaque = true
        window.hasShadow = true
        window.isMovableByWindowBackground = false
    }
}
