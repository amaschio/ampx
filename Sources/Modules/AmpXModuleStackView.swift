import AppKit

final class AmpXModuleStackView: NSView {
    private var moduleViews: [AmpXModuleID: AmpXModuleView] = [:]
    private var insertionMarkerView: NSView?

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

    func addModuleView(_ view: AmpXModuleView) {
        moduleViews[view.moduleID] = view
        if view.superview !== self {
            addSubview(view)
        }
    }

    func moduleView(for moduleID: AmpXModuleID) -> AmpXModuleView? {
        moduleViews[moduleID]
    }

    func setInsertionMarker(at contentY: CGFloat?, width: CGFloat) {
        guard let contentY else {
            insertionMarkerView?.isHidden = true
            return
        }

        if insertionMarkerView == nil {
            let marker = NSView(frame: .zero)
            marker.wantsLayer = true
            marker.layer?.backgroundColor = NSColor.systemYellow.cgColor
            addSubview(marker)
            insertionMarkerView = marker
        }

        insertionMarkerView?.isHidden = false
        insertionMarkerView?.frame = CGRect(
            x: 0,
            y: contentY - AmpXModuleDragController.insertionMarkerHeight / 2,
            width: width,
            height: AmpXModuleDragController.insertionMarkerHeight
        )
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
