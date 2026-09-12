import AppKit
import CoreGraphics

final class AmpXScrollbar: AmpXControlView {
    var offset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var contentLength: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var viewportLength: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var onScroll: ((CGFloat) -> Void)?

    private static let arrowHeight: CGFloat = 8
    private var isDraggingThumb = false
    private var dragStartOffset: CGFloat = 0
    private var dragStartY: CGFloat = 0

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        setAccessibilityRole(.scrollBar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.displayWell(bounds, in: context, backingScale: backingScale)

        let arrowWidth = bounds.width - 4
        drawArrow(
            up: true,
            in: CGRect(x: bounds.minX + 2, y: bounds.minY + 1, width: arrowWidth, height: Self.arrowHeight),
            context: context
        )
        drawArrow(
            up: false,
            in: CGRect(
                x: bounds.minX + 2,
                y: bounds.maxY - Self.arrowHeight - 1,
                width: arrowWidth,
                height: Self.arrowHeight
            ),
            context: context
        )

        let thumb = thumbRect()
        context.setFillColor(skin.gold.cgColor)
        context.fill(thumb)
        context.setFillColor(skin.goldLight.cgColor)
        context.fill(CGRect(x: thumb.minX, y: thumb.minY, width: thumb.width, height: 1))

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(bounds)
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        let thumb = thumbRect()

        if thumb.contains(point) {
            isDraggingThumb = true
            dragStartOffset = offset
            dragStartY = point.y
            return
        }

        if upArrowRect().contains(point) {
            scrollBy(-viewportLength / 3)
            return
        }

        if downArrowRect().contains(point) {
            scrollBy(viewportLength / 3)
            return
        }

        let track = trackRect()
        guard track.contains(point) else { return }
        if point.y < thumb.midY {
            scrollBy(-viewportLength)
        } else {
            scrollBy(viewportLength)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, isDraggingThumb else { return }
        let point = convert(event.locationInWindow, from: nil)
        let track = trackRect()
        guard track.height > 0 else { return }

        let thumbHeight = thumbRect().height
        let travel = max(track.height - thumbHeight, 1)
        let maxOffset = max(contentLength - viewportLength, 0)
        let deltaY = point.y - dragStartY
        let offsetDelta = deltaY / travel * maxOffset
        setOffset(dragStartOffset + offsetDelta)
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingThumb = false
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else { return }
        scrollBy(-event.deltaY * 8)
    }

    override func accessibilityValue() -> Any? {
        offset
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        scrollBy(viewportLength / 5)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        scrollBy(-viewportLength / 5)
        return true
    }

    private func setOffset(_ newOffset: CGFloat) {
        let clamped = AmpXControlMath.clampedScrollOffset(newOffset, contentLength: contentLength, viewportLength: viewportLength)
        guard clamped != offset else { return }
        offset = clamped
        onScroll?(clamped)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    private func scrollBy(_ delta: CGFloat) {
        setOffset(offset + delta)
    }

    private func trackRect() -> CGRect {
        bounds.insetBy(dx: 0, dy: Self.arrowHeight + 2)
    }

    private func upArrowRect() -> CGRect {
        CGRect(x: bounds.minX + 2, y: bounds.minY + 1, width: bounds.width - 4, height: Self.arrowHeight)
    }

    private func downArrowRect() -> CGRect {
        CGRect(
            x: bounds.minX + 2,
            y: bounds.maxY - Self.arrowHeight - 1,
            width: bounds.width - 4,
            height: Self.arrowHeight
        )
    }

    private func thumbRect() -> CGRect {
        let track = trackRect()
        let maxOffset = max(contentLength - viewportLength, 0)
        let thumbHeight = max(
            track.height * viewportLength / max(contentLength, 1),
            12
        )
        let travel = max(track.height - thumbHeight, 0)
        let progress = maxOffset > 0 ? offset / maxOffset : 0
        let y = track.minY + progress * travel
        return CGRect(x: bounds.minX + 2, y: y, width: bounds.width - 4, height: thumbHeight)
    }

    private func drawArrow(up: Bool, in rect: CGRect, context: CGContext) {
        context.setFillColor(skin.orange.cgColor)
        let path = CGMutablePath()
        if up {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 1))
            path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 1))
        } else {
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
        }
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }
}
