import Foundation

/// Turns `AudioFeatureBus` spectrum bands into the Player well's column levels and peak-hold
/// levels, owning the shared smoothing and falloff state. Pure: it never touches the bus, so the
/// band mapping, smoothing and peak behavior are unit-testable without audio.
struct AmpXSpectrumColumnPipeline {
    struct Frame: Equatable {
        /// Normalized 0…1 level per column.
        var levels: [Float]
        /// Normalized 0…1 peak-hold level per column.
        var peaks: [Float]
        /// False once playback stopped and the bars decayed to visual silence.
        var isActive: Bool
    }

    /// Level below which the columns count as visually silent (develop's mini-visualizer threshold).
    static let activityThreshold: Float = 0.002

    private var smoother = VisualizationFeatureSmoother()
    private var tracker = SpectrumPeakTracker()

    /// Folds the analysis bands into the well's columns, each column showing the louder of its bands
    /// so transients survive the 32 → 16 reduction.
    static func columnLevels(fromBands bands: [Float]) -> [Float] {
        let columns = AmpXSpectrumColumnModel.columnCount
        guard columns > 0 else { return [] }
        let bandsPerColumn = max(1, AudioFeatures.spectrumBandCount / columns)

        return (0 ..< columns).map { column in
            let start = column * bandsPerColumn
            let end = min(start + bandsPerColumn, bands.count)
            guard start < end else { return 0 }
            return bands[start ..< end].max() ?? 0
        }
    }

    mutating func update(bands: [Float], isPlaying: Bool, deltaTime: Float) -> Frame {
        // Display-rate smoothing first, then the falloff, matching the Metal mini visualizer.
        let smoothed = self.smoother.update(targets: bands, isPlaying: isPlaying, deltaTime: deltaTime)
        let tracked = self.tracker.update(targets: smoothed, isPlaying: isPlaying, deltaTime: deltaTime)
        let levels = Self.columnLevels(fromBands: tracked.bars)
        let peaks = Self.columnLevels(fromBands: tracked.peaks)

        let isActive = isPlaying || (levels.max() ?? 0) > Self.activityThreshold
        return Frame(levels: levels, peaks: peaks, isActive: isActive)
    }
}
