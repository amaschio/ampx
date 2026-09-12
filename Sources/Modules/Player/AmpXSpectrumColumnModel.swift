import Foundation

/// Per-column spectrum level, color-band mapping, and peak-hold decay for the Player display.
struct AmpXSpectrumColumnModel {
    static let segmentCount = AmpXMetrics.spectrumSegmentCount
    static let columnCount = AmpXMetrics.spectrumColumnCount

    private static let maxBarHeight: Float = 15
    private static let peakInitialStep: Float = 3.0
    private static let peakStepGrowth: Float = 1.1

    private var peakScaled: Float = 0
    private var peakStep: Float = 0
    private var lastTimestamp: TimeInterval?

    static func litCount(level: Float, segmentCount: Int) -> Int {
        guard segmentCount > 0 else { return 0 }
        let clamped = min(max(level, 0), 1)
        return Int((clamped * Float(segmentCount)).rounded())
    }

    static func colorBand(segment: Int, count: Int) -> Int {
        let ratio = Float(segment) / Float(max(count - 1, 1))
        if ratio < 0.45 {
            return 0
        }
        if ratio < 0.75 {
            return 1
        }
        return 2
    }

    mutating func updatePeak(level: Float, at time: TimeInterval) -> Float {
        let clamped = min(max(level, 0), 1)
        let deltaTime: Float = if let lastTimestamp {
            Float(max(time - lastTimestamp, 0))
        } else {
            1.0 / 60.0
        }
        self.lastTimestamp = time

        let frameScale = min(max(deltaTime * 60, 0), 4)
        let scaledBar = clamped * Self.maxBarHeight * 256

        if self.peakScaled <= scaledBar {
            self.peakScaled = scaledBar
            self.peakStep = Self.peakInitialStep
        }

        self.peakScaled -= round(self.peakStep * frameScale)
        self.peakStep *= pow(Self.peakStepGrowth, frameScale)
        if self.peakScaled <= 0 {
            self.peakScaled = 0
        }

        return (self.peakScaled / 256) / Self.maxBarHeight
    }
}
