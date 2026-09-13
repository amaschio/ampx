import AppKit

@MainActor
final class AmpXStackWindowController: NSWindowController, NSWindowDelegate {
    weak var coordinator: AmpXHostCoordinator?
    private let skin: any AmpXSkin
    private let viewport: AmpXStackViewport
    private var preferredPlaylistViewportHeight: CGFloat
    private var isHandlingClose = false
    private var moveSaveWorkItem: DispatchWorkItem?
    private var lastLiveResizeContentSize: NSSize = .zero
    private var isLiveResizing = false

    init(
        coordinator: AmpXHostCoordinator,
        skin: any AmpXSkin,
        moduleViews: [AmpXModuleID: AmpXModuleView],
        playlistViewportHeight: CGFloat
    ) {
        self.coordinator = coordinator
        self.skin = skin
        self.preferredPlaylistViewportHeight = playlistViewportHeight
        self.viewport = AmpXStackViewport(skin: skin)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: 600),
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = self.viewport
        window.backgroundColor = skin.background

        super.init(window: window)

        window.delegate = self
        self.viewport.stackView.setModuleViews(moduleViews)
        self.viewport.onVisibleRectChanged = { [weak coordinator] _ in
            coordinator?.refreshEffectiveVisibility()
        }
        self.applyChrome()
        self.updateLayout()
        self.refreshEffectiveVisibility()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var stackViewport: AmpXStackViewport {
        self.viewport
    }

    func setPreferredPlaylistViewportHeight(_ height: CGFloat) {
        self.preferredPlaylistViewportHeight = height
    }

    func applyStackFrame(_ frame: CGRect) {
        guard let window, AmpXLayoutStore.isValidFrame(frame) else { return }

        var adjusted = window.frame
        adjusted.origin = frame.origin
        adjusted.size.width = frame.width
        window.setFrame(adjusted, display: false)
    }

    func updateLayout() {
        guard let window, let coordinator else { return }

        let width = window.frame.width
        let availableHeight = max(viewport.bounds.height > 0 ? self.viewport.bounds.height : window.contentView?.bounds.height ?? 0, 1)
        let layout = AmpXLayout.calculate(
            state: coordinator.state,
            width: width,
            playlistViewportHeight: self.preferredPlaylistViewportHeight,
            availableHeight: availableHeight
        )
        self.viewport.applyLayout(layout, state: coordinator.state)
        self.resizeWindowPreservingTop(width: width, contentHeight: layout.viewportHeight)
        self.refreshEffectiveVisibility()
    }

    func revealContent(_ rect: CGRect) {
        self.viewport.reveal(rect)
    }

    func clampedFrameSize(for window: NSWindow, to frameSize: NSSize) -> NSSize {
        self.windowWillResize(window, to: frameSize)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: max(frameSize.width, sender.contentMinSize.width),
            height: max(frameSize.height, sender.contentMinSize.height)
        )
    }

    func windowWillStartLiveResize(_: Notification) {
        self.isLiveResizing = true
        self.lastLiveResizeContentSize = self.viewport.bounds.size
    }

    func windowDidEndLiveResize(_: Notification) {
        self.isLiveResizing = false
        self.lastLiveResizeContentSize = .zero
        guard let window else { return }
        self.coordinator?.handleStackFrameChanged(window.frame)
    }

    func windowDidResize(_: Notification) {
        guard self.isLiveResizing, let window else { return }

        let newSize = self.viewport.bounds.size
        guard self.lastLiveResizeContentSize != .zero else {
            self.lastLiveResizeContentSize = newSize
            return
        }

        let widthDelta = newSize.width - self.lastLiveResizeContentSize.width
        let heightDelta = newSize.height - self.lastLiveResizeContentSize.height

        if abs(widthDelta) >= abs(heightDelta) {
            self.updateLayout()
        } else if abs(heightDelta) > 0.5 {
            if self.isStackScrolling(width: window.frame.width, availableHeight: newSize.height) {
                self.updateLayout()
            } else {
                self.coordinator?.adjustPlaylistViewport(
                    byHeightDelta: heightDelta,
                    width: window.frame.width
                )
            }
        }

        self.lastLiveResizeContentSize = newSize
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        guard !self.isHandlingClose else { return true }
        self.isHandlingClose = true
        self.coordinator?.closeStack()
        self.isHandlingClose = false
        return false
    }

    func windowDidMove(_: Notification) {
        guard let window, !window.inLiveResize else { return }

        self.moveSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            self.coordinator?.handleStackFrameChanged(window.frame)
        }
        self.moveSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    func windowDidMiniaturize(_: Notification) {
        self.refreshEffectiveVisibility()
    }

    func windowDidDeminiaturize(_: Notification) {
        self.refreshEffectiveVisibility()
    }

    func windowDidChangeOcclusionState(_: Notification) {
        self.refreshEffectiveVisibility()
    }

    private func refreshEffectiveVisibility() {
        self.coordinator?.refreshEffectiveVisibility()
    }

    private func applyChrome() {
        guard let window else { return }
        AmpXWindowChrome.apply(to: window, minimumHeaderHeight: AmpXMetrics.headerHeight)
    }

    private func isStackScrolling(width: CGFloat, availableHeight: CGFloat) -> Bool {
        guard let coordinator else { return false }
        return AmpXLayout.calculate(
            state: coordinator.state,
            width: width,
            playlistViewportHeight: self.preferredPlaylistViewportHeight,
            availableHeight: availableHeight
        ).scrolls
    }

    private func resizeWindowPreservingTop(width: CGFloat, contentHeight: CGFloat) {
        guard let window else { return }

        let topY = window.frame.maxY
        window.setContentSize(NSSize(width: width, height: contentHeight))
        var frame = window.frame
        frame.origin.y = topY - frame.height
        window.setFrame(frame, display: false)
    }
}
