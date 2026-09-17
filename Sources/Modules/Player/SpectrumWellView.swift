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

    /// Live spectrum source. Injectable so tests drive deterministic data instead of the shared bus,
    /// which any playing `AudioPlayer` can update from its audio thread.
    var spectrumSource: (TimeInterval) -> (targets: [Float], isPlaying: Bool) = { time in
        AudioFeatureBus.shared.spectrumSnapshot(at: time)
    }

    /// Spectrum plus waveform, read in one go for oscilloscope mode.
    var featureSource: (TimeInterval, Int) -> AudioFeatures = { time, waveformSampleCount in
        AudioFeatureBus.shared.snapshot(at: time, waveformSampleCount: waveformSampleCount)
    }

    /// Which mini visualizer mode draws. Clicking the well cycles it.
    var mode: VisualizationMode = .bars {
        didSet { needsDisplay = true }
    }

    /// Receives the new mode after a click cycled it, for persistence.
    var onModeChanged: ((VisualizationMode) -> Void)?

    /// Classic behavior: a double-click shows or hides the visualizer.
    var onDoubleClick: (() -> Void)?

    /// Peak-hold marks are an analyzer-mode feature.
    static func drawsPeakMarks(in mode: VisualizationMode) -> Bool {
        mode == .analyzer
    }

    /// The waveform line replaces the columns in oscilloscope mode.
    static func drawsScopeLine(in mode: VisualizationMode) -> Bool {
        mode == .oscilloscope
    }

    /// Downsamples a mono waveform to one level per polyline point. The shared sampler quantizes to
    /// Metal's clip space, where a positive sample is negative, so the sign is flipped for drawing.
    static func scopeLevels(fromWaveform waveform: [Float], width: CGFloat) -> [Float] {
        OscilloscopeColumnSampler
            .columns(from: waveform, count: AmpXScopeLineLayout.columnCount(forWidth: width))
            .map { -$0 }
    }

    /// A click cycles the mode, but only once AppKit can no longer turn it into a double-click,
    /// so opening the visualizer never also advances the mode.
    override func mouseDown(with event: NSEvent) {
        self.pendingModeCycle?.cancel()
        self.pendingModeCycle = nil

        guard event.clickCount < 2 else {
            self.onDoubleClick?()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingModeCycle = nil
            let next = self.mode.advanced()
            self.mode = next
            self.onModeChanged?(next)
        }
        self.pendingModeCycle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
    }

    private let segmentCount = AmpXSpectrumColumnModel.segmentCount
    private let columnCount = AmpXSpectrumColumnModel.columnCount
    private var pipeline = AmpXSpectrumColumnPipeline()
    private var idleGate = VisualizerIdleGate()
    private var pendingModeCycle: DispatchWorkItem?
    private var scopeLineLevels: [Float] = []
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

        let frame: AmpXSpectrumColumnPipeline.Frame
        if Self.drawsScopeLine(in: self.mode) {
            // Scope mode also needs the waveform, so take one combined snapshot.
            let features = self.featureSource(time, AudioFeatures.scopeWaveformSampleCount)
            let mono = zip(features.waveformLeft, features.waveformRight).map { ($0 + $1) * 0.5 }
            self.scopeLineLevels = Self.scopeLevels(fromWaveform: mono, width: self.spectrumRect.width)
            frame = self.pipeline.update(
                bands: features.spectrum,
                isPlaying: features.isPlaying,
                deltaTime: deltaTime
            )
        } else {
            let snapshot = self.spectrumSource(time)
            frame = self.pipeline.update(
                bands: snapshot.targets,
                isPlaying: snapshot.isPlaying,
                deltaTime: deltaTime
            )
        }
        self.columnLevels = frame.levels
        self.columnPeakLevels = frame.peaks

        setNeedsDisplay(bounds)

        // Park the link only after the final decayed frame has been requested, so the well freezes
        // on an empty display rather than mid-decay. `PlayerModuleContent` wakes it on playback.
        self.setContinuousRenderingPaused(
            self.idleGate.update(isActive: frame.isActive, deltaTime: CFTimeInterval(deltaTime))
        )
    }

    /// Resumes a parked well on a genuine external event (playback started). Only this clears the
    /// idle window: the tick loop must never reset it, or the well could never reach the hold time.
    func wakeRendering() {
        self.idleGate.wake()
        self.setContinuousRenderingPaused(false)
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

        if Self.drawsScopeLine(in: self.mode), self.reference == nil {
            self.drawScopeLine(in: context)
        } else {
            for column in 0 ..< min(self.columnCount, levels.count) {
                self.drawColumn(column, level: levels[column], peak: column < peaks.count ? peaks[column] : 0, context: context)
            }
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

    /// One-point-per-column waveform line, zero amplitude on the centre of the spectrum area.
    private func drawScopeLine(in context: CGContext) {
        let points = AmpXScopeLineLayout.points(levels: self.scopeLineLevels, in: self.spectrumRect)
        guard points.count > 1 else { return }

        context.setStrokeColor(skin.green.cgColor)
        context.setLineWidth(1)
        context.setLineJoin(.round)
        context.addLines(between: points)
        context.strokePath()
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

        guard Self.drawsPeakMarks(in: self.mode) else { return }
        let peakLevel = CGFloat(min(max(peak, 0), 1)) * CGFloat(self.segmentCount)
        guard peakLevel > lit + 0.25 else { return }
        let peakSegment = min(segmentCount - 1, max(0, Int(peakLevel.rounded(.up)) - 1))
        let slot = self.segmentRect(column: column, segment: peakSegment)
        context.setFillColor(Self.segmentColors[peakSegment].withAlphaComponent(0.8).cgColor)
        context.fill(CGRect(x: slot.minX + 0.25, y: slot.minY, width: 2, height: 1.5))
        context.fill(CGRect(x: slot.maxX - 2.25, y: slot.minY, width: 2, height: 1.5))
    }
}
