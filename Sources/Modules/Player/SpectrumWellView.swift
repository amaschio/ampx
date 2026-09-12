import AppKit
import CoreGraphics
import QuartzCore

/// Live L/R spectrum columns sampled from `AudioFeatureBus` at display rate.
final class SpectrumWellView: AmpXContinuousView {
    private let segmentCount = AmpXSpectrumColumnModel.segmentCount
    private let columnCount = AmpXSpectrumColumnModel.columnCount
    private var peakTracker = SpectrumPeakTracker()
    private var columnPeaks = Array(repeating: AmpXSpectrumColumnModel(), count: AmpXSpectrumColumnModel.columnCount)
    private var columnLevels = [Float](repeating: 0, count: AmpXSpectrumColumnModel.columnCount)
    private var columnPeakLevels = [Float](repeating: 0, count: AmpXSpectrumColumnModel.columnCount)
    private var lastTimestamp: TimeInterval?

    override func tick(at time: TimeInterval) {
        let deltaTime: Float
        if let lastTimestamp {
            deltaTime = Float(max(time - lastTimestamp, 0))
        } else {
            deltaTime = 1.0 / 60.0
        }
        self.lastTimestamp = time

        let snapshot = AudioFeatureBus.shared.spectrumSnapshot(at: time)
        let smoothed = peakTracker.update(
            targets: snapshot.targets,
            isPlaying: snapshot.isPlaying,
            deltaTime: deltaTime
        )

        for column in 0 ..< columnCount {
            let bandIndex = Self.bandIndex(forColumn: column)
            let level = smoothed.bars[bandIndex]
            columnLevels[column] = level
            columnPeakLevels[column] = columnPeaks[column].updatePeak(level: level, at: time)
        }

        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let segmentHeight = AmpXMetrics.spectrumSegmentHeight
        let segmentGap = AmpXMetrics.spectrumSegmentGap
        let columnPitch = AmpXMetrics.spectrumColumnPitch
        let baseY = bounds.maxY - 6

        drawChannel(
            originX: bounds.minX + AmpXMetrics.spectrumLeftColumnX,
            baseY: baseY,
            segmentHeight: segmentHeight,
            segmentGap: segmentGap,
            columnPitch: columnPitch,
            context: context
        )
        drawChannel(
            originX: bounds.minX + AmpXMetrics.spectrumRightColumnX,
            baseY: baseY,
            segmentHeight: segmentHeight,
            segmentGap: segmentGap,
            columnPitch: columnPitch,
            context: context
        )

        AmpXLabel(text: "L", color: skin.green, fontSize: 8, weight: .semibold)
            .draw(in: CGRect(x: bounds.minX + 4, y: baseY - 44, width: 10, height: 10), context: context, skin: skin)
        AmpXLabel(text: "R", color: skin.green, fontSize: 8, weight: .semibold)
            .draw(
                in: CGRect(x: bounds.minX + AmpXMetrics.spectrumRightColumnX - 2, y: baseY - 44, width: 10, height: 10),
                context: context,
                skin: skin
            )
    }

    private func drawChannel(
        originX: CGFloat,
        baseY: CGFloat,
        segmentHeight: CGFloat,
        segmentGap: CGFloat,
        columnPitch: CGFloat,
        context: CGContext
    ) {
        for column in 0 ..< columnCount {
            let litCount = AmpXSpectrumColumnModel.litCount(
                level: columnLevels[column],
                segmentCount: segmentCount
            )
            let peakCount = AmpXSpectrumColumnModel.litCount(
                level: columnPeakLevels[column],
                segmentCount: segmentCount
            )

            let columnX = originX + CGFloat(column) * columnPitch
            for segment in 0 ..< litCount {
                let y = baseY - CGFloat(segment + 1) * (segmentHeight + segmentGap)
                context.setFillColor(spectrumColor(for: segment).cgColor)
                context.fill(CGRect(x: columnX, y: y, width: 4.5, height: segmentHeight))
            }

            if peakCount > litCount {
                let peakSegment = peakCount - 1
                let y = baseY - CGFloat(peakSegment + 1) * (segmentHeight + segmentGap)
                context.setFillColor(skin.text.cgColor)
                context.fill(CGRect(x: columnX, y: y, width: 4.5, height: segmentHeight))
            }
        }
    }

    private func spectrumColor(for segment: Int) -> NSColor {
        switch AmpXSpectrumColumnModel.colorBand(segment: segment, count: segmentCount) {
        case 0:
            return skin.green
        case 1:
            return skin.yellow
        default:
            return skin.orange
        }
    }

    private static func bandIndex(forColumn column: Int) -> Int {
        min(
            AudioFeatures.spectrumBandCount - 1,
            (column * AudioFeatures.spectrumBandCount) / AmpXSpectrumColumnModel.columnCount
        )
    }
}
