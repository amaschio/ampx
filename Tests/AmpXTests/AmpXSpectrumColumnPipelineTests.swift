@testable import AmpX
import XCTest

final class AmpXSpectrumColumnPipelineTests: XCTestCase {
    private let bandCount = AudioFeatures.spectrumBandCount
    private let columnCount = AmpXSpectrumColumnModel.columnCount

    /// Every analysis band must reach a column; sampling every second band hid half the spectrum.
    func testColumnLevelsCoverEveryBand() {
        var bands = [Float](repeating: 0, count: self.bandCount)
        for index in stride(from: 1, to: self.bandCount, by: 2) {
            bands[index] = 1
        }

        let levels = AmpXSpectrumColumnPipeline.columnLevels(fromBands: bands)

        XCTAssertEqual(levels.count, self.columnCount)
        XCTAssertEqual(levels.min(), 1, "odd-numbered bands never reached the columns")
    }

    func testColumnLevelsTakeLouderOfEachBandPair() {
        var bands = [Float](repeating: 0, count: self.bandCount)
        bands[0] = 0.25
        bands[1] = 0.75

        let levels = AmpXSpectrumColumnPipeline.columnLevels(fromBands: bands)

        XCTAssertEqual(levels[0], 0.75, accuracy: 0.0001)
    }

    /// At 60 Hz the falloff dominates, but a 120 Hz frame must show the smoother's partial attack.
    func testAttackIsSmoothedAtHighRefreshRates() {
        var pipeline = AmpXSpectrumColumnPipeline()

        let frame = pipeline.update(
            bands: [Float](repeating: 1, count: self.bandCount),
            isPlaying: true,
            deltaTime: 1.0 / 120.0
        )

        XCTAssertLessThan(frame.levels[0], 0.99)
        XCTAssertGreaterThan(frame.levels[0], 0.85)
    }

    func testPeaksHoldAboveBarsThenDecay() {
        var pipeline = AmpXSpectrumColumnPipeline()
        let loud = [Float](repeating: 1, count: self.bandCount)
        let silence = [Float](repeating: 0, count: self.bandCount)

        let first = pipeline.update(bands: loud, isPlaying: true, deltaTime: 1.0 / 60.0)
        XCTAssertEqual(first.peaks[0], 1, accuracy: 0.001)

        var frame = first
        for _ in 0 ..< 20 {
            frame = pipeline.update(bands: silence, isPlaying: true, deltaTime: 1.0 / 60.0)
        }

        XCTAssertLessThan(frame.peaks[0], first.peaks[0])
        XCTAssertGreaterThan(frame.peaks[0], frame.levels[0])
    }

    func testReportsActiveWhilePlaying() {
        var pipeline = AmpXSpectrumColumnPipeline()

        let frame = pipeline.update(
            bands: [Float](repeating: 0, count: self.bandCount),
            isPlaying: true,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertTrue(frame.isActive)
    }

    func testReportsInactiveOnceSilenceDecays() {
        var pipeline = AmpXSpectrumColumnPipeline()
        let loud = [Float](repeating: 1, count: self.bandCount)
        let silence = [Float](repeating: 0, count: self.bandCount)
        _ = pipeline.update(bands: loud, isPlaying: true, deltaTime: 1.0 / 60.0)

        var frame = pipeline.update(bands: silence, isPlaying: false, deltaTime: 1.0 / 60.0)
        XCTAssertTrue(frame.isActive, "bars still carry energy right after playback stops")

        for _ in 0 ..< 60 {
            frame = pipeline.update(bands: silence, isPlaying: false, deltaTime: 1.0 / 60.0)
        }

        XCTAssertFalse(frame.isActive)
    }
}
