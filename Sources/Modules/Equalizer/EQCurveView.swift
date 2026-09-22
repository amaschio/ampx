import AppKit
import CoreGraphics
import QuartzCore

/// Animated EQ response curve using the classic Catmull-Rom spline.
final class EQCurveView: AmpXDrawingView {
    static let animationDuration: TimeInterval = 0.075

    struct Reference: Equatable {
        /// Normalized −1…1 band gains.
        var bandValues: [Float]
        /// Normalized −1…1 preamp gain.
        var preampValue: Float
    }

    /// Display-only curve for deterministic reference presentation; `nil` draws the animated live curve.
    var reference: Reference? {
        didSet { needsDisplay = true }
    }

    /// Sampled from the reference curve stroke.
    private static let curveColor = NSColor(srgbRed: 246 / 255, green: 182 / 255, blue: 6 / 255, alpha: 1)
    private static let knotColor = NSColor(srgbRed: 1, green: 206 / 255, blue: 20 / 255, alpha: 1)

    /// Values currently drawn; lag `target*` while an animation is in flight. Internal for tests.
    private(set) var displayedBandValues = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
    private(set) var displayedPreampValue: Float = 0
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
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Curve knots in a view of `size`: preamp edge knots at the view edges and band knots at the
    /// measured pitch, with heights from `AmpXEQBands.responseCurvePoints`.
    static func knotPoints(bandValues: [Float], preampValue: Float, size: CGSize) -> [CGPoint] {
        let span = AmpXMetrics.eqCurveBandPitch * CGFloat(AmpXEQBands.bandCount)
        let origin = AmpXMetrics.eqCurveFirstBandOffset - AmpXMetrics.eqCurveBandPitch / 2
        var points = AmpXEQBands.responseCurvePoints(
            bandValues: bandValues,
            preampValue: preampValue,
            width: span,
            height: size.height
        )
        guard points.count >= 2 else { return points }
        for index in points.indices {
            points[index].x += origin
        }
        points[0].x = 0
        points[points.count - 1].x = size.width
        return points
    }

    func setCurve(bandValues: [Float], preampValue: Float, animated: Bool) {
        let bands = self.normalizedBands(from: bandValues)
        if !animated {
            self.stopAnimation()
            self.displayedBandValues = bands
            self.displayedPreampValue = preampValue
            self.targetBandValues = bands
            self.targetPreampValue = preampValue
            needsDisplay = true
            return
        }

        self.animationFromBands = self.displayedBandValues
        self.animationFromPreamp = self.displayedPreampValue
        self.targetBandValues = bands
        self.targetPreampValue = preampValue
        self.animationStartTime = CACurrentMediaTime()
        self.startAnimation()
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let points = Self.knotPoints(
            bandValues: self.reference.map { self.normalizedBands(from: $0.bandValues) } ?? self.displayedBandValues,
            preampValue: self.reference?.preampValue ?? self.displayedPreampValue,
            size: bounds.size
        )
        guard points.count >= 2 else { return }

        context.saveGState()
        context.addPath(CatmullRomSpline.path(through: points).cgPath)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(Self.curveColor.cgColor)
        context.strokePath()
        context.setFillColor(Self.knotColor.cgColor)
        for point in points {
            context.fillEllipse(in: CGRect(x: point.x - 1.6, y: point.y - 1.6, width: 3.2, height: 3.2))
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
        // Only replace the display link here. `stopAnimation()` would also clear
        // `animationStartTime`, which `setCurve` has just set; with it nil every tick
        // returned early, so the curve never left its launch values and the link ran forever.
        self.stopDisplayLink()

        let forwarder = EQCurveAnimationForwarder()
        forwarder.view = self
        self.animationForwarder = forwarder

        let link = displayLink(
            target: forwarder,
            selector: #selector(EQCurveAnimationForwarder.displayLinkFired(_:))
        )
        self.animationLink = link
        link.add(to: .main, forMode: .common)
        self.animationTick(at: CACurrentMediaTime())
    }

    func animationTick(at time: TimeInterval) {
        guard let start = animationStartTime else { return }
        // `CADisplayLink.timestamp` is the previous frame's time and can predate `start`; a
        // negative progress would extrapolate away from the target (a raised band dipped first).
        let progress = max(0, min(1, (time - start) / Self.animationDuration))
        self.displayedBandValues = zip(self.animationFromBands, self.targetBandValues).map { from, to in
            from + (to - from) * Float(progress)
        }
        self.displayedPreampValue = self.animationFromPreamp + (self.targetPreampValue - self.animationFromPreamp) * Float(progress)
        setNeedsDisplay(bounds)

        if progress >= 1 {
            self.finishAnimation()
        }
    }

    private func finishAnimation() {
        self.displayedBandValues = self.targetBandValues
        self.displayedPreampValue = self.targetPreampValue
        self.stopAnimation()
        needsDisplay = true
    }

    private func stopAnimation() {
        self.stopDisplayLink()
        self.animationStartTime = nil
    }

    private func stopDisplayLink() {
        self.animationLink?.invalidate()
        self.animationLink = nil
        self.animationForwarder = nil
    }
}

/// Deliberately not `@MainActor`: AppKit calls this `@objc` selector from its display-link callback
/// without a Swift task, and on macOS 26 an isolated entry point traps in
/// `swift_task_isCurrentExecutor`. The link runs on the main run loop, so hopping is safe.
/// Deliberately not `@MainActor`, and the work hops through a real `Task`: AppKit calls this `@objc`
/// selector from its display-link callback with no Swift task, and on macOS 26 the executor check
/// then crashes in `swift_task_isCurrentExecutor` — both at an isolated entry point and inside
/// `MainActor.assumeIsolated`. Entering a task gives the check a valid context (see commit 5562af8).
private final class EQCurveAnimationForwarder: NSObject {
    nonisolated(unsafe) weak var view: EQCurveView?

    @objc func displayLinkFired(_ link: CADisplayLink) {
        // Only the timestamp crosses the boundary; `CADisplayLink` is not Sendable.
        let timestamp = link.timestamp
        let view = self.view
        Task { @MainActor in
            view?.animationTick(at: timestamp)
        }
    }
}
