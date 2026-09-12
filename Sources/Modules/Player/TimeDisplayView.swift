import AppKit
import CoreGraphics

/// Segment timer that pulls `PlaybackClock.currentTime` on display-link ticks.
final class TimeDisplayView: AmpXContinuousView {
    weak var audioPlayer: AudioPlayer?
    var showRemainingTime = false {
        didSet { needsDisplay = true }
    }

    /// Display-only text for deterministic reference presentation; `nil` shows the playback clock.
    var referenceText: String? {
        didSet { needsDisplay = true }
    }

    private let segmentDigits: AmpXSegmentDigits
    private var blinkOff = false
    private var lastBlinkToggle: TimeInterval = 0

    override init(skin: any AmpXSkin) {
        self.segmentDigits = AmpXSegmentDigits(skin: skin)
        super.init(skin: skin)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tick(at time: TimeInterval) {
        self.updateBlinkState(at: time)
        setNeedsDisplay(bounds)
    }

    override func mouseDown(with _: NSEvent) {
        self.showRemainingTime.toggle()
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if let referenceText {
            self.segmentDigits.draw(referenceText, in: bounds, context: context)
            return
        }
        guard let audioPlayer else { return }

        let duration = audioPlayer.duration
        let current = audioPlayer.playbackClock.currentTime
        let displayTime: TimeInterval = if self.showRemainingTime {
            duration > 0 ? -(duration - current) : 0
        } else {
            current
        }

        let text = AmpXTimeFormatting.format(displayTime, showNegative: self.showRemainingTime)
        if self.blinkOff {
            return
        }
        self.segmentDigits.draw(text, in: bounds, context: context)
    }

    private func updateBlinkState(at time: TimeInterval) {
        guard let audioPlayer else {
            self.blinkOff = false
            return
        }
        let paused = !audioPlayer.isPlaying && audioPlayer.duration > 0
        guard paused else {
            self.blinkOff = false
            return
        }
        if time - self.lastBlinkToggle >= 0.5 {
            self.blinkOff.toggle()
            self.lastBlinkToggle = time
        }
    }
}
