import AppKit

final class AmpXModuleHeaderView: AmpXDrawingView {
    let moduleID: AmpXModuleID
    var onCollapse: (() -> Void)?
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?
    var onGripMouseDown: ((NSEvent) -> Void)?
    var onGripMouseDragged: ((NSEvent) -> Void)?
    var onGripMouseUp: ((NSEvent) -> Void)?

    private var gripTracking = false

    init(moduleID: AmpXModuleID, skin: any AmpXSkin) {
        self.moduleID = moduleID
        super.init(skin: skin)
        setAccessibilityRole(.group)
        setAccessibilityLabel(moduleTitle(for: moduleID))
        setAccessibilityHelp("Module header")
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var gripFrame: CGRect {
        let backingScale = window?.backingScaleFactor ?? 1
        let gripWidth: CGFloat = 12
        let gripHeight: CGFloat = 16
        return CGRect(
            x: bounds.minX + 6,
            y: AmpXPixelGrid.align(bounds.midY - gripHeight / 2, backingScale: backingScale),
            width: gripWidth,
            height: gripHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.bevel(bounds, in: context, backingScale: backingScale)

        let accentHeight = max(1 / backingScale, 2 / backingScale)
        skin.accentLine(
            CGRect(x: bounds.minX, y: bounds.maxY - accentHeight, width: bounds.width, height: accentHeight),
            in: context,
            backingScale: backingScale
        )

        drawGrip(in: context, backingScale: backingScale)
        drawTitle(in: context)
        drawButtons(in: context, backingScale: backingScale)
    }

    private func drawGrip(in context: CGContext, backingScale: CGFloat) {
        let gripRect = gripFrame
        context.setFillColor(skin.border.cgColor)
        for row in 0..<3 {
            let y = gripRect.minY + CGFloat(row) * 5
            context.fill(CGRect(x: gripRect.minX, y: y, width: gripRect.width, height: 1 / backingScale))
        }
    }

    private func drawTitle(in context: CGContext) {
        let title = moduleTitle(for: moduleID)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: skin.font(size: 11, weight: .semibold),
            .foregroundColor: skin.text,
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: bounds.minX + 24,
            y: bounds.midY - size.height / 2
        )
        (title as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func drawButtons(in context: CGContext, backingScale: CGFloat) {
        let buttonSize = CGSize(width: 16, height: 14)
        var x = bounds.maxX - 8 - buttonSize.width

        if moduleID == .player {
            drawButton(
                label: "—",
                frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
                in: context,
                backingScale: backingScale
            )
            x -= buttonSize.width + 4
        }

        drawButton(
            label: "▢",
            frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
            in: context,
            backingScale: backingScale
        )
        x -= buttonSize.width + 4

        drawButton(
            label: "✕",
            frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
            in: context,
            backingScale: backingScale
        )
    }

    private func drawButton(
        label: String,
        frame: CGRect,
        in context: CGContext,
        backingScale: CGFloat
    ) {
        skin.inset(frame, in: context, backingScale: backingScale)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: skin.font(size: 9, weight: .medium),
            .foregroundColor: skin.textDim,
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        (label as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func moduleTitle(for moduleID: AmpXModuleID) -> String {
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

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if gripFrame.contains(point) {
            gripTracking = true
            onGripMouseDown?(event)
            return
        }

        let buttonFrames = headerButtonFrames()
        if let closeFrame = buttonFrames.close, closeFrame.contains(point) {
            return
        }
        if let collapseFrame = buttonFrames.collapse, collapseFrame.contains(point) {
            return
        }
        if let minimizeFrame = buttonFrames.minimize, minimizeFrame.contains(point) {
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

        let point = convert(event.locationInWindow, from: nil)
        let buttonFrames = headerButtonFrames()

        if let closeFrame = buttonFrames.close, closeFrame.contains(point) {
            onClose?()
            return
        }
        if let collapseFrame = buttonFrames.collapse, collapseFrame.contains(point) {
            onCollapse?()
            return
        }
        if let minimizeFrame = buttonFrames.minimize, minimizeFrame.contains(point) {
            onMinimize?()
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

    var onDetach: (() -> Void)?

    private func headerButtonFrames() -> (close: CGRect?, collapse: CGRect?, minimize: CGRect?) {
        let buttonSize = CGSize(width: 16, height: 14)
        var x = bounds.maxX - 8 - buttonSize.width
        let y = bounds.midY - buttonSize.height / 2

        let close = CGRect(x: x, y: y, width: buttonSize.width, height: buttonSize.height)
        x -= buttonSize.width + 4

        let collapse = CGRect(x: x, y: y, width: buttonSize.width, height: buttonSize.height)
        x -= buttonSize.width + 4

        let minimize: CGRect?
        if moduleID == .player {
            minimize = CGRect(x: x, y: y, width: buttonSize.width, height: buttonSize.height)
        } else {
            minimize = nil
        }

        return (close, collapse, minimize)
    }
}
