import AppKit

class AmpXControlView: AmpXDrawingView {
    var isEnabled = true {
        didSet { needsDisplay = true }
    }

    var showsFocusRing = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { isEnabled }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden else { return nil }
        let expanded = AmpXControlMath.expandedHitRect(for: bounds)
        return expanded.contains(point) ? self : nil
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            showsFocusRing = true
            revealInStackViewportIfNeeded()
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            showsFocusRing = false
        }
        return resigned
    }

    func drawFocusRing(in context: CGContext, backingScale: CGFloat) {
        guard showsFocusRing else { return }
        let ring = bounds.insetBy(dx: -2, dy: -2)
        let aligned = AmpXPixelGrid.strokeRect(ring, lineWidth: 1, backingScale: backingScale)
        context.setStrokeColor(skin.green.cgColor)
        context.setLineWidth(1 / backingScale)
        context.stroke(aligned)
    }

    private func revealInStackViewportIfNeeded() {
        var ancestor: NSView? = superview
        while let view = ancestor {
            if let stackView = view as? AmpXModuleStackView,
               let viewport = stackView.superview as? AmpXStackViewport
            {
                viewport.reveal(convert(bounds, to: stackView))
                return
            }
            ancestor = view.superview
        }
    }
}
