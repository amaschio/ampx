import AppKit

struct AmpXTheaterSnapshot {
    let originalHostID: AmpXModuleID?
    let modulePosition: Int
    let frame: CGRect
    let scale: CGFloat
    let presentationOptions: NSApplication.PresentationOptions
}

enum AmpXHostPresentation {
    case normal
    case theater
}

@MainActor
final class AmpXTheaterController: NSObject, NSWindowDelegate {
    private weak var hosts: AmpXHostCoordinator?
    private let screenFrame: () -> CGRect
    private let getPresentation: () -> NSApplication.PresentationOptions
    private let setPresentation: (NSApplication.PresentationOptions) -> Void

    private var snapshot: AmpXTheaterSnapshot?
    private var theaterWindow: NSWindow?
    private let containerView = NSView()

    private(set) var isActive = false

    init(
        hosts: AmpXHostCoordinator,
        screenFrame: @escaping () -> CGRect,
        getPresentation: @escaping () -> NSApplication.PresentationOptions,
        setPresentation: @escaping (NSApplication.PresentationOptions) -> Void
    ) {
        self.hosts = hosts
        self.screenFrame = screenFrame
        self.getPresentation = getPresentation
        self.setPresentation = setPresentation
        super.init()
    }

    var window: NSWindow? {
        theaterWindow
    }

    func enter() {
        guard !isActive else { return }
        guard let hosts, let view = hosts.moduleView(for: .enthea) else { return }
        guard !hosts.state.closed.contains(.enthea) else { return }

        let geometry = hosts.captureTheaterSnapshot(for: .enthea)
        snapshot = AmpXTheaterSnapshot(
            originalHostID: geometry.originalHostID,
            modulePosition: geometry.modulePosition,
            frame: geometry.frame,
            scale: geometry.scale,
            presentationOptions: getPresentation()
        )
        isActive = true

        hosts.extractModuleViewForTheater(.enthea)

        let frame = screenFrame()
        ensureTheaterWindow(frame: frame)
        containerView.frame = containerView.superview?.bounds ?? frame
        view.enterTheaterPresentation(containerSize: frame.size)
        containerView.addSubview(view)
        theaterWindow?.setFrame(frame, display: true)
        theaterWindow?.orderFrontRegardless()
        theaterWindow?.makeKey()

        var presentation = getPresentation()
        presentation.insert([.autoHideMenuBar, .autoHideDock])
        setPresentation(presentation)

        (view.content as? EntheaModuleContent)?.refreshTheaterPresentation()
        hosts.refreshEffectiveVisibility()
    }

    func exit() {
        guard isActive, let snapshot else { return }

        setPresentation(snapshot.presentationOptions)
        hosts?.reinstallModuleViewFromTheater(.enthea, snapshot: snapshot)

        theaterWindow?.orderOut(nil)
        theaterWindow = nil
        self.snapshot = nil
        isActive = false
    }

    func handleApplicationTermination() {
        if isActive {
            exit()
        }
    }

    func windowWillClose(_: Notification) {
        exit()
    }

    func windowDidMiniaturize(_: Notification) {
        hosts?.refreshEffectiveVisibility()
    }

    func windowDidDeminiaturize(_: Notification) {
        hosts?.refreshEffectiveVisibility()
    }

    func windowDidChangeOcclusionState(_: Notification) {
        hosts?.refreshEffectiveVisibility()
    }

    private func ensureTheaterWindow(frame: CGRect) {
        guard theaterWindow == nil else { return }

        let window = AmpXHostWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = containerView
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        theaterWindow = window
    }
}
