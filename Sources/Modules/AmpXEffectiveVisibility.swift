import AppKit

struct AmpXVisibilityInputs {
    var collapsed: Bool
    var closed: Bool
    var windowVisible: Bool
    var miniaturized: Bool
    var occluded: Bool
    var intersectsViewport: Bool

    var isVisible: Bool {
        !collapsed && !closed && windowVisible && !miniaturized && !occluded && intersectsViewport
    }
}

enum AmpXEffectiveVisibility {
    static func stackInputs(
        collapsed: Bool,
        closed: Bool,
        window: NSWindow?,
        moduleFrame: CGRect,
        visibleContentRect: CGRect
    ) -> AmpXVisibilityInputs {
        let windowInputs = windowState(from: window)
        return AmpXVisibilityInputs(
            collapsed: collapsed,
            closed: closed,
            windowVisible: windowInputs.isVisible,
            miniaturized: windowInputs.isMiniaturized,
            occluded: windowInputs.isOccluded,
            intersectsViewport: moduleFrame.intersects(visibleContentRect)
        )
    }

    static func detachedInputs(
        collapsed: Bool,
        closed: Bool,
        window: NSWindow?
    ) -> AmpXVisibilityInputs {
        let windowInputs = windowState(from: window)
        return AmpXVisibilityInputs(
            collapsed: collapsed,
            closed: closed,
            windowVisible: windowInputs.isVisible,
            miniaturized: windowInputs.isMiniaturized,
            occluded: windowInputs.isOccluded,
            intersectsViewport: true
        )
    }

    static func theaterInputs(
        collapsed: Bool,
        closed: Bool,
        window: NSWindow?
    ) -> AmpXVisibilityInputs {
        detachedInputs(collapsed: collapsed, closed: closed, window: window)
    }

    private static func windowState(from window: NSWindow?) -> (isVisible: Bool, isMiniaturized: Bool, isOccluded: Bool) {
        guard let window else {
            return (false, false, true)
        }
        return (
            window.isVisible,
            window.isMiniaturized,
            !window.occlusionState.contains(.visible)
        )
    }
}
