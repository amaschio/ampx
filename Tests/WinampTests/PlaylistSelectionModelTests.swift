@testable import Winamp
import XCTest

final class PlaylistSelectionModelTests: XCTestCase {
    private let ids: [UUID] = (0 ..< 10).map { _ in UUID() }

    func testSelectOnlyReplacesSelectionAndSetsAnchor() {
        var model = PlaylistSelectionModel()
        model.selectOnly(self.ids[2])
        model.selectOnly(self.ids[5])
        XCTAssertEqual(model.selectedIDs, [self.ids[5]])
        XCTAssertEqual(model.anchorID, self.ids[5])
        XCTAssertEqual(model.cursorID, self.ids[5])
    }

    func testToggleAddsAndRemoves() {
        var model = PlaylistSelectionModel()
        model.toggle(self.ids[1])
        model.toggle(self.ids[3])
        XCTAssertEqual(model.selectedIDs, [self.ids[1], self.ids[3]])
        model.toggle(self.ids[1])
        XCTAssertEqual(model.selectedIDs, [self.ids[3]])
        XCTAssertEqual(model.cursorID, self.ids[1])
    }

    func testSelectRangeFromAnchor() {
        var model = PlaylistSelectionModel()
        model.selectOnly(self.ids[2])
        model.selectRange(to: self.ids[5], orderedIDs: self.ids)
        XCTAssertEqual(model.selectedIDs, Set(self.ids[2 ... 5]))
        XCTAssertEqual(model.anchorID, self.ids[2])
        XCTAssertEqual(model.cursorID, self.ids[5])
    }

    func testMoveCursorWithoutExtendSelectsOnly() {
        var model = PlaylistSelectionModel()
        model.selectOnly(self.ids[2])
        model.moveCursor(by: 2, extend: false, orderedIDs: self.ids)
        XCTAssertEqual(model.selectedIDs, [self.ids[4]])
        XCTAssertEqual(model.cursorID, self.ids[4])
    }

    func testMoveCursorWithExtendGrowsRange() {
        var model = PlaylistSelectionModel()
        model.selectOnly(self.ids[2])
        model.moveCursor(by: 2, extend: true, orderedIDs: self.ids)
        XCTAssertEqual(model.selectedIDs, Set(self.ids[2 ... 4]))
        XCTAssertEqual(model.anchorID, self.ids[2])
    }

    func testSelectAllAndInvert() {
        var model = PlaylistSelectionModel()
        model.selectOnly(self.ids[1])
        model.selectAll(orderedIDs: self.ids)
        XCTAssertEqual(model.selectedIDs.count, 10)
        model.invert(orderedIDs: self.ids)
        XCTAssertTrue(model.selectedIDs.isEmpty)
        model.invert(orderedIDs: Array(self.ids.prefix(3)))
        XCTAssertEqual(model.selectedIDs, Set(self.ids.prefix(3)))
    }

    func testPageStepIsOneFifthAtLeastOne() {
        XCTAssertEqual(PlaylistSelectionModel.pageStep(count: 0), 1)
        XCTAssertEqual(PlaylistSelectionModel.pageStep(count: 4), 1)
        XCTAssertEqual(PlaylistSelectionModel.pageStep(count: 10), 2)
        XCTAssertEqual(PlaylistSelectionModel.pageStep(count: 25), 5)
    }
}
