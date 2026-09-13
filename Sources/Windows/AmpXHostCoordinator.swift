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
    private(set) lazy var theaterController: AmpXTheaterController = .init(
        hosts: self,
        screenFrame: { [weak self] in self?.screen.frame ?? .zero },
        getPresentation: { NSApp.presentationOptions },
        setPresentation: { NSApp.presentationOptions = $0 }
    )

    private(set) var isStackVisible = false

    var stackWindow: NSWindow? {
        self.stackWindowController?.window
    }

    var stackWindowFrame: CGRect? {
        self.stackWindow?.frame
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
        if self.stackWindowController == nil {
            self.stackWindowController = AmpXStackWindowController(
                coordinator: self,
                skin: self.skin,
                moduleViews: self.visibleStackModuleViews(),
                playlistViewportHeight: self.playlistViewportHeight
            )
            self.dragController.bind(viewport: self.stackWindowController!.stackViewport)
        }

        self.stackWindowController?.updateLayout()
        self.stackWindowController?.applyStackFrame(self.stackFrame)
        self.stackWindowController?.showWindow(nil)
        self.isStackVisible = true
        self.refreshEffectiveVisibility()
    }

    func closeStack() {
        if let window = stackWindowController?.window {
            self.stackFrame = window.frame
        }
        self.stackWindowController?.window?.orderOut(nil)
        self.isStackVisible = false
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func closeModule(_ id: AmpXModuleID) {
        let nextFocus = self.nextVisibleModule(after: id)
        self.dragController.cancelDragIfDragging(moduleID: id)
        if id == .enthea, self.theaterController.isActive {
            self.theaterController.exit()
        }
        if self.state.detached.contains(id) {
            self.tearDownDetachedWindow(for: id)
        }
        if id == .enthea {
            (self.moduleViews[id]?.content as? EntheaModuleContent)?.closeHost()
        }
        self.state.close(id)
        self.focusModule(nextFocus)
        self.stackWindowController?.updateLayout()
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func reopenModule(_ id: AmpXModuleID) {
        self.state.reopen(id)
        if id == .enthea {
            (self.moduleViews[id]?.content as? EntheaModuleContent)?.reopenHost()
        }
        self.stackWindowController?.updateLayout()
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func setCollapsed(_ id: AmpXModuleID, _ value: Bool) {
        if value {
            self.dragController.cancelDragIfDragging(moduleID: id)
        }
        self.state.setCollapsed(id, value)
        self.moduleViews[id]?.setContentCollapsed(value)
        self.detachedWindowControllers[id]?.window?.contentView?.needsLayout = true
        self.stackWindowController?.updateLayout()
        for controller in self.detachedWindowControllers.values {
            self.relayoutDetachedModule(controller)
        }
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func detach(_ id: AmpXModuleID, at screenPoint: CGPoint, inheritedWidth: CGFloat) {
        guard id != .player, !self.state.detached.contains(id) else { return }
        guard let view = moduleViews[id] else { return }

        self.state.detach(id)

        let frame = self.detachedFrames[id]
            ?? self.defaultDetachedFrame(for: id, at: screenPoint, inheritedWidth: inheritedWidth)

        let controller = self.detachedWindowControllers[id]
            ?? AmpXDetachedModuleWindowController(
                moduleID: id,
                coordinator: self,
                skin: self.skin,
                inheritedWidth: inheritedWidth,
                frame: frame
            )

        self.detachedWindowControllers[id] = controller
        self.detachedFrames[id] = frame

        self.transferModuleView(view, to: controller)
        controller.applyFrame(frame)
        controller.showWindow(nil)

        self.stackWindowController?.updateLayout()
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func redock(_ id: AmpXModuleID, at visibleDropIndex: Int) {
        guard let view = moduleViews[id] else { return }

        let fullIndex = AmpXModuleDragController.fullOrderIndex(
            forVisibleDropIndex: visibleDropIndex,
            excluding: id,
            in: self.state
        )

        if let detachedController = detachedWindowControllers[id] {
            _ = detachedController.detachModuleView()
            detachedController.window?.orderOut(nil)
            self.detachedWindowControllers.removeValue(forKey: id)
        }

        self.state.redock(id, at: fullIndex)
        self.transferModuleView(view, to: self.stackWindowController?.stackViewport.stackView)

        if !self.isStackVisible {
            self.showStack()
        } else {
            self.stackWindowController?.updateLayout()
        }
        self.refreshEffectiveVisibility()
        self.persistLayout()
    }

    func menuRedock(_ id: AmpXModuleID, at visibleDropIndex: Int) {
        if !self.isStackVisible {
            self.showStack()
        }
        self.redock(id, at: visibleDropIndex)
    }

    func reorder(_ id: AmpXModuleID, toVisibleDropIndex visibleDropIndex: Int) {
        let fullIndex = AmpXModuleDragController.fullOrderIndex(
            forVisibleDropIndex: visibleDropIndex,
            excluding: id,
            in: self.state
        )
        self.state.move(id, to: fullIndex)
        self.stackWindowController?.updateLayout()
        self.persistLayout()
    }

    func updateDetachedFrame(_ id: AmpXModuleID, frame: CGRect) {
        guard !self.theaterController.isActive || id != .enthea else { return }
        guard AmpXLayoutStore.isValidFrame(frame) else { return }
        let clamped = AmpXLayoutStore.clampedToVisibleFrame(frame, screen: self.screen)
        self.detachedFrames[id] = clamped
        self.detachedWindowControllers[id]?.applyFrame(clamped)
        self.persistLayout()
    }

    func detachedWindowFrame(for id: AmpXModuleID) -> CGRect? {
        self.detachedWindowControllers[id]?.window?.frame ?? self.detachedFrames[id]
    }

    func moduleView(for id: AmpXModuleID) -> AmpXModuleView? {
        self.moduleViews[id]
    }

    func makeDropGeometry(excluding draggedID: AmpXModuleID) -> AmpXDropGeometry {
        guard let stackWindowController else {
            return AmpXDropGeometry(bounds: .zero, orderedFrames: [])
        }

        let width = self.stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
        let availableHeight = stackWindowController.stackViewport.bounds.height
        let layout = AmpXLayout.calculate(
            state: self.state,
            width: width,
            playlistViewportHeight: self.playlistViewportHeight,
            availableHeight: max(availableHeight, 1)
        )

        let orderedFrames = self.state.order.compactMap { moduleID -> (AmpXModuleID, CGRect)? in
            guard moduleID != draggedID,
                  !self.state.closed.contains(moduleID),
                  !self.state.detached.contains(moduleID),
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
        self.stackFrame = AmpXLayoutStore.clampedToVisibleFrame(frame, screen: self.screen)
        self.persistLayout()
    }

    func handlePlayerHeaderClose() {
        self.closeStack()
    }

    func handleModuleHeaderClose(_ id: AmpXModuleID) {
        self.closeModule(id)
    }

    func handleModuleHeaderCollapse(_ id: AmpXModuleID) {
        let collapsed = self.state.collapsed.contains(id)
        self.setCollapsed(id, !collapsed)
    }

    func handlePlayerHeaderMinimize() {
        self.stackWindowController?.window?.miniaturize(nil)
    }

    func adjustPlaylistViewport(byHeightDelta delta: CGFloat, width: CGFloat) {
        let scale = AmpXLayout.scale(width: width)
        self.playlistViewportHeight = AmpXLayout.adjustedPlaylistViewportHeight(
            preferred: self.playlistViewportHeight,
            heightDelta: delta,
            scale: scale
        )
        self.stackWindowController?.setPreferredPlaylistViewportHeight(self.playlistViewportHeight)
        self.stackWindowController?.updateLayout()
        self.persistLayout()
    }

    func revealStackContent(_ rect: CGRect) {
        self.stackWindowController?.revealContent(rect)
    }

    func performModuleCommand(_ command: AmpXModuleCommand) {
        switch command {
        case .moveUp:
            self.moveFocusedModule(by: -1)
        case .moveDown:
            self.moveFocusedModule(by: 1)
        case .toggleDetach:
            self.toggleDetachFocusedModule()
        case .toggleCollapse:
            self.toggleCollapseFocusedModule()
        }
    }

    func noteFocusedModule(_ id: AmpXModuleID) {
        self.focusedModuleID = id
    }

    func toggleTheater() {
        if self.theaterController.isActive {
            self.theaterController.exit()
        } else {
            self.theaterController.enter()
        }
    }

    func exitTheater() {
        self.theaterController.exit()
    }

    var isInTheater: Bool {
        self.theaterController.isActive
    }

    private func moveFocusedModule(by offset: Int) {
        guard self.focusedModuleID != .player else { return }
        guard let currentIndex = visibleModuleOrder().firstIndex(of: focusedModuleID) else { return }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < self.visibleModuleOrder().count else { return }
        let targetID = self.visibleModuleOrder()[targetIndex]
        guard targetID != .player else { return }

        if self.state.detached.contains(self.focusedModuleID) {
            self.menuRedock(self.focusedModuleID, at: targetIndex)
        } else {
            self.reorder(self.focusedModuleID, toVisibleDropIndex: targetIndex)
        }
    }

    private func toggleDetachFocusedModule() {
        guard self.focusedModuleID != .player else { return }
        if self.state.detached.contains(self.focusedModuleID) {
            self.menuRedock(self.focusedModuleID, at: self.visibleModuleOrder().count)
        } else if let moduleView = moduleViews[focusedModuleID], let stackWindow {
            let windowPoint = moduleView.convert(
                NSPoint(x: moduleView.bounds.midX, y: moduleView.bounds.maxY),
                to: nil
            )
            let screenPoint = stackWindow.convertPoint(toScreen: windowPoint)
            self.detach(
                self.focusedModuleID,
                at: CGPoint(x: screenPoint.x, y: screenPoint.y),
                inheritedWidth: stackWindow.frame.width
            )
        }
    }

    private func toggleCollapseFocusedModule() {
        let collapsed = self.state.collapsed.contains(self.focusedModuleID)
        self.setCollapsed(self.focusedModuleID, !collapsed)
    }

    private func focusModule(_ id: AmpXModuleID) {
        self.focusedModuleID = id
        guard let view = moduleViews[id] else { return }
        self.stackWindow?.makeFirstResponder(view.header)
        self.detachedWindowControllers[id]?.window?.makeFirstResponder(view.header)
    }

    private func nextVisibleModule(after id: AmpXModuleID) -> AmpXModuleID {
        let visible = self.visibleModuleOrder()
        guard let index = visible.firstIndex(of: id) else { return .player }
        if index + 1 < visible.count {
            return visible[index + 1]
        }
        return visible.first ?? .player
    }

    private func visibleModuleOrder() -> [AmpXModuleID] {
        self.state.order.filter { moduleID in
            !self.state.closed.contains(moduleID) && !self.state.detached.contains(moduleID)
        }
    }

    private func createModuleViews() {
        for moduleID in AmpXModuleID.allCases {
            let content = self.makeModuleContent(for: moduleID)
            let view = AmpXModuleView(moduleID: moduleID, content: content, skin: skin)
            self.wireHeader(for: view)
            self.moduleViews[moduleID] = view
        }
        if !self.state.closed.contains(.enthea) {
            (self.moduleViews[.enthea]?.content as? EntheaModuleContent)?.reopenHost()
        }
    }

    private func makeModuleContent(for moduleID: AmpXModuleID) -> AmpXModuleContent {
        switch moduleID {
        case .player:
            PlayerModuleContent(
                skin: self.skin,
                audioPlayer: self.audioPlayer,
                playlistManager: self.playlistManager,
                onToggleModule: { [weak self] id in
                    self?.toggleModuleVisibility(id)
                }
            )
        case .equalizer:
            EqualizerModuleContent(skin: self.skin, audioPlayer: self.audioPlayer)
        case .playlist:
            PlaylistModuleContent(
                skin: self.skin,
                manager: self.playlistManager,
                audioPlayer: self.audioPlayer
            )
        case .enthea:
            EntheaModuleContent(
                skin: self.skin,
                audioPlayer: self.audioPlayer,
                isTheater: { [weak self] in self?.theaterController.isActive ?? false },
                onToggleTheater: { [weak self] in self?.toggleTheater() }
            )
        default:
            AmpXModuleContent.make(moduleID: moduleID, skin: self.skin)
        }
    }

    private func toggleModuleVisibility(_ id: AmpXModuleID) {
        if self.state.closed.contains(id) {
            self.reopenModule(id)
        } else {
            self.closeModule(id)
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
        for moduleID in self.state.detached where moduleID != .player {
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
        let height = self.detachedModuleHeight(for: id, scale: scale)
        return AmpXLayoutStore.clampedToVisibleFrame(
            CGRect(
                x: screenPoint.x - inheritedWidth / 2,
                y: screenPoint.y - AmpXMetrics.headerHeight * scale,
                width: inheritedWidth,
                height: height
            ),
            screen: self.screen
        )
    }

    private func detachedModuleHeight(for id: AmpXModuleID, scale: CGFloat) -> CGFloat {
        var moduleState = self.state
        moduleState.detached.remove(id)
        let layout = AmpXLayout.calculate(
            state: moduleState,
            width: AmpXMetrics.compositionWidth * scale,
            playlistViewportHeight: self.playlistViewportHeight,
            availableHeight: 10000
        )
        return layout.frames[id]?.height ?? AmpXMetrics.headerHeight * scale
    }

    private func visibleStackModuleViews() -> [AmpXModuleID: AmpXModuleView] {
        self.moduleViews.filter { moduleID, _ in
            !self.state.detached.contains(moduleID) && !self.state.closed.contains(moduleID)
        }
    }

    private func transferModuleView(_ view: AmpXModuleView, to stackView: AmpXModuleStackView?) {
        view.removeFromSuperview()
        stackView?.addModuleView(view)
    }

    private func transferModuleView(_ view: AmpXModuleView, to controller: AmpXDetachedModuleWindowController) {
        let width = controller.window?.frame.width ?? AmpXMetrics.compositionWidth
        var moduleState = self.state
        moduleState.detached.remove(view.moduleID)
        let layout = AmpXLayout.calculate(
            state: moduleState,
            width: width,
            playlistViewportHeight: self.playlistViewportHeight,
            availableHeight: 10000
        )
        controller.attachModuleView(view, layout: layout)
    }

    private func relayoutDetachedModule(_ controller: AmpXDetachedModuleWindowController) {
        guard let view = controller.detachModuleView() else { return }
        self.transferModuleView(view, to: controller)
    }

    private func tearDownDetachedWindow(for id: AmpXModuleID) {
        self.detachedWindowControllers[id]?.window?.orderOut(nil)
        self.detachedWindowControllers.removeValue(forKey: id)
        self.detachedFrames.removeValue(forKey: id)
    }

    private func persistLayout() {
        let layout = AmpXSavedLayout(
            state: state,
            stackFrame: stackFrame,
            detachedFrames: detachedFrames,
            playlistViewportHeight: playlistViewportHeight
        )
        self.layoutStore.save(layout)
    }

    func refreshEffectiveVisibility() {
        for moduleID in AmpXModuleID.allCases {
            guard let moduleView = moduleViews[moduleID] else { continue }
            let inputs = self.visibilityInputs(for: moduleID)
            moduleView.content.setEffectivelyVisible(inputs.isVisible)
        }
        if let playerContent = moduleViews[.player]?.content as? PlayerModuleContent {
            playerContent.updateModuleToggleStates(
                eqOpen: !self.state.closed.contains(.equalizer),
                plOpen: !self.state.closed.contains(.playlist)
            )
        }
    }

    private func visibilityInputs(for moduleID: AmpXModuleID) -> AmpXVisibilityInputs {
        if self.state.detached.contains(moduleID) {
            return AmpXEffectiveVisibility.detachedInputs(
                collapsed: self.state.collapsed.contains(moduleID),
                closed: self.state.closed.contains(moduleID),
                window: self.detachedWindowControllers[moduleID]?.window
            )
        }

        if moduleID == .enthea, self.theaterController.isActive {
            return AmpXEffectiveVisibility.theaterInputs(
                collapsed: self.state.collapsed.contains(moduleID),
                closed: self.state.closed.contains(moduleID),
                window: self.theaterController.window
            )
        }

        let moduleFrame = self.moduleFrameInStackContent(for: moduleID)
        let visibleContentRect = self.stackWindowController?.stackViewport.visibleContentRect ?? .zero
        let stackWindowVisible = self.isStackVisible && (self.stackWindow?.isVisible ?? false)

        var inputs = AmpXEffectiveVisibility.stackInputs(
            collapsed: self.state.collapsed.contains(moduleID),
            closed: self.state.closed.contains(moduleID),
            window: self.stackWindow,
            moduleFrame: moduleFrame,
            visibleContentRect: visibleContentRect
        )
        if !stackWindowVisible {
            inputs.windowVisible = false
        }
        return inputs
    }

    private func refreshEntheaPresentation() {
        (self.moduleViews[.enthea]?.content as? EntheaModuleContent)?.refreshTheaterPresentation()
    }

    func captureTheaterSnapshot(for moduleID: AmpXModuleID) -> AmpXTheaterSnapshot {
        let view = self.moduleViews[moduleID]
        let originalHostID = self.state.detached.contains(moduleID) ? moduleID : nil
        let position = self.state.order.firstIndex(of: moduleID) ?? 0
        let frame: CGRect = if self.state.detached.contains(moduleID) {
            self.detachedWindowFrame(for: moduleID) ?? view?.frame ?? .zero
        } else {
            view?.frame ?? .zero
        }
        let scale = self.moduleScale(for: moduleID)
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
        if self.state.detached.contains(moduleID) {
            self.detachedWindowControllers[moduleID]?.window?.orderOut(nil)
        }
        self.stackWindowController?.updateLayout()
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
            let restoredFrame = AmpXLayoutStore.clampedToVisibleFrame(snapshot.frame, screen: self.screen)
            self.transferModuleView(view, to: controller)
            controller.applyFrame(restoredFrame)
            controller.showWindow(nil)
        } else {
            self.transferModuleView(view, to: self.stackWindowController?.stackViewport.stackView)
            self.stackWindowController?.updateLayout()
        }

        self.refreshEntheaPresentation()
        self.refreshEffectiveVisibility()
    }

    func moduleScale(for moduleID: AmpXModuleID) -> CGFloat {
        if self.state.detached.contains(moduleID) {
            let width = self.detachedWindowControllers[moduleID]?.window?.frame.width ?? AmpXMetrics.compositionWidth
            return AmpXLayout.scale(width: width)
        }
        let width = self.stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
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
