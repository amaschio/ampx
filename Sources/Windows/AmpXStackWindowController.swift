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
        self.viewport = AmpXStackViewport()

        let window = AmpXHostWindow(
            contentRect: NSRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: AmpXMetrics.playerHeight),
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = self.viewport
        window.backgroundColor = skin.background

        super.init(window: window)

        window.delegate = self
        self.viewport.stackView.setModuleViews(moduleViews)
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

    /// Height the stack may occupy: the visible frame of the window's screen, not the window's own height.
    static func availableHeight(for window: NSWindow?) -> CGFloat {
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        return max(screen?.visibleFrame.height ?? .greatestFiniteMagnitude, 1)
    }

    func setPreferredPlaylistViewportHeight(_ height: CGFloat) {
        self.preferredPlaylistViewportHeight = height
    }

    /// Restores a saved frame by its top edge and width; the height always follows the composition.
    func applyStackFrame(_ frame: CGRect) {
        guard let window, AmpXLayoutStore.isValidFrame(frame) else { return }

        var adjusted = window.frame
        adjusted.origin.x = frame.minX
        adjusted.size.width = frame.width
        adjusted.origin.y = frame.maxY - adjusted.height
        window.setFrame(self.constrainedToVisibleFrame(adjusted), display: false)
        self.updateLayout()
    }

    func updateLayout() {
        guard let window, let coordinator else { return }

        let width = window.frame.width
        let layout = AmpXLayout.calculate(
            state: coordinator.state,
            width: width,
            playlistViewportHeight: self.preferredPlaylistViewportHeight,
            availableHeight: Self.availableHeight(for: window)
        )
        self.viewport.applyLayout(layout, state: coordinator.state)
        self.resizeWindowPreservingTop(width: width, contentHeight: layout.contentHeight)
        self.refreshEffectiveVisibility()
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
            // Only the expanded Playlist resizes vertically; any other vertical drag snaps back.
            if let coordinator, Self.hasExpandedDockedPlaylist(coordinator.state) {
                coordinator.adjustPlaylistViewport(byHeightDelta: heightDelta, width: window.frame.width)
            } else {
                self.updateLayout()
            }
        }

        self.lastLiveResizeContentSize = self.viewport.bounds.size
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

    private static func hasExpandedDockedPlaylist(_ state: AmpXModuleOrder) -> Bool {
        !state.closed.contains(.playlist)
            && !state.detached.contains(.playlist)
            && !state.collapsed.contains(.playlist)
    }

    private func resizeWindowPreservingTop(width: CGFloat, contentHeight: CGFloat) {
        guard let window else { return }

        let topY = window.frame.maxY
        window.setContentSize(NSSize(width: width, height: contentHeight))
        var frame = window.frame
        frame.origin.y = topY - frame.height
        window.setFrame(self.constrainedToVisibleFrame(frame), display: false)
    }

    /// Keeps the window's vertical extent inside the visible frame when it fits; a taller stack stays top-aligned.
    private func constrainedToVisibleFrame(_ frame: CGRect) -> CGRect {
        guard let visible = (window?.screen ?? NSScreen.main)?.visibleFrame else { return frame }
        var result = frame
        if result.height <= visible.height {
            result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        } else {
            result.origin.y = visible.maxY - result.height
        }
        return result
    }
}
