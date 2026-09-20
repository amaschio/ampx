@testable import AmpX
import XCTest

@MainActor
final class PlaylistChromeActionsTests: XCTestCase {
    private var manager: PlaylistManager!
    private var player: MockAudioPlayer!

    override func setUp() {
        super.setUp()
        self.player = MockAudioPlayer()
        self.manager = PlaylistManager(
            audioPlayer: self.player,
            restoreBookmarks: false,
            restorePlaylist: false,
            alertPresenter: SilentPlaylistAlertPresenter()
        )
    }

    private func track(_ name: String) -> Track {
        Track(title: name, artist: "A", url: URL(fileURLWithPath: "/tmp/\(name).wav"))
    }

    func testRemoveSelectedIsNoOpWhenEmpty() {
        self.manager.addTracks([self.track("a"), self.track("b")])
        var selection = PlaylistSelectionModel()
        PlaylistChromeActions.removeSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.count, 2)
    }

    func testRemoveSelectedRemovesAndPrunes() {
        let a = self.track("a")
        let b = self.track("b")
        let c = self.track("c")
        self.manager.addTracks([a, b, c])
        var selection = PlaylistSelectionModel()
        selection.selectOnly(b.id)
        PlaylistChromeActions.removeSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.map(\.title), ["a", "c"])
        XCTAssertFalse(selection.selectedIDs.contains(b.id))
    }

    func testCropKeepsOnlySelected() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        var selection = PlaylistSelectionModel()
        selection.selectedIDs = [tracks[0].id, tracks[2].id]
        PlaylistChromeActions.cropToSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.map(\.title), ["a", "c"])
    }

    func testClearListEmptiesTracksAndSelection() {
        self.manager.addTracks([self.track("a")])
        var selection = PlaylistSelectionModel()
        selection.selectOnly(self.manager.tracks[0].id)
        PlaylistChromeActions.clearList(manager: self.manager, selection: &selection)
        XCTAssertTrue(self.manager.tracks.isEmpty)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
    }

    func testSelectAllNoneInvert() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        var selection = PlaylistSelectionModel()
        PlaylistChromeActions.selectAll(tracks: self.manager.tracks, selection: &selection)
        XCTAssertEqual(selection.selectedIDs.count, 3)
        PlaylistChromeActions.selectNone(selection: &selection)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
        selection.selectOnly(tracks[1].id)
        PlaylistChromeActions.invertSelection(tracks: self.manager.tracks, selection: &selection)
        XCTAssertEqual(selection.selectedIDs, Set([tracks[0].id, tracks[2].id]))
    }

    func testFileInfoIndexPrefersFirstSelectedInOrder() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        self.manager.playTrack(at: 2)
        var selection = PlaylistSelectionModel()
        selection.selectedIDs = [tracks[2].id, tracks[0].id]
        let index = PlaylistChromeActions.fileInfoIndex(
            tracks: self.manager.tracks,
            selection: selection,
            currentIndex: self.manager.currentIndex
        )
        XCTAssertEqual(index, 0)
    }

    func testFileInfoIndexFallsBackToCurrent() {
        let tracks = [self.track("a"), self.track("b")]
        self.manager.addTracks(tracks)
        self.manager.playTrack(at: 1)
        let index = PlaylistChromeActions.fileInfoIndex(
            tracks: self.manager.tracks,
            selection: PlaylistSelectionModel(),
            currentIndex: 1
        )
        XCTAssertEqual(index, 1)
    }
}
