import AppKit
import CoreGraphics

final class AmpXSlider: AmpXControlView {
    var value: Double = 0 {
        didSet { needsDisplay = true }
    }

    var range: ClosedRange<Double> = 0 ... 1 {
        didSet { needsDisplay = true }
    }

    var step: Double = 0 {
        didSet { needsDisplay = true }
    }

    var onChange: ((Double) -> Void)?
    var isVertical = false {
        didSet { needsDisplay = true }
    }

    var showsGradient = false {
        didSet { needsDisplay = true }
    }

    var showsThumbGrip = false {
        didSet { needsDisplay = true }
    }

    var accessibilityTitle: String?

    private var isDragging = false

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        setAccessibilityRole(.slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ newValue: Double, sendChange: Bool) {
        let clamped = AmpXControlMath.value(fraction: AmpXControlMath.fraction(value: newValue, range: range), range: range, step: step)
        value = clamped
        if sendChange {
            onChange?(clamped)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        let track = bounds

        skin.displayWell(track, in: context, backingScale: backingScale)

        if showsGradient {
            drawGradient(in: context, track: track)
        }

        let thumb = thumbRect(in: track)
        skin.bevel(thumb, in: context, backingScale: backingScale)
        context.setFillColor(skin.panelLight.cgColor)
        context.fill(thumb.insetBy(dx: 1, dy: 1))

        if showsThumbGrip {
            context.setFillColor(skin.borderDark.cgColor)
            context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY - 1, width: thumb.width - 4, height: 1))
            context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY + 1, width: thumb.width - 4, height: 1))
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(track)
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isDragging = true
        updateValue(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, isDragging else { return }
        updateValue(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else { return }
        let delta = event.deltaY != 0 ? event.deltaY : event.deltaX
        guard delta != 0 else { return }
        let increment = step > 0 ? step : (range.upperBound - range.lowerBound) / 100
        let direction = isVertical ? -delta : delta
        setValue(value + Double(direction) * increment, sendChange: true)
    }

    override func accessibilityLabel() -> String? {
        accessibilityTitle ?? super.accessibilityLabel()
    }

    override func accessibilityValue() -> Any? {
        value
    }

    override func accessibilityMinValue() -> Any? {
        range.lowerBound
    }

    override func accessibilityMaxValue() -> Any? {
        range.upperBound
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        let increment = step > 0 ? step : 1
        setValue(value + increment, sendChange: true)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        let increment = step > 0 ? step : 1
        setValue(value - increment, sendChange: true)
        return true
    }

    private func updateValue(for point: CGPoint) {
        let fraction = isVertical
            ? AmpXControlMath.verticalFraction(point: point, track: bounds)
            : AmpXControlMath.horizontalFraction(point: point, track: bounds)
        let next = AmpXControlMath.value(fraction: fraction, range: range, step: step)
        value = next
        onChange?(next)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    private func thumbRect(in track: CGRect) -> CGRect {
        let fraction = AmpXControlMath.fraction(value: value, range: range)
        if isVertical {
            let thumbHeight: CGFloat = 8
            let travel = track.height - thumbHeight
            let centerY = track.minY + (1 - CGFloat(fraction)) * travel + thumbHeight / 2
            return CGRect(
                x: track.midX - 5,
                y: centerY - thumbHeight / 2,
                width: 10,
                height: thumbHeight
            )
        }

        let thumbWidth: CGFloat = 8
        let travel = track.width - thumbWidth
        let centerX = track.minX + CGFloat(fraction) * travel + thumbWidth / 2
        return CGRect(
            x: centerX - thumbWidth / 2,
            y: track.minY + 1,
            width: thumbWidth,
            height: track.height - 2
        )
    }

    private func drawGradient(in context: CGContext, track: CGRect) {
        let colors: CFArray
        let start: CGPoint
        let end: CGPoint
        if isVertical {
            colors = [skin.orange.cgColor, skin.yellow.cgColor, skin.green.cgColor] as CFArray
            start = CGPoint(x: track.midX, y: track.minY)
            end = CGPoint(x: track.midX, y: track.maxY)
        } else if range.lowerBound < 0 {
            colors = [skin.green.cgColor, skin.yellow.cgColor, skin.orange.cgColor] as CFArray
            start = CGPoint(x: track.minX, y: track.midY)
            end = CGPoint(x: track.maxX, y: track.midY)
        } else {
            colors = [skin.green.cgColor, skin.yellow.cgColor, skin.orange.cgColor] as CFArray
            start = CGPoint(x: track.minX, y: track.midY)
            end = CGPoint(x: track.maxX, y: track.midY)
        }

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.5, 1]
        ) else { return }

        context.saveGState()
        context.clip(to: track.insetBy(dx: 1, dy: 1))
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }
}
