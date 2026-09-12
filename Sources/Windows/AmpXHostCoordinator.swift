import AppKit

@MainActor
final class AmpXHostCoordinator {
    private(set) var state: AmpXModuleOrder
    private let skin: any AmpXSkin
    private let layoutStore: AmpXLayoutStore
    private let screen: NSScreen

    private(set) var stackWindowController: AmpXStackWindowController?
    private var moduleViews: [AmpXModuleID: AmpXModuleView] = [:]
    private var detachedWindowControllers: [AmpXModuleID: AmpXDetachedModuleWindowController] = [:]
    private var stackFrame: CGRect
    private var detachedFrames: [AmpXModuleID: CGRect]
    private var playlistViewportHeight: CGFloat

    private(set) var dragController = AmpXModuleDragSession()

    private(set) var isStackVisible = false

    var stackWindow: NSWindow? {
        stackWindowController?.window
    }

    var stackWindowFrame: CGRect? {
        stackWindow?.frame
    }

    init(
        state: AmpXModuleOrder,
        skin: any AmpXSkin,
        layoutStore: AmpXLayoutStore? = nil,
        screen: NSScreen? = nil
    ) {
        let resolvedScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        self.state = state
        self.skin = skin
        self.screen = resolvedScreen
        self.layoutStore = layoutStore ?? AmpXLayoutStore(defaults: .standard, screen: resolvedScreen)

        let saved = self.layoutStore.load(screen: resolvedScreen)
        self.stackFrame = saved.stackFrame
        self.detachedFrames = saved.detachedFrames
        self.playlistViewportHeight = saved.playlistViewportHeight

        self.createModuleViews()
        self.dragController.bind(coordinator: self)
        self.restoreDetachedModules()
    }

    func showStack() {
        if stackWindowController == nil {
            stackWindowController = AmpXStackWindowController(
                coordinator: self,
                skin: skin,
                moduleViews: visibleStackModuleViews(),
                playlistViewportHeight: playlistViewportHeight
            )
            dragController.bind(viewport: stackWindowController!.stackViewport)
        }

        stackWindowController?.updateLayout()
        stackWindowController?.applyStackFrame(stackFrame)
        stackWindowController?.showWindow(nil)
        isStackVisible = true
    }

    func closeStack() {
        if let window = stackWindowController?.window {
            stackFrame = window.frame
        }
        stackWindowController?.window?.orderOut(nil)
        isStackVisible = false
        persistLayout()
    }

    func closeModule(_ id: AmpXModuleID) {
        dragController.cancelDragIfDragging(moduleID: id)
        if state.detached.contains(id) {
            tearDownDetachedWindow(for: id)
        }
        state.close(id)
        stackWindowController?.updateLayout()
        persistLayout()
    }

    func reopenModule(_ id: AmpXModuleID) {
        state.reopen(id)
        stackWindowController?.updateLayout()
        persistLayout()
    }

    func setCollapsed(_ id: AmpXModuleID, _ value: Bool) {
        if value {
            dragController.cancelDragIfDragging(moduleID: id)
        }
        state.setCollapsed(id, value)
        detachedWindowControllers[id]?.window?.contentView?.needsLayout = true
        stackWindowController?.updateLayout()
        for controller in detachedWindowControllers.values {
            relayoutDetachedModule(controller)
        }
        persistLayout()
    }

    func detach(_ id: AmpXModuleID, at screenPoint: CGPoint, inheritedWidth: CGFloat) {
        guard id != .player, !state.detached.contains(id) else { return }
        guard let view = moduleViews[id] else { return }

        state.detach(id)

        let frame = detachedFrames[id]
            ?? defaultDetachedFrame(for: id, at: screenPoint, inheritedWidth: inheritedWidth)

        let controller = detachedWindowControllers[id]
            ?? AmpXDetachedModuleWindowController(
                moduleID: id,
                coordinator: self,
                skin: skin,
                inheritedWidth: inheritedWidth,
                frame: frame
            )

        detachedWindowControllers[id] = controller
        detachedFrames[id] = frame

        transferModuleView(view, to: controller)
        controller.applyFrame(frame)
        controller.showWindow(nil)

        stackWindowController?.updateLayout()
        persistLayout()
    }

    func redock(_ id: AmpXModuleID, at visibleDropIndex: Int) {
        guard let view = moduleViews[id] else { return }

        let fullIndex = AmpXModuleDragController.fullOrderIndex(
            forVisibleDropIndex: visibleDropIndex,
            excluding: id,
            in: state
        )

        if let detachedController = detachedWindowControllers[id] {
            _ = detachedController.detachModuleView()
            detachedController.window?.orderOut(nil)
            detachedWindowControllers.removeValue(forKey: id)
        }

        state.redock(id, at: fullIndex)
        transferModuleView(view, to: stackWindowController?.stackViewport.stackView)

        if !isStackVisible {
            showStack()
        } else {
            stackWindowController?.updateLayout()
        }
        persistLayout()
    }

    func menuRedock(_ id: AmpXModuleID, at visibleDropIndex: Int) {
        if !isStackVisible {
            showStack()
        }
        redock(id, at: visibleDropIndex)
    }

    func reorder(_ id: AmpXModuleID, toVisibleDropIndex visibleDropIndex: Int) {
        let fullIndex = AmpXModuleDragController.fullOrderIndex(
            forVisibleDropIndex: visibleDropIndex,
            excluding: id,
            in: state
        )
        state.move(id, to: fullIndex)
        stackWindowController?.updateLayout()
        persistLayout()
    }

    func updateDetachedFrame(_ id: AmpXModuleID, frame: CGRect) {
        guard AmpXLayoutStore.isValidFrame(frame) else { return }
        let clamped = AmpXLayoutStore.clampedToVisibleFrame(frame, screen: screen)
        detachedFrames[id] = clamped
        detachedWindowControllers[id]?.applyFrame(clamped)
        persistLayout()
    }

    func detachedWindowFrame(for id: AmpXModuleID) -> CGRect? {
        detachedWindowControllers[id]?.window?.frame ?? detachedFrames[id]
    }

    func moduleView(for id: AmpXModuleID) -> AmpXModuleView? {
        moduleViews[id]
    }

    func makeDropGeometry(excluding draggedID: AmpXModuleID) -> AmpXDropGeometry {
        guard let stackWindowController else {
            return AmpXDropGeometry(bounds: .zero, orderedFrames: [])
        }

        let width = stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
        let availableHeight = stackWindowController.stackViewport.bounds.height
        let layout = AmpXLayout.calculate(
            state: state,
            width: width,
            playlistViewportHeight: playlistViewportHeight,
            availableHeight: max(availableHeight, 1)
        )

        let orderedFrames = state.order.compactMap { moduleID -> (AmpXModuleID, CGRect)? in
            guard moduleID != draggedID,
                  !state.closed.contains(moduleID),
                  !state.detached.contains(moduleID),
                  let frame = layout.frames[moduleID]
            else { return nil }
            return (moduleID, frame)
        }

        return AmpXDropGeometry(
            bounds: CGRect(x: 0, y: 0, width: width, height: layout.contentHeight),
            orderedFrames: orderedFrames
        )
    }

    func handleStackFrameChanged(_ frame: CGRect) {
        guard AmpXLayoutStore.isValidFrame(frame) else { return }
        stackFrame = AmpXLayoutStore.clampedToVisibleFrame(frame, screen: screen)
        persistLayout()
    }

    func handlePlayerHeaderClose() {
        closeStack()
    }

    func handleModuleHeaderClose(_ id: AmpXModuleID) {
        closeModule(id)
    }

    func handleModuleHeaderCollapse(_ id: AmpXModuleID) {
        let collapsed = state.collapsed.contains(id)
        setCollapsed(id, !collapsed)
    }

    func handlePlayerHeaderMinimize() {
        stackWindowController?.window?.miniaturize(nil)
    }

    func adjustPlaylistViewport(byHeightDelta delta: CGFloat, width: CGFloat) {
        let scale = AmpXLayout.scale(width: width)
        playlistViewportHeight = AmpXLayout.adjustedPlaylistViewportHeight(
            preferred: playlistViewportHeight,
            heightDelta: delta,
            scale: scale
        )
        stackWindowController?.setPreferredPlaylistViewportHeight(playlistViewportHeight)
        stackWindowController?.updateLayout()
        persistLayout()
    }

    func revealStackContent(_ rect: CGRect) {
        stackWindowController?.revealContent(rect)
    }

    private func createModuleViews() {
        for moduleID in AmpXModuleID.allCases {
            let content = AmpXModuleContent.make(moduleID: moduleID, skin: skin)
            let view = AmpXModuleView(moduleID: moduleID, content: content, skin: skin)
            wireHeader(for: view)
            moduleViews[moduleID] = view
        }
    }

    private func wireHeader(for view: AmpXModuleView) {
        let moduleID = view.moduleID

        view.header.onCollapse = { [weak self] in
            self?.handleModuleHeaderCollapse(moduleID)
        }

        view.header.onClose = { [weak self] in
            guard let self else { return }
            if moduleID == .player {
                self.handlePlayerHeaderClose()
            } else {
                self.handleModuleHeaderClose(moduleID)
            }
        }

        view.header.onMinimize = { [weak self] in
            guard moduleID == .player else { return }
            self?.handlePlayerHeaderMinimize()
        }

        view.header.onGripMouseDown = { [weak self] event in
            self?.dragController.beginGripDrag(moduleID: moduleID, event: event)
        }

        view.header.onGripMouseDragged = { [weak self] event in
            self?.dragController.updateDrag(event: event)
        }

        view.header.onGripMouseUp = { [weak self] event in
            self?.dragController.endDrag(event: event)
        }
    }

    private func restoreDetachedModules() {
        for moduleID in state.detached where moduleID != .player {
            guard let view = moduleViews[moduleID] else { continue }

            let frame = detachedFrames[moduleID]
                ?? defaultDetachedFrame(
                    for: moduleID,
                    at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY),
                    inheritedWidth: AmpXMetrics.compositionWidth
                )

            let controller = AmpXDetachedModuleWindowController(
                moduleID: moduleID,
                coordinator: self,
                skin: skin,
                inheritedWidth: frame.width,
                frame: frame
            )
            detachedWindowControllers[moduleID] = controller
            transferModuleView(view, to: controller)
            controller.showWindow(nil)
        }
    }

    private func defaultDetachedFrame(
        for id: AmpXModuleID,
        at screenPoint: CGPoint,
        inheritedWidth: CGFloat
    ) -> CGRect {
        let scale = AmpXLayout.scale(width: inheritedWidth)
        let height = detachedModuleHeight(for: id, scale: scale)
        return AmpXLayoutStore.clampedToVisibleFrame(
            CGRect(
                x: screenPoint.x - inheritedWidth / 2,
                y: screenPoint.y - AmpXMetrics.headerHeight * scale,
                width: inheritedWidth,
                height: height
            ),
            screen: screen
        )
    }

    private func detachedModuleHeight(for id: AmpXModuleID, scale: CGFloat) -> CGFloat {
        var moduleState = state
        moduleState.detached.remove(id)
        let layout = AmpXLayout.calculate(
            state: moduleState,
            width: AmpXMetrics.compositionWidth * scale,
            playlistViewportHeight: playlistViewportHeight,
            availableHeight: 10_000
        )
        return layout.frames[id]?.height ?? AmpXMetrics.headerHeight * scale
    }

    private func visibleStackModuleViews() -> [AmpXModuleID: AmpXModuleView] {
        moduleViews.filter { moduleID, _ in
            !state.detached.contains(moduleID) && !state.closed.contains(moduleID)
        }
    }

    private func transferModuleView(_ view: AmpXModuleView, to stackView: AmpXModuleStackView?) {
        view.removeFromSuperview()
        stackView?.addModuleView(view)
    }

    private func transferModuleView(_ view: AmpXModuleView, to controller: AmpXDetachedModuleWindowController) {
        let width = controller.window?.frame.width ?? AmpXMetrics.compositionWidth
        var moduleState = state
        moduleState.detached.remove(view.moduleID)
        let layout = AmpXLayout.calculate(
            state: moduleState,
            width: width,
            playlistViewportHeight: playlistViewportHeight,
            availableHeight: 10_000
        )
        controller.attachModuleView(view, layout: layout)
    }

    private func relayoutDetachedModule(_ controller: AmpXDetachedModuleWindowController) {
        guard let view = controller.detachModuleView() else { return }
        transferModuleView(view, to: controller)
    }

    private func tearDownDetachedWindow(for id: AmpXModuleID) {
        detachedWindowControllers[id]?.window?.orderOut(nil)
        detachedWindowControllers.removeValue(forKey: id)
        detachedFrames.removeValue(forKey: id)
    }

    private func persistLayout() {
        let layout = AmpXSavedLayout(
            state: state,
            stackFrame: stackFrame,
            detachedFrames: detachedFrames,
            playlistViewportHeight: playlistViewportHeight
        )
        layoutStore.save(layout)
    }
}
