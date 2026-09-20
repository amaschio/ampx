@testable import AmpX
import XCTest

final class AmpXEQBandsTests: XCTestCase {
    func testDisplayLabelsMatchBandCount() {
        XCTAssertEqual(AmpXEQBands.displayLabels.count, AmpXEQBands.bandCount)
        XCTAssertEqual(AmpXEQBands.centerFrequenciesHz.count, AmpXEQBands.bandCount)
    }

    func testBandCenterXAlignsWithEvenSpacing() {
        let width: CGFloat = 300
        let first = AmpXEQBands.bandCenterX(bandIndex: 0, width: width)
        let last = AmpXEQBands.bandCenterX(bandIndex: 9, width: width)
        XCTAssertEqual(first, width / 20, accuracy: 0.001)
        XCTAssertEqual(last, width * 19 / 20, accuracy: 0.001)
    }

    func testBandwidthsCountMatchesBands() {
        XCTAssertEqual(AmpXEQBands.bandwidthsOctaves.count, AmpXEQBands.bandCount)
    }

    func testBandwidthsStayWithinAVAudioUnitEQLimits() {
        for bw in AmpXEQBands.bandwidthsOctaves {
            XCTAssertGreaterThanOrEqual(bw, 0.05)
            XCTAssertLessThanOrEqual(bw, 5.0)
        }
    }

    func testCloselySpacedTopBandsHaveNarrowerBandwidthThanLowBands() {
        // 60/170/310 Hz are spaced over an octave apart; 12k/14k/16k are <¼ octave apart.
        // Deriving bandwidth from neighbour spacing should make the top bands much narrower,
        // preventing the overlap that let three boosted treble bands stack past +12 dB.
        let lowBand = AmpXEQBands.bandwidthsOctaves[1] // 170 Hz
        let topBand = AmpXEQBands.bandwidthsOctaves[8] // 14 kHz
        XCTAssertLessThan(topBand, lowBand)
    }

    func testResponseCurveEndpointsFollowPreamp() {
        let points = AmpXEQBands.responseCurvePoints(
            bandValues: Array(repeating: 0, count: 10),
            preampValue: 0.25,
            width: 200,
            height: 40
        )
        XCTAssertEqual(points.first?.x, 0)
        XCTAssertEqual(points.last?.x, 200)
        let startY = points.first?.y ?? 0
        let endY = points.last?.y ?? 0
        XCTAssertEqual(startY, endY, accuracy: 0.001)
    }
}
