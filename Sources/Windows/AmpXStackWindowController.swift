import AppKit

@MainActor
final class AmpXStackWindowController: NSWindowController, NSWindowDelegate {
    private weak var coordinator: AmpXHostCoordinator?
    private let skin: any AmpXSkin
    private let stackView = AmpXModuleStackView()
    private var playlistViewportHeight: CGFloat
    private var isHandlingClose = false
    private var moveSaveWorkItem: DispatchWorkItem?

    init(
        coordinator: AmpXHostCoordinator,
        skin: any AmpXSkin,
        moduleViews: [AmpXModuleID: AmpXModuleView],
        playlistViewportHeight: CGFloat
    ) {
        self.coordinator = coordinator
        self.skin = skin
        self.playlistViewportHeight = playlistViewportHeight

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: AmpXMetrics.compositionWidth, height: 600),
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = self.stackView
        window.backgroundColor = skin.background

        super.init(window: window)

        window.delegate = self
        self.stackView.setModuleViews(moduleViews)
        self.applyChrome()
        self.updateLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        let availableHeight = max(window.contentView?.bounds.height ?? 0, 1)
        let layout = AmpXLayout.calculate(
            state: coordinator.state,
            width: width,
            playlistViewportHeight: playlistViewportHeight,
            availableHeight: availableHeight
        )
        self.stackView.applyLayout(layout, state: coordinator.state)
        window.setContentSize(NSSize(width: width, height: layout.contentHeight))
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

    func windowShouldClose(_: NSWindow) -> Bool {
        guard !isHandlingClose else { return true }
        isHandlingClose = true
        coordinator?.closeStack()
        isHandlingClose = false
        return false
    }

    func windowDidEndLiveResize(_: Notification) {
        guard let window else { return }
        coordinator?.handleStackFrameChanged(window.frame)
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

    private func applyChrome() {
        guard let window else { return }
        AmpXWindowChrome.apply(to: window, minimumHeaderHeight: AmpXMetrics.headerHeight)
    }
}
