@testable import AmpX
import XCTest

/// The Player owns the mini visualizer's persistence and its double-click target.
@MainActor
final class AmpXPlayerMiniVisualizerWiringTests: XCTestCase {
    func testPlayerStartsInThePersistedModeAndSavesEveryChange() {
        let defaults = self.makeDefaults()
        defaults.set(VisualizationMode.analyzer.storageValue, forKey: AmpXMiniVisualizerModeStore.key)
        let content = self.makeContent(defaults: defaults)

        XCTAssertEqual(content.spectrumWell.mode, .analyzer)

        content.spectrumWell.mouseDown(with: self.click(count: 1))
        self.waitForMainQueue(after: NSEvent.doubleClickInterval + 0.05)

        XCTAssertEqual(content.spectrumWell.mode, .bars)
        XCTAssertEqual(
            defaults.integer(forKey: AmpXMiniVisualizerModeStore.key),
            VisualizationMode.bars.storageValue
        )
    }

    func testDoubleClickingTheWellTogglesTheVisualizerModule() {
        var toggled: [AmpXModuleID] = []
        let content = self.makeContent(defaults: self.makeDefaults()) { toggled.append($0) }

        content.spectrumWell.mouseDown(with: self.click(count: 1))
        content.spectrumWell.mouseDown(with: self.click(count: 2))
        self.waitForMainQueue(after: NSEvent.doubleClickInterval + 0.05)

        XCTAssertEqual(toggled, [.enthea])
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AmpXPlayerMiniVisualizerWiringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        self.addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func makeContent(
        defaults: UserDefaults,
        onToggleModule: @escaping (AmpXModuleID) -> Void = { _ in }
    ) -> PlayerModuleContent {
        PlayerModuleContent(
            skin: ClassicModernSkin(),
            audioPlayer: AudioPlayer(installRemoteCommands: false),
            playlistManager: PlaylistManager(
                audioPlayer: MockAudioPlayer(),
                restoreBookmarks: false,
                restorePlaylist: false,
                alertPresenter: SilentPlaylistAlertPresenter()
            ),
            onToggleModule: onToggleModule,
            modeStore: AmpXMiniVisualizerModeStore(defaults: defaults)
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
