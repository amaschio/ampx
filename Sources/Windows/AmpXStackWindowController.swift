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
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var stackViewport: AmpXStackViewport {
        viewport
    }

    func setPreferredPlaylistViewportHeight(_ height: CGFloat) {
        preferredPlaylistViewportHeight = height
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
        let availableHeight = max(viewport.bounds.height > 0 ? viewport.bounds.height : window.contentView?.bounds.height ?? 0, 1)
        let layout = AmpXLayout.calculate(
            state: coordinator.state,
            width: width,
            playlistViewportHeight: preferredPlaylistViewportHeight,
            availableHeight: availableHeight
        )
        viewport.applyLayout(layout, state: coordinator.state)
        resizeWindowPreservingTop(width: width, contentHeight: layout.viewportHeight)
        refreshEffectiveVisibility()
    }

    func revealContent(_ rect: CGRect) {
        viewport.reveal(rect)
    }

    func clampedFrameSize(for window: NSWindow, to frameSize: NSSize) -> NSSize {
        windowWillResize(window, to: frameSize)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: max(frameSize.width, sender.contentMinSize.width),
            height: max(frameSize.height, sender.contentMinSize.height)
        )
    }

    func windowWillStartLiveResize(_: Notification) {
        isLiveResizing = true
        lastLiveResizeContentSize = viewport.bounds.size
    }

    func windowDidEndLiveResize(_: Notification) {
        isLiveResizing = false
        lastLiveResizeContentSize = .zero
        guard let window else { return }
        coordinator?.handleStackFrameChanged(window.frame)
    }

    func windowDidResize(_: Notification) {
        guard isLiveResizing, let window else { return }

        let newSize = viewport.bounds.size
        guard lastLiveResizeContentSize != .zero else {
            lastLiveResizeContentSize = newSize
            return
        }

        let widthDelta = newSize.width - lastLiveResizeContentSize.width
        let heightDelta = newSize.height - lastLiveResizeContentSize.height

        if abs(widthDelta) >= abs(heightDelta) {
            updateLayout()
        } else if abs(heightDelta) > 0.5 {
            if isStackScrolling(width: window.frame.width, availableHeight: newSize.height) {
                updateLayout()
            } else {
                coordinator?.adjustPlaylistViewport(
                    byHeightDelta: heightDelta,
                    width: window.frame.width
                )
            }
        }

        lastLiveResizeContentSize = newSize
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        guard !isHandlingClose else { return true }
        isHandlingClose = true
        coordinator?.closeStack()
        isHandlingClose = false
        return false
    }

    func windowDidMove(_: Notification) {
        guard let window, !window.inLiveResize else { return }

        moveSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            self.coordinator?.handleStackFrameChanged(window.frame)
        }
        moveSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    func windowDidMiniaturize(_: Notification) {
        refreshEffectiveVisibility()
    }

    func windowDidDeminiaturize(_: Notification) {
        refreshEffectiveVisibility()
    }

    func windowDidChangeOcclusionState(_: Notification) {
        refreshEffectiveVisibility()
    }

    private func refreshEffectiveVisibility() {
        coordinator?.refreshEffectiveVisibility()
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
            playlistViewportHeight: preferredPlaylistViewportHeight,
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
