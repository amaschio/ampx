import AppKit
import CoreGraphics
import QuartzCore

/// Live spectrum columns sampled from `AudioFeatureBus` at display rate.
final class SpectrumWellView: AmpXContinuousView {
    struct Reference: Equatable {
        /// Normalized 0…1 level per column.
        var levels: [Float]
        /// Normalized 0…1 peak-hold level per column.
        var peaks: [Float]
    }

    /// Display-only levels for deterministic reference presentation; `nil` draws live analysis.
    var reference: Reference? {
        didSet { needsDisplay = true }
    }

    private let segmentCount = AmpXSpectrumColumnModel.segmentCount
    private let columnCount = AmpXSpectrumColumnModel.columnCount
    private var peakTracker = SpectrumPeakTracker()
    private var columnPeaks = Array(repeating: AmpXSpectrumColumnModel(), count: AmpXSpectrumColumnModel.columnCount)
    private var columnLevels = [Float](repeating: 0, count: AmpXSpectrumColumnModel.columnCount)
    private var columnPeakLevels = [Float](repeating: 0, count: AmpXSpectrumColumnModel.columnCount)
    private var lastTimestamp: TimeInterval?

    /// Bottom-to-top segment colors sampled from the reference columns.
    private static let segmentColors: [NSColor] = [
        NSColor(srgbRed: 28 / 255, green: 247 / 255, blue: 6 / 255, alpha: 1),
        NSColor(srgbRed: 139 / 255, green: 233 / 255, blue: 1 / 255, alpha: 1),
        NSColor(srgbRed: 250 / 255, green: 242 / 255, blue: 6 / 255, alpha: 1),
        NSColor(srgbRed: 250 / 255, green: 227 / 255, blue: 8 / 255, alpha: 1),
        NSColor(srgbRed: 244 / 255, green: 180 / 255, blue: 0, alpha: 1),
        NSColor(srgbRed: 252 / 255, green: 170 / 255, blue: 2 / 255, alpha: 1),
    ]

    override func tick(at time: TimeInterval) {
        let deltaTime: Float = if let lastTimestamp {
            Float(max(time - lastTimestamp, 0))
        } else {
            1.0 / 60.0
        }
        self.lastTimestamp = time

        let snapshot = AudioFeatureBus.shared.spectrumSnapshot(at: time)
        let smoothed = self.peakTracker.update(
            targets: snapshot.targets,
            isPlaying: snapshot.isPlaying,
            deltaTime: deltaTime
        )

        for column in 0 ..< self.columnCount {
            let bandIndex = Self.bandIndex(forColumn: column)
            let level = smoothed.bars[bandIndex]
            self.columnLevels[column] = level
            self.columnPeakLevels[column] = self.columnPeaks[column].updatePeak(level: level, at: time)
        }

        setNeedsDisplay(bounds)
    }

    /// Spectrum area in this view's coordinates (the view is placed on the display well).
    var spectrumRect: CGRect {
        AmpXMetrics.playerSpectrum.offsetBy(dx: -AmpXMetrics.playerDisplayWell.minX, dy: -AmpXMetrics.playerDisplayWell.minY)
    }

    func segmentRect(column: Int, segment: Int) -> CGRect {
        let area = self.spectrumRect
        let top = area.minY + CGFloat(self.segmentCount - 1 - segment) * AmpXMetrics.spectrumSegmentPitch
        return CGRect(
            x: area.minX + CGFloat(column) * AmpXMetrics.spectrumColumnPitch,
            y: top,
            width: AmpXMetrics.spectrumColumnWidth,
            height: AmpXMetrics.spectrumSegmentHeight
        )
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let levels = self.reference?.levels ?? self.columnLevels
        let peaks = self.reference?.peaks ?? self.columnPeakLevels

        for column in 0 ..< min(self.columnCount, levels.count) {
            self.drawColumn(column, level: levels[column], peak: column < peaks.count ? peaks[column] : 0, context: context)
        }

        let labelColor = NSColor(srgbRed: 133 / 255, green: 148 / 255, blue: 179 / 255, alpha: 1)
        let origin = AmpXMetrics.playerDisplayWell.origin
        for (text, ink) in [("L", AmpXMetrics.playerChannelLabelL), ("R", AmpXMetrics.playerChannelLabelR)] {
            let label = AmpXLabel(text: text, color: labelColor, fontSize: 19, weight: .semibold)
            let font = label.font(skin: skin)
            label.draw(
                x: ink.minX - origin.x - 1.4,
                baseline: ink.minY - origin.y + font.capHeight,
                context: context,
                skin: skin
            )
        }
    }

    private func drawColumn(_ column: Int, level: Float, peak: Float, context: CGContext) {
        let lit = CGFloat(min(max(level, 0), 1)) * CGFloat(self.segmentCount)
        let fullSegments = Int(lit)
        for segment in 0 ..< min(fullSegments, self.segmentCount) {
            context.setFillColor(Self.segmentColors[segment].cgColor)
            context.fill(self.segmentRect(column: column, segment: segment))
        }

        let partial = lit - CGFloat(fullSegments)
        if fullSegments < self.segmentCount, partial > 0.08 {
            let slot = self.segmentRect(column: column, segment: fullSegments)
            let height = max(1, slot.height * partial)
            context.setFillColor(Self.segmentColors[fullSegments].cgColor)
            context.fill(CGRect(x: slot.minX, y: slot.maxY - height, width: slot.width, height: height))
        }

        let peakLevel = CGFloat(min(max(peak, 0), 1)) * CGFloat(self.segmentCount)
        guard peakLevel > lit + 0.25 else { return }
        let peakSegment = min(segmentCount - 1, max(0, Int(peakLevel.rounded(.up)) - 1))
        let slot = self.segmentRect(column: column, segment: peakSegment)
        context.setFillColor(Self.segmentColors[peakSegment].withAlphaComponent(0.8).cgColor)
        context.fill(CGRect(x: slot.minX + 0.25, y: slot.minY, width: 2, height: 1.5))
        context.fill(CGRect(x: slot.maxX - 2.25, y: slot.minY, width: 2, height: 1.5))
    }

    private static func bandIndex(forColumn column: Int) -> Int {
        min(
            AudioFeatures.spectrumBandCount - 1,
            (column * AudioFeatures.spectrumBandCount) / AmpXSpectrumColumnModel.columnCount
        )
    }
}
