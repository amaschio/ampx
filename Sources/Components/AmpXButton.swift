import AppKit
import CoreGraphics

final class AmpXButton: AmpXControlView {
    enum Style {
        case bevel
        case menu
    }

    var action: (() -> Void)?
    var isActive = false {
        didSet { needsDisplay = true }
    }

    var label: String? {
        didSet { needsDisplay = true }
    }

    var icon: AmpXIcon? {
        didSet { needsDisplay = true }
    }

    var iconColor: NSColor? {
        didSet { needsDisplay = true }
    }

    var showsActiveIndicator = false {
        didSet { needsDisplay = true }
    }

    var style: Style = .bevel {
        didSet { needsDisplay = true }
    }

    var accessibilityTitle: String?

    private(set) var isPressed = false {
        didSet { needsDisplay = true }
    }

    private var pressResetWorkItem: DispatchWorkItem?

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        switch style {
        case .bevel:
            skin.bevel(bounds, in: context, backingScale: backingScale)
            if isPressed || (isHovered && isEnabled) {
                context.setFillColor(skin.panelLight.withAlphaComponent(isPressed ? 0.35 : 0.18).cgColor)
                context.fill(bounds.insetBy(dx: 1, dy: 1))
            }
        case .menu:
            context.setFillColor(skin.orange.withAlphaComponent(isEnabled ? 1 : 0.45).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
            if isPressed {
                context.setFillColor(skin.borderDark.withAlphaComponent(0.25).cgColor)
                context.fill(bounds.insetBy(dx: 1, dy: 1))
            }
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if let label {
            let color = isEnabled ? skin.text : skin.textDim
            AmpXLabel(text: label, color: color, fontSize: label.contains("\n") ? 7 : 8, weight: .semibold, alignment: .center)
                .draw(in: bounds.insetBy(dx: 2, dy: label.contains("\n") ? 4 : 10), context: context, skin: skin)
        }

        if let icon {
            let tint = iconColor ?? (isActive ? skin.green : skin.text)
            icon.draw(
                in: bounds.insetBy(dx: 8, dy: 8),
                context: context,
                skin: skin,
                color: isEnabled ? tint : skin.textDim
            )
        }

        if showsActiveIndicator {
            let indicator = CGRect(x: bounds.maxX - 7, y: bounds.midY - 2, width: 4, height: 4)
            if isActive {
                context.setFillColor(skin.green.cgColor)
                context.fill(indicator)
            } else {
                context.setFillColor(skin.textDim.cgColor)
                context.fillEllipse(in: indicator)
            }
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let shouldFire = isEnabled && bounds.contains(point)
        if shouldFire {
            action?()
            schedulePressReset()
        } else {
            isPressed = false
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isEnabled, event.keyCode == 49 else { return false }
        action?()
        isPressed = true
        schedulePressReset()
        return true
    }

    override func accessibilityLabel() -> String? {
        accessibilityTitle ?? label ?? super.accessibilityLabel()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        action?()
        isPressed = true
        schedulePressReset()
        return true
    }

    private func schedulePressReset() {
        pressResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isPressed = false
        }
        pressResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AmpXControlMath.buttonPressDuration, execute: work)
    }
}
