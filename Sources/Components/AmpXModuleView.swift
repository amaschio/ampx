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

    override var isFlipped: Bool {
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

        let headerHeight = AmpXMetrics.headerHeight * (frame.width / AmpXMetrics.compositionWidth)
        self.header.frame = CGRect(x: 0, y: 0, width: snappedFrame.width, height: headerHeight)
        self.content.frame = CGRect(
            x: 0,
            y: headerHeight,
            width: snappedFrame.width,
            height: max(0, snappedFrame.height - headerHeight)
        )
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
