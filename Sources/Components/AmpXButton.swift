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

    /// Active state is shown as a depressed face (e.g. Play while playing).
    var showsActiveFace = false {
        didSet { needsDisplay = true }
    }

    var style: Style = .bevel {
        didSet { needsDisplay = true }
    }

    /// Measured content layout in bounds coordinates; `nil` values center the content.
    var labelBaselineOrigin: CGPoint? {
        didSet { needsDisplay = true }
    }

    var labelFontSize: CGFloat? {
        didSet { needsDisplay = true }
    }

    var labelWeight: NSFont.Weight = .semibold {
        didSet { needsDisplay = true }
    }

    var iconRect: CGRect? {
        didSet { needsDisplay = true }
    }

    var indicatorRect: CGRect? {
        didSet { needsDisplay = true }
    }

    /// Display-only active state for deterministic reference presentation.
    var displayActiveOverride: Bool? {
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

    private var displaysActive: Bool {
        displayActiveOverride ?? isActive
    }

    private var labelLines: [String] {
        label?.components(separatedBy: "\n") ?? []
    }

    var labelFont: NSFont {
        skin.font(size: labelFontSize ?? (labelLines.count > 1 ? 7 : 8), weight: labelWeight)
    }

    /// Typographic box of the label lines; never narrower than one line height.
    var labelRect: CGRect {
        let font = labelFont
        let lineHeight = font.ascender - font.descender
        let blockHeight = lineHeight * CGFloat(max(labelLines.count, 1))
        let width = labelLines.map { measuredWidth(of: $0) }.max() ?? 0
        if let origin = labelBaselineOrigin {
            return CGRect(x: origin.x, y: origin.y - font.ascender, width: width, height: blockHeight)
        }
        let height = min(blockHeight, bounds.height)
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    var resolvedIconRect: CGRect {
        if let iconRect { return iconRect }
        let area = bounds.insetBy(dx: 8, dy: 8)
        return area.insetBy(dx: area.width * 0.28, dy: area.height * 0.28)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        let faceStyle: AmpXFaceStyle = switch style {
        case .menu: .menu
        case .bevel where isPressed || (showsActiveFace && displaysActive): .pressed
        case .bevel where isHovered && isEnabled: .hovered
        case .bevel: .normal
        }
        skin.raisedFace(bounds, style: faceStyle, in: context, backingScale: backingScale)
        if style == .menu, isPressed {
            context.setFillColor(skin.borderDark.withAlphaComponent(0.25).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if label != nil {
            drawLabel(in: context)
        }

        if let icon {
            let tint = iconColor ?? (displaysActive ? skin.green : skin.text)
            icon.draw(in: resolvedIconRect, context: context, skin: skin, color: isEnabled ? tint : skin.textDim)
        }

        if showsActiveIndicator {
            drawIndicator(in: context)
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    private func drawLabel(in context: CGContext) {
        let font = labelFont
        let color = isEnabled ? skin.text : skin.textDim
        let rect = labelRect
        let lineHeight = font.ascender - font.descender
        for (index, line) in labelLines.enumerated() {
            let baseline = rect.minY + font.ascender + CGFloat(index) * lineHeight
            if labelBaselineOrigin != nil {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: labelWeight)
                    .draw(x: rect.minX, baseline: baseline, context: context, skin: skin)
            } else {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: labelWeight, alignment: .center)
                    .draw(x: bounds.midX, baseline: baseline, context: context, skin: skin)
            }
        }
    }

    private func drawIndicator(in context: CGContext) {
        guard let lamp = indicatorRect else {
            let indicator = CGRect(x: bounds.maxX - 7, y: bounds.midY - 2, width: 4, height: 4)
            if displaysActive {
                context.setFillColor(skin.green.cgColor)
                context.fill(indicator)
            } else {
                context.setFillColor(skin.textDim.cgColor)
                context.fillEllipse(in: indicator)
            }
            return
        }

        context.setFillColor(NSColor(srgbRed: 0.02, green: 0.05, blue: 0.04, alpha: 1).cgColor)
        context.fill(lamp)
        let inner = lamp.insetBy(dx: 1, dy: 1)
        if displaysActive {
            context.setFillColor(NSColor(srgbRed: 0.10, green: 0.78, blue: 0.08, alpha: 1).cgColor)
            context.fill(inner)
            context.setFillColor(NSColor(srgbRed: 0.28, green: 0.94, blue: 0.20, alpha: 1).cgColor)
            context.fill(inner.insetBy(dx: 0.5, dy: 0.5))
            context.setFillColor(NSColor(srgbRed: 0.62, green: 1, blue: 0.52, alpha: 1).cgColor)
            context.fill(CGRect(x: inner.minX + 0.5, y: inner.minY + 0.5, width: inner.width - 1, height: 0.5))
        } else {
            context.setFillColor(NSColor(srgbRed: 0.17, green: 0.2, blue: 0.25, alpha: 1).cgColor)
            context.fill(inner)
        }
    }

    private func measuredWidth(of text: String) -> CGFloat {
        AmpXLabel(text: text, color: skin.text, fontSize: labelFont.pointSize, weight: labelWeight)
            .measuredSize(skin: skin).width
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
