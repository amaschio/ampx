@testable import AmpX
import XCTest

@MainActor
final class AmpXMenuBuilderTests: XCTestCase {
    private func makeApplication(tracks: [Track] = []) -> AmpXApplicationController {
        let player = AudioPlayer(installRemoteCommands: false)
        let manager = PlaylistManager(
            audioPlayer: MockAudioPlayer(),
            restoreBookmarks: false,
            restorePlaylist: false,
            alertPresenter: SilentPlaylistAlertPresenter()
        )
        manager.tracks = tracks
        let hosts = AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            audioPlayer: player,
            playlistManager: manager
        )
        return AmpXApplicationController(
            audioPlayer: player,
            playlistManager: manager,
            hosts: hosts
        )
    }

    func testMainMenuHasSingleFileMenuWithCatalogItems() throws {
        let application = makeApplication()
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        XCTAssertEqual(menu.items.filter { $0.title == "File" }.count, 1)

        let file = try XCTUnwrap(menu.item(withTitle: "File")?.submenu)
        file.update()
        XCTAssertEqual(
            file.items.filter { !$0.isSeparatorItem }.map(\.title),
            AmpXMenuCatalog.FileItem.allCases.map(\.rawValue)
        )

        let save = try XCTUnwrap(file.item(withTitle: "Save Playlist…"))
        XCTAssertFalse(save.isEnabled)
        XCTAssertNotNil(save.target)
        XCTAssertNotNil(save.action)
    }

    func testSavePlaylistEnabledWhenTracksPresent() throws {
        let application = makeApplication(tracks: [
            Track(title: "One", artist: "Artist", url: URL(fileURLWithPath: "/tmp/one.mp3")),
        ])
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        let file = try XCTUnwrap(menu.item(withTitle: "File")?.submenu)
        file.update()
        let save = try XCTUnwrap(file.item(withTitle: "Save Playlist…"))
        XCTAssertTrue(save.isEnabled)
    }

    func testPlaybackMenuMatchesCatalog() throws {
        let application = makeApplication()
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        let playback = try XCTUnwrap(menu.item(withTitle: "Playback")?.submenu)
        playback.update()
        XCTAssertEqual(
            playback.items.filter { !$0.isSeparatorItem }.map(\.title),
            AmpXMenuCatalog.PlaybackItem.allCases.map(\.rawValue)
        )
    }

    func testViewMenuReflectsModuleVisibility() throws {
        let application = makeApplication()
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        let view = try XCTUnwrap(menu.item(withTitle: "View")?.submenu)
        view.update()

        let eq = try XCTUnwrap(view.item(withTitle: AmpXMenuCatalog.ViewPanel.equalizer.rawValue))
        let pl = try XCTUnwrap(view.item(withTitle: AmpXMenuCatalog.ViewPanel.playlist.rawValue))
        let viz = try XCTUnwrap(view.item(withTitle: AmpXMenuCatalog.ViewPanel.visualizer.rawValue))
        XCTAssertEqual(eq.state, .on)
        XCTAssertEqual(pl.state, .on)
        XCTAssertEqual(viz.state, .off)

        application.hosts.closeModule(.equalizer)
        view.update()
        XCTAssertEqual(eq.state, .off)
    }

    func testWindowMenuIncludesAmpXReopenAndModuleCommands() throws {
        let application = makeApplication()
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        let window = try XCTUnwrap(menu.item(withTitle: "Window")?.submenu)
        let titles = window.items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertTrue(titles.contains("AmpX"))
        XCTAssertTrue(titles.contains("Move Module Up"))
        XCTAssertTrue(titles.contains("Move Module Down"))
        XCTAssertTrue(titles.contains("Detach/Re-dock Module"))
        XCTAssertTrue(titles.contains("Collapse/Expand Module"))
        XCTAssertTrue(titles.contains("Bring All to Front"))
    }

    func testShuffleAndRepeatReflectPlaylistState() throws {
        let application = makeApplication()
        application.playlistManager.shuffleEnabled = true
        application.playlistManager.repeatEnabled = true
        let menu = AmpXMenuBuilder.makeMainMenu(application: application)
        let playback = try XCTUnwrap(menu.item(withTitle: "Playback")?.submenu)
        playback.update()
        let shuffle = try XCTUnwrap(playback.item(withTitle: AmpXMenuCatalog.PlaybackItem.shuffle.rawValue))
        let repeatItem = try XCTUnwrap(playback.item(withTitle: AmpXMenuCatalog.PlaybackItem.repeat.rawValue))
        XCTAssertEqual(shuffle.state, .on)
        XCTAssertEqual(repeatItem.state, .on)
    }
}
