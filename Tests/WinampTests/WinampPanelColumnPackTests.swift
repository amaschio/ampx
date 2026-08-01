import CoreGraphics
import XCTest
@testable import Winamp

final class WinampPanelColumnPackTests: XCTestCase {
    func testVisualizerNeverJoinsVerticalPackEvenWhenLeftAligned() {
        XCTAssertFalse(
            WinampPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .visualizer,
                forcing: nil,
                sameColumn: true,
                sideOfMain: false
            )
        )
        XCTAssertFalse(
            WinampPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .visualizer,
                forcing: .visualizer,
                sameColumn: true,
                sideOfMain: false
            )
        )
    }

    func testEqualizerJoinsWhenInColumnOrForced() {
        XCTAssertTrue(
            WinampPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: nil,
                sameColumn: true,
                sideOfMain: false
            )
        )
        XCTAssertTrue(
            WinampPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: .equalizer,
                sameColumn: false,
                sideOfMain: false
            )
        )
        XCTAssertFalse(
            WinampPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: nil,
                sameColumn: false,
                sideOfMain: true
            )
        )
    }

    func testPackedWidthPreservesPlaylistAndLocksOthersToMain() {
        XCTAssertEqual(
            WinampPanelColumnPack.packedWidth(panelID: .playlist, currentWidth: 400, mainWidth: 275),
            400
        )
        XCTAssertEqual(
            WinampPanelColumnPack.packedWidth(panelID: .equalizer, currentWidth: 400, mainWidth: 275),
            275
        )
        XCTAssertEqual(
            WinampPanelColumnPack.packedWidth(panelID: .visualizer, currentWidth: 600, mainWidth: 275),
            275
        )
    }
}

final class WinampDockGraphDescendantTests: XCTestCase {
    func testDescendantsFollowParentChain() {
        let parents: [WinampPanelID: WinampDockNode] = [
            .equalizer: .main,
            .playlist: .panel(.equalizer),
            .visualizer: .main,
        ]
        XCTAssertEqual(
            Set(WinampDockGraph.descendants(of: .equalizer, parents: parents)),
            [.playlist]
        )
        XCTAssertTrue(WinampDockGraph.descendants(of: .playlist, parents: parents).isEmpty)
        XCTAssertTrue(WinampDockGraph.descendants(of: .visualizer, parents: parents).isEmpty)
    }
}
