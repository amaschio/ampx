import AppKit

final class AmpXModuleView: NSView {
    let moduleID: AmpXModuleID
    let content: AmpXModuleContent
    let header: AmpXModuleHeaderView

    private(set) var presentation: AmpXHostPresentation = .normal
    private var savedNormalFrame: CGRect = .zero

    private let skin: any AmpXSkin
    private weak var rememberedContentResponder: NSView?

    init(moduleID: AmpXModuleID, content: AmpXModuleContent, skin: any AmpXSkin) {
        self.moduleID = moduleID
        self.content = content
        self.skin = skin
        self.header = AmpXModuleHeaderView(moduleID: moduleID, skin: skin)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(self.header)
        addSubview(content)
        setAccessibilityRole(.group)
        setAccessibilityLabel(self.accessibilityModuleLabel(for: moduleID))
        self.wireFocusTraversal()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `nonisolated`: AppKit reads this from its layer-display path with no Swift task, and on
    /// macOS 26 an isolated getter crashes in `swift_task_isCurrentExecutor` (see commit 5562af8).
    override nonisolated var isFlipped: Bool {
        true
    }

    func applyLayout(frame: CGRect) {
        self.savedNormalFrame = frame
        guard self.presentation == .normal else { return }
        self.applyNormalLayout(frame: frame)
    }

    func enterTheaterPresentation(containerSize: CGSize) {
        self.presentation = .theater
        self.header.isHidden = true
        frame = CGRect(origin: .zero, size: containerSize)
        self.content.frame = bounds
        self.content.bounds = CGRect(origin: .zero, size: bounds.size)
        needsDisplay = true
    }

    func exitTheaterPresentation(restoreFrame: CGRect) {
        self.presentation = .normal
        self.header.isHidden = false
        let targetFrame = restoreFrame == .zero ? self.savedNormalFrame : restoreFrame
        if targetFrame == .zero {
            frame = restoreFrame
            return
        }
        self.applyNormalLayout(frame: targetFrame)
    }

    override func draw(_: NSRect) {
        guard self.presentation == .normal else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        self.skin.panelFrame(
            bounds,
            contentFrame: self.content.isHidden ? nil : self.contentFrameRect,
            in: context,
            backingScale: backingScale
        )
    }

    /// Recessed content frame shared by all modules; spans the header seam as in the reference.
    var contentFrameRect: CGRect {
        let scale = bounds.width / AmpXMetrics.compositionWidth
        let insets = AmpXMetrics.contentFrameInsets
        return CGRect(
            x: insets.left * scale,
            y: insets.top * scale,
            width: bounds.width - (insets.left + insets.right) * scale,
            height: max(0, bounds.height - (insets.top + insets.bottom) * scale)
        )
    }

    private func applyNormalLayout(frame: CGRect) {
        let backingScale = window?.backingScaleFactor ?? 1
        let snappedFrame = CGRect(
            x: AmpXPixelGrid.align(frame.minX, backingScale: backingScale),
            y: AmpXPixelGrid.align(frame.minY, backingScale: backingScale),
            width: AmpXPixelGrid.align(frame.width, backingScale: backingScale),
            height: AmpXPixelGrid.align(frame.height, backingScale: backingScale)
        )
        self.frame = snappedFrame

        // The Playlist stretches instead of scaling (spec Revision 9); every other module scales with its width.
        let stretches = Self.stretchesHorizontally(self.moduleID)
        let scale = stretches ? 1 : Self.scale(forWidth: snappedFrame.width)
        self.header.stretchesHorizontally = stretches
        let headerHeight = AmpXMetrics.headerHeight * scale
        self.header.frame = CGRect(x: 0, y: 0, width: snappedFrame.width, height: headerHeight)
        self.content.frame = CGRect(
            x: 0,
            y: headerHeight,
            width: snappedFrame.width,
            height: max(0, snappedFrame.height - headerHeight)
        )
        // Content lays out and draws in reference points; the bounds scale maps them to the UI scale,
        // keeping hit testing and drawing aligned.
        self.content.bounds = CGRect(
            origin: .zero,
            size: CGSize(width: self.content.frame.width / scale, height: self.content.frame.height / scale)
        )
    }

    static func scale(forWidth width: CGFloat) -> CGFloat {
        width > 0 ? width / AmpXMetrics.compositionWidth : 1
    }

    /// Only the Playlist keeps 1:1 content points at any width.
    static func stretchesHorizontally(_ moduleID: AmpXModuleID) -> Bool {
        moduleID == .playlist
    }

    func setContentCollapsed(_ collapsed: Bool) {
        if collapsed {
            if let responder = window?.firstResponder as? NSView,
               responder.isDescendant(of: content)
            {
                self.rememberedContentResponder = responder
            }
            self.content.isHidden = true
            window?.makeFirstResponder(self.header)
        } else {
            self.content.isHidden = false
            if let rememberedContentResponder,
               rememberedContentResponder.window === window
            {
                window?.makeFirstResponder(rememberedContentResponder)
            }
        }
    }

    func focusableViews() -> [NSView] {
        var views: [NSView] = [header]
        views.append(contentsOf: self.content.focusableControls())
        return views
    }

    func wireFocusTraversal() {
        let views = self.focusableViews()
        guard !views.isEmpty else { return }
        for index in views.indices {
            views[index].nextKeyView = views[(index + 1) % views.count]
        }
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        self.header.accessibilityCustomActions()
    }

    private func accessibilityModuleLabel(for moduleID: AmpXModuleID) -> String {
        switch moduleID {
        case .player: "Player"
        case .equalizer: "Equalizer"
        case .playlist: "Playlist"
        case .enthea: "ENTHEA"
        }
    }
}
