import AppKit
import CoreGraphics
import QuartzCore

/// Animated EQ response curve using the classic Catmull-Rom spline.
final class EQCurveView: AmpXDrawingView {
    static let animationDuration: TimeInterval = 0.075

    private var displayedBandValues = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
    private var displayedPreampValue: Float = 0
    private var targetBandValues = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
    private var targetPreampValue: Float = 0

    private var animationStartTime: TimeInterval?
    private var animationFromBands = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
    private var animationFromPreamp: Float = 0
    private var animationLink: CADisplayLink?
    private var animationForwarder: EQCurveAnimationForwarder?

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCurve(bandValues: [Float], preampValue: Float, animated: Bool) {
        let bands = normalizedBands(from: bandValues)
        if !animated {
            stopAnimation()
            displayedBandValues = bands
            displayedPreampValue = preampValue
            targetBandValues = bands
            targetPreampValue = preampValue
            needsDisplay = true
            return
        }

        animationFromBands = displayedBandValues
        animationFromPreamp = displayedPreampValue
        targetBandValues = bands
        targetPreampValue = preampValue
        animationStartTime = CACurrentMediaTime()
        startAnimation()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let points = AmpXEQBands.responseCurvePoints(
            bandValues: displayedBandValues,
            preampValue: displayedPreampValue,
            width: bounds.width,
            height: bounds.height
        )
        guard points.count >= 2 else { return }

        context.saveGState()
        context.addPath(CatmullRomSpline.path(through: points).cgPath)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        let colors = [skin.yellow.cgColor, skin.orange.cgColor] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: bounds.width, y: 0),
                options: []
            )
        }
        context.restoreGState()
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            stopAnimation()
        }
    }

    private func normalizedBands(from values: [Float]) -> [Float] {
        var bands = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
        for index in 0 ..< AmpXEQBands.bandCount where index < values.count {
            bands[index] = values[index]
        }
        return bands
    }

    private func startAnimation() {
        stopAnimation()

        let forwarder = EQCurveAnimationForwarder()
        forwarder.view = self
        animationForwarder = forwarder

        let link = displayLink(
            target: forwarder,
            selector: #selector(EQCurveAnimationForwarder.displayLinkFired(_:))
        )
        animationLink = link
        link.add(to: .main, forMode: .common)
        animationTick(at: CACurrentMediaTime())
    }

    fileprivate func animationTick(at time: TimeInterval) {
        guard let start = animationStartTime else { return }
        let progress = min(1, (time - start) / Self.animationDuration)
        displayedBandValues = zip(animationFromBands, targetBandValues).map { from, to in
            from + (to - from) * Float(progress)
        }
        displayedPreampValue = animationFromPreamp + (targetPreampValue - animationFromPreamp) * Float(progress)
        setNeedsDisplay(bounds)

        if progress >= 1 {
            finishAnimation()
        }
    }

    private func finishAnimation() {
        displayedBandValues = targetBandValues
        displayedPreampValue = targetPreampValue
        stopAnimation()
        needsDisplay = true
    }

    private func stopAnimation() {
        animationLink?.invalidate()
        animationLink = nil
        animationForwarder = nil
        animationStartTime = nil
    }
}

@MainActor
private final class EQCurveAnimationForwarder: NSObject {
    weak var view: EQCurveView?

    @objc func displayLinkFired(_ link: CADisplayLink) {
        view?.animationTick(at: link.timestamp)
    }
}
