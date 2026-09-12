import AppKit

@MainActor
final class AmpXStackWindowController: NSWindowController, NSWindowDelegate {
    private let moduleState: AmpXModuleOrder
    private let skin: any AmpXSkin
    private let stackView = AmpXModuleStackView()

    init(state: AmpXModuleOrder, skin: any AmpXSkin) {
        self.moduleState = state
        self.skin = skin

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
        self.setupModuleViews()
        self.applyChrome()
        self.updateLayout()
        self.centerOnScreen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private func setupModuleViews() {
        var views: [AmpXModuleID: AmpXModuleView] = [:]
        for moduleID in self.moduleState.order {
            let content = AmpXModuleContent.make(moduleID: moduleID, skin: self.skin)
            views[moduleID] = AmpXModuleView(moduleID: moduleID, content: content, skin: self.skin)
        }
        self.stackView.setModuleViews(views)
    }

    private func applyChrome() {
        guard let window else { return }
        AmpXWindowChrome.apply(to: window, minimumHeaderHeight: AmpXMetrics.headerHeight)
    }

    private func updateLayout() {
        guard let window else { return }

        let width = window.frame.width
        let availableHeight = max(window.contentView?.bounds.height ?? 0, 1)
        let layout = AmpXLayout.calculate(
            state: self.moduleState,
            width: width,
            playlistViewportHeight: AmpXMetrics.defaultPlaylistViewportHeight,
            availableHeight: availableHeight
        )
        self.stackView.applyLayout(layout, state: self.moduleState)
        window.setContentSize(NSSize(width: width, height: layout.contentHeight))
    }

    private func centerOnScreen() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let origin = NSPoint(
            x: screenFrame.midX - windowFrame.width / 2,
            y: screenFrame.maxY - windowFrame.height - 20
        )
        window.setFrameOrigin(origin)
    }
}
