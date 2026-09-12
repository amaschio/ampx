import AppKit
import Foundation

@MainActor
final class AmpXApplicationController: NSObject, NSMenuItemValidation {
    let audioPlayer: AudioPlayer
    let playlistManager: PlaylistManager
    let hosts: AmpXHostCoordinator

    private let playsStartupSound: Bool
    private var playbackCoordinationBound = false

    init(
        audioPlayer: AudioPlayer,
        playlistManager: PlaylistManager,
        hosts: AmpXHostCoordinator,
        playsStartupSound: Bool? = nil
    ) {
        self.audioPlayer = audioPlayer
        self.playlistManager = playlistManager
        self.hosts = hosts
        self.playsStartupSound = playsStartupSound ?? !Self.isRunningUnderTest
        super.init()
    }

    func start() {
        bindPlaybackCoordinationIfNeeded()
        loadStartupSoundIfNeeded()
        wirePlayerMenuButton()
        hosts.showStack()
    }

    func terminate() {
        hosts.theaterController.handleApplicationTermination()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(savePlaylist(_:)):
            return !playlistManager.tracks.isEmpty
        case #selector(toggleShuffle(_:)):
            menuItem.state = playlistManager.shuffleEnabled ? .on : .off
            return true
        case #selector(toggleRepeat(_:)):
            menuItem.state = playlistManager.repeatEnabled ? .on : .off
            return true
        case #selector(toggleEqualizer(_:)):
            menuItem.state = hosts.state.closed.contains(.equalizer) ? .off : .on
            return true
        case #selector(togglePlaylist(_:)):
            menuItem.state = hosts.state.closed.contains(.playlist) ? .off : .on
            return true
        case #selector(toggleVisualizer(_:)):
            menuItem.state = hosts.state.closed.contains(.enthea) ? .off : .on
            return true
        case #selector(moveModuleUp(_:)), #selector(moveModuleDown(_:)):
            return hosts.focusedModuleID != .player
        case #selector(toggleDetachModule(_:)):
            return hosts.focusedModuleID != .player
        case #selector(toggleCollapseModule(_:)):
            return true
        case #selector(closeStack(_:)):
            return hosts.isStackVisible
        default:
            return true
        }
    }

    // MARK: - File

    @objc func addFiles(_: Any?) {
        playlistManager.showFilePicker()
    }

    @objc func addFolder(_: Any?) {
        playlistManager.showFolderPicker()
    }

    @objc func loadPlaylist(_: Any?) {
        playlistManager.showLoadM3UPicker()
    }

    @objc func savePlaylist(_: Any?) {
        playlistManager.saveM3UPlaylist()
    }

    // MARK: - Playback

    @objc func togglePlayPause(_: Any?) {
        audioPlayer.togglePlayPause()
    }

    @objc func stopPlayback(_: Any?) {
        audioPlayer.stop()
    }

    @objc func previousTrack(_: Any?) {
        playlistManager.previous()
    }

    @objc func nextTrack(_: Any?) {
        playlistManager.next()
    }

    @objc func toggleShuffle(_: Any?) {
        playlistManager.shuffleEnabled.toggle()
    }

    @objc func toggleRepeat(_: Any?) {
        playlistManager.repeatEnabled.toggle()
    }

    // MARK: - View

    @objc func toggleEqualizer(_: Any?) {
        toggleModule(.equalizer)
    }

    @objc func togglePlaylist(_: Any?) {
        toggleModule(.playlist)
    }

    @objc func toggleVisualizer(_: Any?) {
        toggleModule(.enthea)
    }

    // MARK: - Window

    @objc func showAmpX(_: Any?) {
        hosts.showStack()
    }

    @objc func moveModuleUp(_: Any?) {
        hosts.performModuleCommand(.moveUp)
    }

    @objc func moveModuleDown(_: Any?) {
        hosts.performModuleCommand(.moveDown)
    }

    @objc func toggleDetachModule(_: Any?) {
        hosts.performModuleCommand(.toggleDetach)
    }

    @objc func toggleCollapseModule(_: Any?) {
        hosts.performModuleCommand(.toggleCollapse)
    }

    @objc func closeStack(_: Any?) {
        hosts.closeStack()
    }

    @objc func popUpPlayerMenu(from sender: Any?) {
        guard let button = sender as? NSView else { return }
        let menu = AmpXMenuBuilder.makePlayerMenu(application: self)
        let point = NSPoint(x: 0, y: button.bounds.height)
        menu.popUp(positioning: nil, at: point, in: button)
    }

    private func bindPlaybackCoordinationIfNeeded() {
        guard !playbackCoordinationBound else { return }
        playbackCoordinationBound = true

        audioPlayer.onTrackFinished = { [weak playlistManager] in
            playlistManager?.next()
        }
        audioPlayer.onNextTrackRequested = { [weak playlistManager] in
            playlistManager?.next()
        }
        audioPlayer.onPreviousTrackRequested = { [weak playlistManager] in
            playlistManager?.previous()
        }
    }

    private func loadStartupSoundIfNeeded() {
        guard playsStartupSound else { return }
        guard playlistManager.shouldPlayStartupSoundOnLaunch else { return }
        guard let startupURL = Bundle.main.url(forResource: "startup", withExtension: "mp3") else {
            return
        }

        Task { @MainActor in
            let startupTrack = await Track.load(from: startupURL)
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.audioPlayer.loadTrack(startupTrack) { success in
                if success {
                    self.audioPlayer.play()
                }
            }
        }
    }

    private func wirePlayerMenuButton() {
        guard let playerContent = hosts.moduleView(for: .player)?.content as? PlayerModuleContent else {
            return
        }
        playerContent.menuAction = { [weak self] button in
            self?.popUpPlayerMenu(from: button)
        }
    }

    private func toggleModule(_ id: AmpXModuleID) {
        if hosts.state.closed.contains(id) {
            hosts.reopenModule(id)
        } else {
            hosts.closeModule(id)
        }
    }

    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

#if DEBUG
extension AmpXApplicationController {
    var isPlaybackCoordinationBound: Bool {
        playbackCoordinationBound
    }
}
#endif
