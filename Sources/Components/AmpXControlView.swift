import AppKit

class AmpXControlView: AmpXDrawingView {
    var isEnabled = true {
        didSet { needsDisplay = true }
    }

    var showsFocusRing = false {
        didSet { needsDisplay = true }
    }

    /// Keyboard navigation can focus a control, but a click cannot, so global shortcuts keep working
    /// after mouse use. AppKit's current event is what identifies the click.
    static func acceptsFocus(isEnabled: Bool, currentEventType: NSEvent.EventType?) -> Bool {
        guard isEnabled else { return false }
        switch currentEventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return false
        default:
            return true
        }
    }

    override var acceptsFirstResponder: Bool {
        Self.acceptsFocus(isEnabled: self.isEnabled, currentEventType: NSApp.currentEvent?.type)
    }

    /// `point` is in the superview's coordinate system; the expanded hit area is tested in local coordinates.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard self.isEnabled, !isHidden else { return nil }
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        let expanded = AmpXControlMath.expandedHitRect(for: bounds)
        return expanded.contains(localPoint) ? self : nil
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            self.showsFocusRing = true
            self.noteFocusedModuleIfNeeded()
        }
        return became
    }

    private func noteFocusedModuleIfNeeded() {
        var ancestor: NSView? = superview
        while let view = ancestor {
            if let moduleView = view as? AmpXModuleView,
               let coordinator = findCoordinator(in: window)
            {
                coordinator.noteFocusedModule(moduleView.moduleID)
                return
            }
            ancestor = view.superview
        }
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

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            self.showsFocusRing = false
        }
        return resigned
    }

    func drawFocusRing(in context: CGContext, backingScale: CGFloat) {
        guard self.showsFocusRing else { return }
        let ring = bounds.insetBy(dx: -2, dy: -2)
        let aligned = AmpXPixelGrid.strokeRect(ring, lineWidth: 1, backingScale: backingScale)
        context.setStrokeColor(skin.green.cgColor)
        context.setLineWidth(1 / backingScale)
        context.stroke(aligned)
    }
}
