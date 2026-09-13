import CoreGraphics

struct AmpXLayoutResult: Equatable {
    var scale: CGFloat
    var frames: [AmpXModuleID: CGRect]
    var contentHeight: CGFloat
    var viewportHeight: CGFloat
    var playlistViewportHeight: CGFloat
    var scrolls: Bool
}

enum AmpXLayout {
    static func scale(width: CGFloat) -> CGFloat {
        let raw = width / AmpXMetrics.compositionWidth
        return min(1.35, max(0.85, raw))
    }

    static func adjustedPlaylistViewportHeight(
        preferred: CGFloat,
        heightDelta: CGFloat,
        scale: CGFloat
    ) -> CGFloat {
        guard scale > 0 else { return preferred }
        let adjusted = preferred + heightDelta / scale
        return max(AmpXMetrics.minimumPlaylistViewportHeight, adjusted)
    }

    static func calculate(
        state: AmpXModuleOrder,
        width: CGFloat,
        playlistViewportHeight: CGFloat,
        availableHeight: CGFloat
    ) -> AmpXLayoutResult {
        let layoutScale = self.scale(width: width)
        let compositionWidth = AmpXMetrics.compositionWidth * layoutScale
        let originX = max(0, (width - compositionWidth) / 2)
        let visibleModules = self.stackModules(in: state)

        var effectivePlaylistViewport = playlistViewportHeight
        var contentHeight = self.totalContentHeight(
            state: state,
            modules: visibleModules,
            scale: layoutScale,
            playlistViewportHeight: effectivePlaylistViewport
        )

        if contentHeight > availableHeight,
           self.shouldShrinkPlaylist(state: state, modules: visibleModules)
        {
            effectivePlaylistViewport = AmpXMetrics.minimumPlaylistViewportHeight
            contentHeight = self.totalContentHeight(
                state: state,
                modules: visibleModules,
                scale: layoutScale,
                playlistViewportHeight: effectivePlaylistViewport
            )
        }

        let scrolls = contentHeight > availableHeight
        let viewportHeight = scrolls ? availableHeight : contentHeight
        let frames = self.layoutFrames(
            modules: visibleModules,
            state: state,
            originX: originX,
            compositionWidth: compositionWidth,
            scale: layoutScale,
            playlistViewportHeight: effectivePlaylistViewport
        )

        return AmpXLayoutResult(
            scale: layoutScale,
            frames: frames,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight,
            playlistViewportHeight: effectivePlaylistViewport,
            scrolls: scrolls
        )
    }

    private static func stackModules(in state: AmpXModuleOrder) -> [AmpXModuleID] {
        state.order.filter { moduleID in
            !state.closed.contains(moduleID) && !state.detached.contains(moduleID)
        }
    }

    private static func shouldShrinkPlaylist(
        state: AmpXModuleOrder,
        modules: [AmpXModuleID]
    ) -> Bool {
        modules.contains(.playlist)
            && !state.collapsed.contains(.playlist)
    }

    private static func moduleHeight(
        moduleID: AmpXModuleID,
        state: AmpXModuleOrder,
        playlistViewportHeight: CGFloat
    ) -> CGFloat {
        if state.collapsed.contains(moduleID) {
            return AmpXMetrics.headerHeight
        }

        switch moduleID {
        case .player:
            return AmpXMetrics.playerHeight
        case .equalizer:
            return AmpXMetrics.equalizerHeight
        case .playlist:
            return AmpXMetrics.headerHeight
                + AmpXMetrics.playlistNonRowChrome
                + playlistViewportHeight
        case .enthea:
            return AmpXMetrics.entheaHeight
        }
    }

    private static func totalContentHeight(
        state: AmpXModuleOrder,
        modules: [AmpXModuleID],
        scale: CGFloat,
        playlistViewportHeight: CGFloat
    ) -> CGFloat {
        guard !modules.isEmpty else { return 0 }

        var total: CGFloat = 0
        for (index, moduleID) in modules.enumerated() {
            total += self.moduleHeight(
                moduleID: moduleID,
                state: state,
                playlistViewportHeight: playlistViewportHeight
            )
            if index < modules.count - 1 {
                total += AmpXMetrics.moduleGap
            }
        }
        return total * scale
    }

    private static func layoutFrames(
        modules: [AmpXModuleID],
        state: AmpXModuleOrder,
        originX: CGFloat,
        compositionWidth: CGFloat,
        scale: CGFloat,
        playlistViewportHeight: CGFloat
    ) -> [AmpXModuleID: CGRect] {
        var frames: [AmpXModuleID: CGRect] = [:]
        var y: CGFloat = 0

        for (index, moduleID) in modules.enumerated() {
            let height = self.moduleHeight(
                moduleID: moduleID,
                state: state,
                playlistViewportHeight: playlistViewportHeight
            ) * scale
            frames[moduleID] = CGRect(x: originX, y: y, width: compositionWidth, height: height)

            y += height
            if index < modules.count - 1 {
                y += AmpXMetrics.moduleGap * scale
            }
        }

        return frames
    }
}
