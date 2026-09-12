import AppKit

/// Playback position slider that pulls `PlaybackClock.currentTime` on display-link ticks.
final class PositionBarView: AmpXContinuousView {
    weak var audioPlayer: AudioPlayer?
    var onChange: ((TimeInterval) -> Void)?

    /// Display-only position for deterministic reference presentation; `nil` follows playback.
    var referenceFraction: Double? {
        didSet { slider.displayValueOverride = referenceFraction }
    }

    private let slider: AmpXSlider
    private var playbackDuration: TimeInterval = 0

    override init(skin: any AmpXSkin) {
        self.slider = AmpXSlider(skin: skin)
        super.init(skin: skin)
        slider.range = 0 ... 1
        slider.artwork = .seek
        slider.trackSize = AmpXMetrics.playerPositionTrackSize
        slider.thumbSize = AmpXMetrics.playerPositionThumbSize
        slider.thumbCrossOffset = AmpXMetrics.playerPositionThumbOffset
        slider.onChange = { [weak self] fraction in
            guard let self else { return }
            self.onChange?(self.playbackDuration * fraction)
        }
        addSubview(slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        slider.frame = bounds
    }

    override func layout() {
        super.layout()
        slider.frame = bounds
    }

    override func tick(at time: TimeInterval) {
        guard let audioPlayer else { return }
        updatePlayback(
            current: audioPlayer.playbackClock.currentTime,
            duration: audioPlayer.duration
        )
    }

    func updatePlayback(current: TimeInterval, duration: TimeInterval) {
        playbackDuration = duration
        let fraction = duration > 0 ? current / duration : 0
        slider.setValue(fraction, sendChange: false)
    }
}
