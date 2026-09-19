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
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var displaysActive: Bool {
        self.displayActiveOverride ?? self.isActive
    }

    private var labelLines: [String] {
        self.label?.components(separatedBy: "\n") ?? []
    }

    var labelFont: NSFont {
        skin.font(size: self.labelFontSize ?? (self.labelLines.count > 1 ? 7 : 8), weight: self.labelWeight)
    }

    /// Typographic box of the label lines; never narrower than one line height.
    var labelRect: CGRect {
        let font = self.labelFont
        let lineHeight = font.ascender - font.descender
        let blockHeight = lineHeight * CGFloat(max(self.labelLines.count, 1))
        let width = self.labelLines.map { self.measuredWidth(of: $0) }.max() ?? 0
        if let origin = labelBaselineOrigin {
            return CGRect(x: origin.x, y: origin.y - font.ascender, width: width, height: blockHeight)
        }
        let height = min(blockHeight, bounds.height)
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    var resolvedIconRect: CGRect {
        if let iconRect {
            return iconRect
        }
        let area = bounds.insetBy(dx: 8, dy: 8)
        return area.insetBy(dx: area.width * 0.28, dy: area.height * 0.28)
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        let faceStyle: AmpXFaceStyle = switch self.style {
        case .menu: .menu
        case .bevel where self.isPressed || (self.showsActiveFace && self.displaysActive): .pressed
        case .bevel where isHovered && isEnabled: .hovered
        case .bevel: .normal
        }
        skin.raisedFace(bounds, style: faceStyle, in: context, backingScale: backingScale)
        if self.style == .menu, self.isPressed {
            context.setFillColor(skin.borderDark.withAlphaComponent(0.25).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if self.label != nil {
            self.drawLabel(in: context)
        }

        if let icon {
            let tint = self.iconColor ?? (self.displaysActive ? skin.green : skin.text)
            icon.draw(in: self.resolvedIconRect, context: context, skin: skin, color: isEnabled ? tint : skin.textDim)
        }

        if self.showsActiveIndicator {
            self.drawIndicator(in: context)
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    private func drawLabel(in context: CGContext) {
        let font = self.labelFont
        let color = isEnabled ? skin.text : skin.textDim
        let rect = self.labelRect
        let lineHeight = font.ascender - font.descender
        for (index, line) in self.labelLines.enumerated() {
            let baseline = rect.minY + font.ascender + CGFloat(index) * lineHeight
            if self.labelBaselineOrigin != nil {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: self.labelWeight)
                    .draw(x: rect.minX, baseline: baseline, context: context, skin: skin)
            } else {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: self.labelWeight, alignment: .center)
                    .draw(x: bounds.midX, baseline: baseline, context: context, skin: skin)
            }
        }
    }

    private func drawIndicator(in context: CGContext) {
        guard let lamp = indicatorRect else {
            let indicator = CGRect(x: bounds.maxX - 7, y: bounds.midY - 2, width: 4, height: 4)
            if self.displaysActive {
                context.setFillColor(skin.green.cgColor)
                context.fill(indicator)
            } else {
                context.setFillColor(skin.textDim.cgColor)
                context.fillEllipse(in: indicator)
            }
            return
        }

        guard self.displaysActive else {
            self.drawInactiveLamp(in: lamp, context: context)
            return
        }
        context.setFillColor(NSColor(srgbRed: 0.02, green: 0.05, blue: 0.04, alpha: 1).cgColor)
        context.fill(lamp)
        let inner = lamp.insetBy(dx: 1, dy: 1)
        if self.displaysActive {
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

    /// Unlit lamp: a round steel-gray dome, as the reference AUTO indicator.
    private func drawInactiveLamp(in lamp: CGRect, context: CGContext) {
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
            NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1).cgColor
        }
        context.setFillColor(color(62, 76, 100))
        context.fillEllipse(in: lamp.offsetBy(dx: 0.5, dy: 0.75))
        context.setFillColor(color(8, 15, 28))
        context.fillEllipse(in: lamp)
        let dome = lamp.insetBy(dx: 0.75, dy: 0.75)
        context.saveGState()
        context.addEllipse(in: dome)
        context.clip()
        if let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [color(104, 117, 139), color(150, 163, 183), color(170, 183, 200)] as CFArray,
            locations: [0, 0.6, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: dome.minX, y: dome.minY),
                end: CGPoint(x: dome.maxX, y: dome.maxY),
                options: []
            )
        }
        context.restoreGState()
    }

    private func measuredWidth(of text: String) -> CGFloat {
        AmpXLabel(text: text, color: skin.text, fontSize: self.labelFont.pointSize, weight: self.labelWeight)
            .measuredSize(skin: skin).width
    }

    override func mouseDown(with _: NSEvent) {
        guard isEnabled else { return }
        self.isPressed = true
    }

    override func cancelInteraction() {
        self.pressResetWorkItem?.cancel()
        self.pressResetWorkItem = nil
        self.isPressed = false
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let shouldFire = self.isPressed && isEnabled && bounds.contains(point)
        if shouldFire {
            self.action?()
            self.schedulePressReset()
        } else {
            self.isPressed = false
        }
    }

    /// Presses the button from the keyboard (Return/Enter while focused). Space stays global play/pause.
    @discardableResult
    func performKeyboardPress() -> Bool {
        guard isEnabled else { return false }
        self.action?()
        self.isPressed = true
        self.schedulePressReset()
        return true
    }

    override func accessibilityLabel() -> String? {
        self.accessibilityTitle ?? self.label ?? super.accessibilityLabel()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        self.action?()
        self.isPressed = true
        self.schedulePressReset()
        return true
    }

    private func schedulePressReset() {
        self.pressResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isPressed = false
        }
        self.pressResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AmpXControlMath.buttonPressDuration, execute: work)
    }
}
