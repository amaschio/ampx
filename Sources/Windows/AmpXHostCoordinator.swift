import AppKit

@MainActor
final class AmpXHostCoordinator {
    private(set) var state: AmpXModuleOrder
    private let skin: any AmpXSkin
    private let layoutStore: AmpXLayoutStore
    private let screen: NSScreen

    private var stackWindowController: AmpXStackWindowController?
    private var moduleViews: [AmpXModuleID: AmpXModuleView] = [:]
    private var stackFrame: CGRect
    private var detachedFrames: [AmpXModuleID: CGRect]
    private var playlistViewportHeight: CGFloat

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
    }

    func showStack() {
        if stackWindowController == nil {
            stackWindowController = AmpXStackWindowController(
                coordinator: self,
                skin: skin,
                moduleViews: moduleViews,
                playlistViewportHeight: playlistViewportHeight
            )
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
        state.setCollapsed(id, value)
        stackWindowController?.updateLayout()
        persistLayout()
    }

    func moduleView(for id: AmpXModuleID) -> AmpXModuleView? {
        moduleViews[id]
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
