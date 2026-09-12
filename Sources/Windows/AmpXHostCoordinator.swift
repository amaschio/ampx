import AppKit

@MainActor
final class AmpXHostCoordinator: AmpXEntheaTheaterHandling {
    private(set) var state: AmpXModuleOrder
    private let skin: any AmpXSkin
    private let layoutStore: AmpXLayoutStore
    private let screen: NSScreen
    private let audioPlayer: AudioPlayer
    private let playlistManager: PlaylistManager

    private(set) var stackWindowController: AmpXStackWindowController?
    private var moduleViews: [AmpXModuleID: AmpXModuleView] = [:]
    private var detachedWindowControllers: [AmpXModuleID: AmpXDetachedModuleWindowController] = [:]
    private var stackFrame: CGRect
    private var detachedFrames: [AmpXModuleID: CGRect]
    private var playlistViewportHeight: CGFloat

    private(set) var dragController = AmpXModuleDragSession()
    private(set) var focusedModuleID: AmpXModuleID = .player
    private(set) lazy var theaterController: AmpXTheaterController = AmpXTheaterController(
        hosts: self,
        screenFrame: { [weak self] in self?.screen.frame ?? .zero },
        getPresentation: { NSApp.presentationOptions },
        setPresentation: { NSApp.presentationOptions = $0 }
    )

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
        screen: NSScreen? = nil,
        audioPlayer: AudioPlayer = .shared,
        playlistManager: PlaylistManager = .shared
    ) {
        let resolvedScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        self.state = state
        self.skin = skin
        self.screen = resolvedScreen
        self.audioPlayer = audioPlayer
        self.playlistManager = playlistManager
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
        refreshEffectiveVisibility()
    }

    func closeStack() {
        if let window = stackWindowController?.window {
            stackFrame = window.frame
        }
        stackWindowController?.window?.orderOut(nil)
        isStackVisible = false
        refreshEffectiveVisibility()
        persistLayout()
    }

    func closeModule(_ id: AmpXModuleID) {
        let nextFocus = nextVisibleModule(after: id)
        dragController.cancelDragIfDragging(moduleID: id)
        if id == .enthea, theaterController.isActive {
            theaterController.exit()
        }
        if state.detached.contains(id) {
            tearDownDetachedWindow(for: id)
        }
        if id == .enthea {
            (moduleViews[id]?.content as? EntheaModuleContent)?.closeHost()
        }
        state.close(id)
        focusModule(nextFocus)
        stackWindowController?.updateLayout()
        refreshEffectiveVisibility()
        persistLayout()
    }

    func reopenModule(_ id: AmpXModuleID) {
        state.reopen(id)
        if id == .enthea {
            (moduleViews[id]?.content as? EntheaModuleContent)?.reopenHost()
        }
        stackWindowController?.updateLayout()
        refreshEffectiveVisibility()
        persistLayout()
    }

    func setCollapsed(_ id: AmpXModuleID, _ value: Bool) {
        if value {
            dragController.cancelDragIfDragging(moduleID: id)
        }
        state.setCollapsed(id, value)
        moduleViews[id]?.setContentCollapsed(value)
        detachedWindowControllers[id]?.window?.contentView?.needsLayout = true
        stackWindowController?.updateLayout()
        for controller in detachedWindowControllers.values {
            relayoutDetachedModule(controller)
        }
        refreshEffectiveVisibility()
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
        refreshEffectiveVisibility()
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
        refreshEffectiveVisibility()
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
        guard !theaterController.isActive || id != .enthea else { return }
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

    func performModuleCommand(_ command: AmpXModuleCommand) {
        switch command {
        case .moveUp:
            moveFocusedModule(by: -1)
        case .moveDown:
            moveFocusedModule(by: 1)
        case .toggleDetach:
            toggleDetachFocusedModule()
        case .toggleCollapse:
            toggleCollapseFocusedModule()
        }
    }

    func noteFocusedModule(_ id: AmpXModuleID) {
        focusedModuleID = id
    }

    func toggleTheater() {
        if theaterController.isActive {
            theaterController.exit()
        } else {
            theaterController.enter()
        }
    }

    func exitTheater() {
        theaterController.exit()
    }

    var isInTheater: Bool {
        theaterController.isActive
    }

    private func moveFocusedModule(by offset: Int) {
        guard focusedModuleID != .player else { return }
        guard let currentIndex = visibleModuleOrder().firstIndex(of: focusedModuleID) else { return }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < visibleModuleOrder().count else { return }
        let targetID = visibleModuleOrder()[targetIndex]
        guard targetID != .player else { return }

        if state.detached.contains(focusedModuleID) {
            menuRedock(focusedModuleID, at: targetIndex)
        } else {
            reorder(focusedModuleID, toVisibleDropIndex: targetIndex)
        }
    }

    private func toggleDetachFocusedModule() {
        guard focusedModuleID != .player else { return }
        if state.detached.contains(focusedModuleID) {
            menuRedock(focusedModuleID, at: visibleModuleOrder().count)
        } else if let moduleView = moduleViews[focusedModuleID], let stackWindow {
            let windowPoint = moduleView.convert(
                NSPoint(x: moduleView.bounds.midX, y: moduleView.bounds.maxY),
                to: nil
            )
            let screenPoint = stackWindow.convertPoint(toScreen: windowPoint)
            detach(
                focusedModuleID,
                at: CGPoint(x: screenPoint.x, y: screenPoint.y),
                inheritedWidth: stackWindow.frame.width
            )
        }
    }

    private func toggleCollapseFocusedModule() {
        let collapsed = state.collapsed.contains(focusedModuleID)
        setCollapsed(focusedModuleID, !collapsed)
    }

    private func focusModule(_ id: AmpXModuleID) {
        focusedModuleID = id
        guard let view = moduleViews[id] else { return }
        stackWindow?.makeFirstResponder(view.header)
        detachedWindowControllers[id]?.window?.makeFirstResponder(view.header)
    }

    private func nextVisibleModule(after id: AmpXModuleID) -> AmpXModuleID {
        let visible = visibleModuleOrder()
        guard let index = visible.firstIndex(of: id) else { return .player }
        if index + 1 < visible.count {
            return visible[index + 1]
        }
        return visible.first ?? .player
    }

    private func visibleModuleOrder() -> [AmpXModuleID] {
        state.order.filter { moduleID in
            !state.closed.contains(moduleID) && !state.detached.contains(moduleID)
        }
    }

    private func createModuleViews() {
        for moduleID in AmpXModuleID.allCases {
            let content = makeModuleContent(for: moduleID)
            let view = AmpXModuleView(moduleID: moduleID, content: content, skin: skin)
            wireHeader(for: view)
            moduleViews[moduleID] = view
        }
        if !state.closed.contains(.enthea) {
            (moduleViews[.enthea]?.content as? EntheaModuleContent)?.reopenHost()
        }
    }

    private func makeModuleContent(for moduleID: AmpXModuleID) -> AmpXModuleContent {
        switch moduleID {
        case .player:
            return PlayerModuleContent(
                skin: skin,
                audioPlayer: audioPlayer,
                playlistManager: playlistManager,
                onToggleModule: { [weak self] id in
                    self?.toggleModuleVisibility(id)
                }
            )
        case .equalizer:
            return EqualizerModuleContent(skin: skin, audioPlayer: audioPlayer)
        case .playlist:
            return PlaylistModuleContent(
                skin: skin,
                manager: playlistManager,
                audioPlayer: audioPlayer
            )
        case .enthea:
            return EntheaModuleContent(
                skin: skin,
                audioPlayer: audioPlayer,
                isTheater: { [weak self] in self?.theaterController.isActive ?? false },
                onToggleTheater: { [weak self] in self?.toggleTheater() }
            )
        default:
            return AmpXModuleContent.make(moduleID: moduleID, skin: skin)
        }
    }

    private func toggleModuleVisibility(_ id: AmpXModuleID) {
        if state.closed.contains(id) {
            reopenModule(id)
        } else {
            closeModule(id)
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

        view.header.onDetach = { [weak self] in
            guard let self else { return }
            self.noteFocusedModule(moduleID)
            self.toggleDetachFocusedModule()
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

    func refreshEffectiveVisibility() {
        for moduleID in AmpXModuleID.allCases {
            guard let moduleView = moduleViews[moduleID] else { continue }
            let inputs = visibilityInputs(for: moduleID)
            moduleView.content.setEffectivelyVisible(inputs.isVisible)
        }
        if let playerContent = moduleViews[.player]?.content as? PlayerModuleContent {
            playerContent.updateModuleToggleStates(
                eqOpen: !state.closed.contains(.equalizer),
                plOpen: !state.closed.contains(.playlist)
            )
        }
    }

    private func visibilityInputs(for moduleID: AmpXModuleID) -> AmpXVisibilityInputs {
        if state.detached.contains(moduleID) {
            return AmpXEffectiveVisibility.detachedInputs(
                collapsed: state.collapsed.contains(moduleID),
                closed: state.closed.contains(moduleID),
                window: detachedWindowControllers[moduleID]?.window
            )
        }

        if moduleID == .enthea, theaterController.isActive {
            return AmpXEffectiveVisibility.theaterInputs(
                collapsed: state.collapsed.contains(moduleID),
                closed: state.closed.contains(moduleID),
                window: theaterController.window
            )
        }

        let moduleFrame = moduleFrameInStackContent(for: moduleID)
        let visibleContentRect = stackWindowController?.stackViewport.visibleContentRect ?? .zero
        let stackWindowVisible = isStackVisible && (stackWindow?.isVisible ?? false)

        var inputs = AmpXEffectiveVisibility.stackInputs(
            collapsed: state.collapsed.contains(moduleID),
            closed: state.closed.contains(moduleID),
            window: stackWindow,
            moduleFrame: moduleFrame,
            visibleContentRect: visibleContentRect
        )
        if !stackWindowVisible {
            inputs.windowVisible = false
        }
        return inputs
    }

    private func refreshEntheaPresentation() {
        (moduleViews[.enthea]?.content as? EntheaModuleContent)?.refreshTheaterPresentation()
    }

    func captureTheaterSnapshot(for moduleID: AmpXModuleID) -> AmpXTheaterSnapshot {
        let view = moduleViews[moduleID]
        let originalHostID = state.detached.contains(moduleID) ? moduleID : nil
        let position = state.order.firstIndex(of: moduleID) ?? 0
        let frame: CGRect
        if state.detached.contains(moduleID) {
            frame = detachedWindowFrame(for: moduleID) ?? view?.frame ?? .zero
        } else {
            frame = view?.frame ?? .zero
        }
        let scale = moduleScale(for: moduleID)
        return AmpXTheaterSnapshot(
            originalHostID: originalHostID,
            modulePosition: position,
            frame: frame,
            scale: scale,
            presentationOptions: []
        )
    }

    func extractModuleViewForTheater(_ moduleID: AmpXModuleID) {
        guard let view = moduleViews[moduleID] else { return }
        view.removeFromSuperview()
        if state.detached.contains(moduleID) {
            detachedWindowControllers[moduleID]?.window?.orderOut(nil)
        }
        stackWindowController?.updateLayout()
    }

    func reinstallModuleViewFromTheater(_ moduleID: AmpXModuleID, snapshot: AmpXTheaterSnapshot) {
        guard let view = moduleViews[moduleID] else { return }

        if snapshot.originalHostID != nil {
            view.exitTheaterPresentation(restoreFrame: .zero)
        } else {
            view.exitTheaterPresentation(restoreFrame: snapshot.frame)
        }

        if snapshot.originalHostID != nil {
            guard let controller = detachedWindowControllers[moduleID] else { return }
            let restoredFrame = AmpXLayoutStore.clampedToVisibleFrame(snapshot.frame, screen: screen)
            transferModuleView(view, to: controller)
            controller.applyFrame(restoredFrame)
            controller.showWindow(nil)
        } else {
            transferModuleView(view, to: stackWindowController?.stackViewport.stackView)
            stackWindowController?.updateLayout()
        }

        refreshEntheaPresentation()
        refreshEffectiveVisibility()
    }

    func moduleScale(for moduleID: AmpXModuleID) -> CGFloat {
        if state.detached.contains(moduleID) {
            let width = detachedWindowControllers[moduleID]?.window?.frame.width ?? AmpXMetrics.compositionWidth
            return AmpXLayout.scale(width: width)
        }
        let width = stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
        return AmpXLayout.scale(width: width)
    }

    private func moduleFrameInStackContent(for moduleID: AmpXModuleID) -> CGRect {
        guard let moduleView = moduleViews[moduleID],
              let stackView = stackWindowController?.stackViewport.stackView,
              moduleView.superview === stackView
        else { return .zero }
        return moduleView.frame
    }
}
