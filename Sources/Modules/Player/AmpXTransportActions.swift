import Foundation

@MainActor
enum AmpXTransportActions {
    static func make(
        for icon: AmpXIcon,
        audioPlayer: AudioPlayer,
        playlistManager: PlaylistManager
    ) -> (() -> Void)? {
        switch icon {
        case .previous: return { [weak playlistManager] in playlistManager?.previous() }
        case .play: return { [weak audioPlayer] in audioPlayer?.playOrResume() }
        case .pause: return { [weak audioPlayer] in audioPlayer?.pause() }
        case .stop: return { [weak audioPlayer] in audioPlayer?.stop() }
        case .next: return { [weak playlistManager] in playlistManager?.next() }
        default: return nil
        }
    }
}
