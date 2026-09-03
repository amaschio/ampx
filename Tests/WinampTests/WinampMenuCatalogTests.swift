@testable import Winamp
import XCTest

final class WinampMenuCatalogTests: XCTestCase {
    func testFileItemsIncludeAddAndPlaylistIO() {
        XCTAssertEqual(
            WinampMenuCatalog.FileItem.allCases.map(\.rawValue),
            [
                "Add Files…",
                "Add Folder…",
                "Load Playlist…",
                "Save Playlist…",
            ]
        )
    }

    func testPlaybackItemsIncludeTransportAndToggles() {
        XCTAssertEqual(
            WinampMenuCatalog.PlaybackItem.allCases.map(\.rawValue),
            [
                "Play/Pause",
                "Stop",
                "Previous Track",
                "Next Track",
                "Shuffle",
                "Repeat",
            ]
        )
    }

    func testViewPanelsMatchClassicChrome() {
        XCTAssertEqual(
            WinampMenuCatalog.ViewPanel.allCases.map(\.rawValue),
            ["Equalizer", "Playlist", "Visualizer"]
        )
    }

    func testUIScaleLivesUnderViewNotTopLevelZoom() {
        XCTAssertEqual(WinampMenuCatalog.uiScaleMenuTitle, "UI Scale")
        XCTAssertFalse(
            WinampMenuCatalog.uiScaleMenuTitle.localizedCaseInsensitiveContains("Zoom"),
            "UI scale must not reuse the Window → Zoom name"
        )
    }

    func testFileShortcutsMatchClassicHotkeysWithoutCommand() {
        XCTAssertEqual(WinampMenuCatalog.FileShortcut.addFilesKey, "l")
        XCTAssertFalse(WinampMenuCatalog.FileShortcut.addFilesUsesCommand)
        XCTAssertFalse(WinampMenuCatalog.FileShortcut.addFilesUsesShift)
        XCTAssertTrue(WinampMenuCatalog.FileShortcut.addFolderUsesShift)
        XCTAssertFalse(WinampMenuCatalog.FileShortcut.addFolderUsesCommand)
    }
}
