@testable import AmpX
import XCTest

/// Classic behavior: clicking the mini visualizer cycles its modes and the choice persists;
/// double-clicking opens the visualizer instead. Peak marks belong to the analyzer mode only.
@MainActor
final class AmpXMiniVisualizerModeTests: XCTestCase {
    func testPeakMarksBelongToAnalyzerModeOnly() {
        XCTAssertFalse(SpectrumWellView.drawsPeakMarks(in: .bars))
        XCTAssertTrue(SpectrumWellView.drawsPeakMarks(in: .analyzer))
        XCTAssertFalse(SpectrumWellView.drawsPeakMarks(in: .oscilloscope))
    }

    func testClickCyclesToTheNextModeAndReportsIt() {
        let well = SpectrumWellView(skin: ClassicModernSkin())
        well.mode = .bars
        var reported: [VisualizationMode] = []
        well.onModeChanged = { reported.append($0) }

        well.mouseDown(with: self.click(count: 1))
        self.waitForMainQueue(after: NSEvent.doubleClickInterval + 0.05)

        XCTAssertEqual(well.mode, .oscilloscope)
        XCTAssertEqual(reported, [.oscilloscope])
    }

    func testDoubleClickOpensVisualizerAndNeverCyclesTheMode() {
        let well = SpectrumWellView(skin: ClassicModernSkin())
        well.mode = .bars
        var opened = 0
        var reported: [VisualizationMode] = []
        well.onDoubleClick = { opened += 1 }
        well.onModeChanged = { reported.append($0) }

        // AppKit delivers the first click of a double-click as clickCount 1.
        well.mouseDown(with: self.click(count: 1))
        well.mouseDown(with: self.click(count: 2))
        self.waitForMainQueue(after: NSEvent.doubleClickInterval + 0.05)

        XCTAssertEqual(opened, 1)
        XCTAssertEqual(well.mode, .bars)
        XCTAssertEqual(reported, [])
    }

    func testModeStoreDefaultsToBarsAndRoundTrips() throws {
        let suite = "AmpXMiniVisualizerModeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        self.addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = AmpXMiniVisualizerModeStore(defaults: defaults)

        XCTAssertEqual(store.load(), .bars)

        store.save(.analyzer)

        XCTAssertEqual(store.load(), .analyzer)
        XCTAssertEqual(
            defaults.integer(forKey: "visualizationMode"),
            VisualizationMode.analyzer.storageValue,
            "must reuse the key the SwiftUI player stored, so an existing choice carries over"
        )
    }

    private func click(count: Int) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: CGPoint(x: 40, y: 20),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: count,
            pressure: 1
        )!
    }
}
