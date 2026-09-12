import AppKit

final class AmpXModuleHeaderView: AmpXDrawingView {
    enum HeaderButton {
        case minimize, collapse, close
    }

    let moduleID: AmpXModuleID
    var onCollapse: (() -> Void)?
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?
    var onDetach: (() -> Void)?
    var onGripMouseDown: ((NSEvent) -> Void)?
    var onGripMouseDragged: ((NSEvent) -> Void)?
    var onGripMouseUp: ((NSEvent) -> Void)?

    private var gripTracking = false

    init(moduleID: AmpXModuleID, skin: any AmpXSkin) {
        self.moduleID = moduleID
        super.init(skin: skin)
        setAccessibilityRole(.group)
        setAccessibilityLabel(accessibilityTitle(for: moduleID))
        setAccessibilityHelp("Module header")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became, let coordinator = findCoordinator(in: window) {
            coordinator.noteFocusedModule(moduleID)
        }
        return became
    }

    private func findCoordinator(in window: NSWindow?) -> AmpXHostCoordinator? {
        guard let window else { return nil }
        if let stack = window.windowController as? AmpXStackWindowController {
            return stack.coordinator
        }
        if let detached = window.windowController as? AmpXDetachedModuleWindowController {
            return detached.coordinator
        }
        return nil
    }

    // MARK: - Geometry (reference coordinates scaled with the module width)

    private var scale: CGFloat {
        bounds.width / AmpXMetrics.compositionWidth
    }

    private func scaled(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }

    /// Drag handle around the left pulse decoration; stops short of the gold rules.
    var gripFrame: CGRect {
        scaled(CGRect(x: 4, y: 2, width: 29, height: 24.5))
    }

    func headerButtonLayout() -> [(button: HeaderButton, frame: CGRect)] {
        var layout: [(button: HeaderButton, frame: CGRect)] = []
        if moduleID == .player {
            layout.append((.minimize, scaled(AmpXMetrics.headerMinimizeButton)))
        }
        layout.append((.collapse, scaled(AmpXMetrics.headerCollapseButton)))
        layout.append((.close, scaled(AmpXMetrics.headerCloseButton)))
        return layout
    }

    private var brandLabel: AmpXLabel {
        AmpXLabel(text: "AmpX", color: skin.text, fontSize: 20 * scale, weight: .semibold, tracking: 0.8 * scale)
    }

    private var moduleTitleLabel: AmpXLabel? {
        let title: String? = switch moduleID {
        case .player: nil
        case .equalizer: "EQUALIZER"
        case .playlist: "PLAYLIST"
        case .enthea: "ENTHEA"
        }
        return title.map {
            AmpXLabel(text: $0, color: skin.text, fontSize: 15 * scale, weight: .regular, tracking: 1.2 * scale)
        }
    }

    /// Horizontal extent of the centered brand/title group.
    var titleGroupFrame: CGRect {
        let brandWidth = brandLabel.measuredSize(skin: skin).width
        let titleWidth = moduleTitleLabel.map { $0.measuredSize(skin: skin).width + 20 * scale } ?? 0
        let width = brandWidth + titleWidth
        return CGRect(
            x: AmpXMetrics.headerTitleCenterX * scale - width / 2,
            y: AmpXMetrics.headerBrandInkTop * scale,
            width: width,
            height: 18 * scale
        )
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        AmpXIcon.grip.draw(
            in: scaled(AmpXMetrics.headerGripGlyph),
            context: context,
            skin: skin,
            color: NSColor(srgbRed: 1, green: 0.8, blue: 0.08, alpha: 1)
        )
        drawTitleAndRules(in: context, backingScale: backingScale)
        for item in headerButtonLayout() {
            drawButton(item.button, frame: item.frame, in: context, backingScale: backingScale)
        }
    }

    private func drawTitleAndRules(in context: CGContext, backingScale: CGFloat) {
        let group = titleGroupFrame
        let ruleY = AmpXMetrics.headerRuleY * scale
        let ruleHeight = AmpXMetrics.headerRuleHeight * scale
        let leftMaxX = group.minX - AmpXMetrics.headerRuleGapBeforeTitle * scale
        let rightMinX = group.maxX + AmpXMetrics.headerRuleGapAfterTitle * scale
        let leftMinX = AmpXMetrics.headerRuleMinX * scale
        skin.headerRule(
            CGRect(x: leftMinX, y: ruleY, width: leftMaxX - leftMinX, height: ruleHeight),
            in: context,
            backingScale: backingScale
        )
        skin.headerRule(
            CGRect(x: rightMinX, y: ruleY, width: AmpXMetrics.headerRuleMaxX * scale - rightMinX, height: ruleHeight),
            in: context,
            backingScale: backingScale
        )

        let brand = brandLabel
        let brandFont = brand.font(skin: skin)
        let baseline = group.minY + brandFont.capHeight
        brand.draw(x: group.minX, baseline: baseline, context: context, skin: skin)
        if let title = moduleTitleLabel {
            let titleX = group.minX + brand.measuredSize(skin: skin).width + 20 * scale
            title.draw(x: titleX, baseline: baseline, context: context, skin: skin)
        }
    }

    private func drawButton(_ button: HeaderButton, frame: CGRect, in context: CGContext, backingScale: CGFloat) {
        skin.raisedFace(frame, style: .normal, in: context, backingScale: backingScale)
        let icon: AmpXIcon
        let glyphRect: CGRect
        let color: NSColor
        switch button {
        case .minimize:
            icon = .minimize
            glyphRect = AmpXMetrics.headerMinimizeGlyph
            color = NSColor(srgbRed: 0.95, green: 0.69, blue: 0.08, alpha: 1)
        case .collapse:
            icon = .collapse
            glyphRect = AmpXMetrics.headerCollapseGlyph
            color = NSColor(srgbRed: 0.84, green: 0.87, blue: 0.92, alpha: 1)
        case .close:
            icon = .close
            glyphRect = AmpXMetrics.headerCloseGlyph
            color = NSColor(srgbRed: 0.95, green: 0.63, blue: 0.08, alpha: 1)
        }
        icon.draw(
            in: scaled(glyphRect).offsetBy(dx: frame.minX, dy: frame.minY),
            context: context,
            skin: skin,
            color: color
        )
    }

    private func accessibilityTitle(for moduleID: AmpXModuleID) -> String {
        switch moduleID {
        case .player:
            return "AmpX"
        case .equalizer:
            return "Equalizer"
        case .playlist:
            return "Playlist"
        case .enthea:
            return "ENTHEA"
        }
    }

    // MARK: - Interaction

    private func headerButton(at point: CGPoint) -> HeaderButton? {
        headerButtonLayout().first { $0.frame.contains(point) }?.button
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if gripFrame.contains(point) {
            gripTracking = true
            onGripMouseDown?(event)
            return
        }

        if headerButton(at: point) != nil {
            return
        }

        window?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard gripTracking else { return }
        onGripMouseDragged?(event)
    }

    override func mouseUp(with event: NSEvent) {
        if gripTracking {
            gripTracking = false
            onGripMouseUp?(event)
            return
        }

        switch headerButton(at: convert(event.locationInWindow, from: nil)) {
        case .close:
            onClose?()
        case .collapse:
            onCollapse?()
        case .minimize:
            onMinimize?()
        case nil:
            break
        }
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        var actions: [NSAccessibilityCustomAction] = []

        if moduleID != .player {
            actions.append(NSAccessibilityCustomAction(name: "Detach", target: self, selector: #selector(accessibilityDetach)))
        } else if onMinimize != nil {
            actions.append(NSAccessibilityCustomAction(name: "Minimize", target: self, selector: #selector(accessibilityMinimize)))
        }

        actions.append(NSAccessibilityCustomAction(name: "Collapse", target: self, selector: #selector(accessibilityCollapse)))
        actions.append(NSAccessibilityCustomAction(name: "Close", target: self, selector: #selector(accessibilityClose)))

        return actions
    }

    @objc func accessibilityCollapse() -> Bool {
        onCollapse?()
        return true
    }

    @objc func accessibilityClose() -> Bool {
        onClose?()
        return true
    }

    @objc func accessibilityMinimize() -> Bool {
        onMinimize?()
        return true
    }

    @objc func accessibilityDetach() -> Bool {
        onDetach?()
        return true
    }
}
