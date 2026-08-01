import Foundation

/// Transport surface used by `PlaylistManager` and test doubles.
/// Classic UI observes the concrete `AudioPlayer` for richer playback/EQ state;
/// widen this protocol only when a second consumer needs the same surface under test.
@MainActor
protocol AudioPlaybackControlling: AnyObject {
    func loadTrack(_ track: Track, completion: (@MainActor @Sendable (Bool) -> Void)?)
    func play()
    func stop()
    func seek(to time: TimeInterval)
}

extension AudioPlayer: AudioPlaybackControlling {}
