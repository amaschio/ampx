import AppKit

final class AmpXModuleStackView: NSView {
    private var moduleViews: [AmpXModuleID: AmpXModuleView] = [:]

    override var isFlipped: Bool { true }

    func setModuleViews(_ views: [AmpXModuleID: AmpXModuleView]) {
        for view in moduleViews.values where !views.values.contains(view) {
            view.removeFromSuperview()
        }

        moduleViews = views
        for view in views.values where view.superview !== self {
            addSubview(view)
        }
    }

    func moduleView(for moduleID: AmpXModuleID) -> AmpXModuleView? {
        moduleViews[moduleID]
    }

    func applyLayout(
        _ result: AmpXLayoutResult,
        state: AmpXModuleOrder,
        playlistViewportHeight: CGFloat
    ) {
        let visibleModules = state.order.filter { moduleID in
            !state.closed.contains(moduleID) && !state.detached.contains(moduleID)
        }

        for moduleID in visibleModules {
            guard let frame = result.frames[moduleID],
                  let moduleView = moduleViews[moduleID]
            else { continue }
            moduleView.applyLayout(frame: frame)

            if moduleID == .playlist,
               let playlist = moduleView.content as? PlaylistModuleContent
            {
                playlist.setRowViewportHeight(playlistViewportHeight)
            }
        }
    }
}
