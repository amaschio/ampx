import AppKit

@MainActor
final class AmpXDetachedModuleWindowController: NSWindowController, NSWindowDelegate {
    let moduleID: AmpXModuleID

    private weak var coordinator: AmpXHostCoordinator?
    private let skin: any AmpXSkin
    private let containerView = NSView()
    private var moveSaveWorkItem: DispatchWorkItem?

    init(
        moduleID: AmpXModuleID,
        coordinator: AmpXHostCoordinator,
        skin: any AmpXSkin,
        inheritedWidth: CGFloat,
        frame: CGRect
    ) {
        self.moduleID = moduleID
        self.coordinator = coordinator
        self.skin = skin

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = containerView
        window.backgroundColor = skin.background

        super.init(window: window)

        window.delegate = self
        AmpXWindowChrome.apply(to: window, minimumHeaderHeight: AmpXMetrics.headerHeight)
        resizeToInheritedWidth(inheritedWidth)
        window.setFrame(frame, display: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attachModuleView(_ view: AmpXModuleView, layout: AmpXLayoutResult) {
        view.removeFromSuperview()
        containerView.addSubview(view)
        if let frame = layout.frames[moduleID] {
            view.applyLayout(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        }
        containerView.frame = containerView.superview?.bounds ?? .zero
        resizeWindow(toContentHeight: view.frame.height)
    }

    func detachModuleView() -> AmpXModuleView? {
        containerView.subviews.compactMap { $0 as? AmpXModuleView }.first
    }

    func applyFrame(_ frame: CGRect) {
        guard let window, AmpXLayoutStore.isValidFrame(frame) else { return }
        window.setFrame(frame, display: true)
    }

    func windowDidMove(_: Notification) {
        guard let window, !window.inLiveResize else { return }

        moveSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let window = self.window else { return }
            self.coordinator?.updateDetachedFrame(self.moduleID, frame: window.frame)
        }
        moveSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    func windowDidEndLiveResize(_: Notification) {
        guard let window else { return }
        coordinator?.updateDetachedFrame(moduleID, frame: window.frame)
    }

    private func resizeToInheritedWidth(_ inheritedWidth: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        frame.size.width = inheritedWidth
        window.setFrame(frame, display: false)
    }

    private func resizeWindow(toContentHeight contentHeight: CGFloat) {
        guard let window else { return }

        let topY = window.frame.maxY
        window.setContentSize(NSSize(width: window.frame.width, height: contentHeight))
        var frame = window.frame
        frame.origin.y = topY - frame.height
        window.setFrame(frame, display: false)
    }
}
