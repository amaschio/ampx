@testable import AmpX
import QuartzCore
import XCTest

@MainActor
final class EQCurveViewTests: XCTestCase {
    private func makeView() -> EQCurveView {
        let view = EQCurveView(skin: ClassicModernSkin())
        view.frame = AmpXMetrics.eqCurveFrame
        return view
    }

    func testAnimatedSetCurveReachesTargetValues() {
        let view = self.makeView()
        let bands: [Float] = [1, 0.5, 0.25, 0, -1, -0.5, 0, 0, 0.75, 1]

        view.setCurve(bandValues: bands, preampValue: 0.5, animated: true)
        view.animationTick(at: CACurrentMediaTime() + EQCurveView.animationDuration * 2)

        XCTAssertEqual(view.displayedBandValues, bands, "Animated updates must land on the slider values")
        XCTAssertEqual(view.displayedPreampValue, 0.5)
    }

    func testAnimatedSetCurveInterpolatesFromPreviousValues() {
        let view = self.makeView()
        view.setCurve(bandValues: Array(repeating: 1, count: AmpXEQBands.bandCount), preampValue: 0, animated: false)

        view.setCurve(bandValues: Array(repeating: 0, count: AmpXEQBands.bandCount), preampValue: 0, animated: true)
        XCTAssertGreaterThan(view.displayedBandValues[0], 0.5, "Right after the request the curve still shows the old values")

        view.animationTick(at: CACurrentMediaTime() + EQCurveView.animationDuration)
        XCTAssertEqual(view.displayedBandValues[0], 0, accuracy: 0.001)
    }

    func testTickBeforeAnimationStartDoesNotMoveCurveBackwards() {
        let view = self.makeView()
        view.setCurve(bandValues: Array(repeating: 0, count: AmpXEQBands.bandCount), preampValue: 0, animated: false)

        view.setCurve(bandValues: Array(repeating: 1, count: AmpXEQBands.bandCount), preampValue: 0, animated: true)
        // `CADisplayLink.timestamp` is the previous frame's time, so the first link tick can
        // predate the start of the animation.
        view.animationTick(at: CACurrentMediaTime() - EQCurveView.animationDuration)

        XCTAssertGreaterThanOrEqual(view.displayedBandValues[0], 0, "Raising a band must never dip the curve first")
    }

    func testEdgeKnotsFollowFirstAndLastBands() {
        var bands = Array(repeating: Float(0), count: AmpXEQBands.bandCount)
        bands[0] = 1
        bands[bands.count - 1] = -1
        let points = EQCurveView.knotPoints(bandValues: bands, preampValue: 0, size: AmpXMetrics.eqCurveFrame.size)

        XCTAssertEqual(points.first?.y ?? 0, points[1].y, accuracy: 0.001)
        XCTAssertEqual(points.last?.y ?? 0, points[points.count - 2].y, accuracy: 0.001)
    }

    func testImmediateSetCurveAppliesWithoutAnimation() {
        let view = self.makeView()
        let bands: [Float] = Array(repeating: -0.5, count: AmpXEQBands.bandCount)
        view.setCurve(bandValues: bands, preampValue: -0.25, animated: false)
        XCTAssertEqual(view.displayedBandValues, bands)
        XCTAssertEqual(view.displayedPreampValue, -0.25)
    }
}
