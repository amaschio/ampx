import AppKit
import CoreGraphics

final class AmpXSlider: AmpXControlView {
    enum Artwork {
        /// Full-bounds well with a small bevelled thumb (Equalizer, pending its reconstruction).
        case legacy
        /// Slender pill track with a steel thumb.
        case pill(AmpXTrackFill)
        /// Recessed seek well whose bounds are the well, with a gold thumb.
        case seek
    }

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

    var artwork: Artwork = .legacy {
        didSet { needsDisplay = true }
    }

    /// Visible track size, centered in bounds. `nil` uses the full bounds.
    var trackSize: CGSize? {
        didSet { needsDisplay = true }
    }

    /// Visible thumb size. `nil` derives the legacy size from the track.
    var thumbSize: CGSize? {
        didSet { needsDisplay = true }
    }

    /// Display-only value for deterministic reference presentation; `nil` draws `value`.
    var displayValueOverride: Double? {
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

    // MARK: - Geometry shared by drawing and pointer mapping

    var trackRect: CGRect {
        guard let trackSize else { return bounds }
        return CGRect(
            x: bounds.midX - trackSize.width / 2,
            y: bounds.midY - trackSize.height / 2,
            width: trackSize.width,
            height: trackSize.height
        )
    }

    var resolvedThumbSize: CGSize {
        if let thumbSize { return thumbSize }
        let track = trackRect
        return isVertical ? CGSize(width: 10, height: 8) : CGSize(width: 8, height: max(0, track.height - 2))
    }

    /// Thumb-center displacement perpendicular to the travel axis.
    var thumbCrossOffset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    /// Thumb-center travel endpoints: minimum value first.
    var travel: (start: CGPoint, end: CGPoint) {
        let track = trackRect
        let size = resolvedThumbSize
        if isVertical {
            let x = track.midX + thumbCrossOffset
            return (CGPoint(x: x, y: track.maxY - size.height / 2), CGPoint(x: x, y: track.minY + size.height / 2))
        }
        let y = track.midY + thumbCrossOffset
        return (CGPoint(x: track.minX + size.width / 2, y: y), CGPoint(x: track.maxX - size.width / 2, y: y))
    }

    var thumbRect: CGRect {
        thumbRect(forValue: displayValueOverride ?? value)
    }

    func thumbRect(forValue value: Double) -> CGRect {
        let fraction = CGFloat(min(max(AmpXControlMath.fraction(value: value, range: range), 0), 1))
        let (start, end) = travel
        let size = resolvedThumbSize
        let center = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    func value(at point: CGPoint) -> Double {
        let (start, end) = travel
        let fraction: Double
        if isVertical {
            let span = start.y - end.y
            fraction = span > 0 ? Double((start.y - point.y) / span) : 0
        } else {
            let span = end.x - start.x
            fraction = span > 0 ? Double((point.x - start.x) / span) : 0
        }
        return AmpXControlMath.value(fraction: fraction, range: range, step: step)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        let track = trackRect
        let thumb = thumbRect

        switch artwork {
        case .legacy:
            skin.displayWell(track, in: context, backingScale: backingScale)
            if showsGradient {
                drawGradient(in: context, track: track)
            }
            skin.bevel(thumb, in: context, backingScale: backingScale)
            context.setFillColor(skin.panelLight.cgColor)
            context.fill(thumb.insetBy(dx: 1, dy: 1))
            if showsThumbGrip {
                context.setFillColor(skin.borderDark.cgColor)
                context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY - 1, width: thumb.width - 4, height: 1))
                context.fill(CGRect(x: thumb.minX + 2, y: thumb.midY + 1, width: thumb.width - 4, height: 1))
            }
        case let .pill(fill):
            skin.sliderTrack(track, fill: fill, filledThroughX: thumb.midX, in: context, backingScale: backingScale)
            skin.metallicThumb(thumb, material: .steel, in: context, backingScale: backingScale)
        case .seek:
            skin.seekWell(bounds, track: track, in: context, backingScale: backingScale)
            skin.metallicThumb(thumb, material: .gold, in: context, backingScale: backingScale)
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(track.union(thumb))
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

    @discardableResult
    func handleArrowKey(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        let increment = step > 0 ? step : (range.upperBound - range.lowerBound) / 20
        switch event.keyCode {
        case 123, 125:
            setValue(value - increment, sendChange: true)
            return true
        case 124, 126:
            setValue(value + increment, sendChange: true)
            return true
        default:
            return false
        }
    }

    private func updateValue(for point: CGPoint) {
        let next = value(at: point)
        value = next
        onChange?(next)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    private func drawGradient(in context: CGContext, track: CGRect) {
        let colors: CFArray
        let start: CGPoint
        let end: CGPoint
        if isVertical {
            colors = [skin.orange.cgColor, skin.yellow.cgColor, skin.green.cgColor] as CFArray
            start = CGPoint(x: track.midX, y: track.minY)
            end = CGPoint(x: track.midX, y: track.maxY)
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
