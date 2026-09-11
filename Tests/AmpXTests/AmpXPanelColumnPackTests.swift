import CoreGraphics
import XCTest
@testable import AmpX

final class AmpXPanelColumnPackTests: XCTestCase {
    func testVisualizerNeverJoinsVerticalPackEvenWhenLeftAligned() {
        XCTAssertFalse(
            AmpXPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .visualizer,
                forcing: nil,
                sameColumn: true,
                sideOfMain: false
            )
        )
        XCTAssertFalse(
            AmpXPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .visualizer,
                forcing: .visualizer,
                sameColumn: true,
                sideOfMain: false
            )
        )
    }

    func testEqualizerJoinsWhenInColumnOrForced() {
        XCTAssertTrue(
            AmpXPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: nil,
                sameColumn: true,
                sideOfMain: false
            )
        )
        XCTAssertTrue(
            AmpXPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: .equalizer,
                sameColumn: false,
                sideOfMain: false
            )
        )
        XCTAssertFalse(
            AmpXPanelColumnPack.shouldIncludeInVerticalPack(
                panelID: .equalizer,
                forcing: nil,
                sameColumn: false,
                sideOfMain: true
            )
        )
    }

    func testPackedWidthPreservesPlaylistAndLocksOthersToMain() {
        XCTAssertEqual(
            AmpXPanelColumnPack.packedWidth(panelID: .playlist, currentWidth: 400, mainWidth: 275),
            400
        )
        XCTAssertEqual(
            AmpXPanelColumnPack.packedWidth(panelID: .equalizer, currentWidth: 400, mainWidth: 275),
            275
        )
        XCTAssertEqual(
            AmpXPanelColumnPack.packedWidth(panelID: .visualizer, currentWidth: 600, mainWidth: 275),
            275
        )
    }
}

final class AmpXDockGraphDescendantTests: XCTestCase {
    func testDescendantsFollowParentChain() {
        let parents: [AmpXPanelID: AmpXDockNode] = [
            .equalizer: .main,
            .playlist: .panel(.equalizer),
            .visualizer: .main,
        ]
        XCTAssertEqual(
            Set(AmpXDockGraph.descendants(of: .equalizer, parents: parents)),
            [.playlist]
        )
        XCTAssertTrue(AmpXDockGraph.descendants(of: .playlist, parents: parents).isEmpty)
        XCTAssertTrue(AmpXDockGraph.descendants(of: .visualizer, parents: parents).isEmpty)
    }
}
