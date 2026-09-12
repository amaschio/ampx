import AppKit
import Combine
import CoreGraphics

final class PlayerModuleContent: AmpXModuleContent {
    private let audioPlayer: AudioPlayer
    private let playlistManager: PlaylistManager
    private let onToggleModule: (AmpXModuleID) -> Void

    private let spectrumWell: SpectrumWellView
    private let timeDisplay: TimeDisplayView
    private let volumeSlider: AmpXSlider
    private let balanceSlider: AmpXSlider
    private let positionBar: PositionBarView
    private let eqToggle: AmpXButton
    private let plToggle: AmpXButton
    private var transportButtons: [AmpXButton] = []
    private var cancellables = Set<AnyCancellable>()

    private var showPlayGlyph = true
    private var trackTitle = ""
    private var bitrateText = "128"
    private var sampleRateText = "48"
    private var isMono = false
    private var isStereo = true

    init(
        skin: any AmpXSkin,
        audioPlayer: AudioPlayer,
        playlistManager: PlaylistManager,
        onToggleModule: @escaping (AmpXModuleID) -> Void
    ) {
        self.audioPlayer = audioPlayer
        self.playlistManager = playlistManager
        self.onToggleModule = onToggleModule
        self.spectrumWell = SpectrumWellView(skin: skin)
        self.timeDisplay = TimeDisplayView(skin: skin)
        self.volumeSlider = AmpXSlider(skin: skin)
        self.balanceSlider = AmpXSlider(skin: skin)
        self.positionBar = PositionBarView(skin: skin)
        self.eqToggle = AmpXButton(skin: skin)
        self.plToggle = AmpXButton(skin: skin)
        super.init(skin: skin)
        configureControls()
        bindModels()
        refreshStaticDisplayState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateModuleToggleStates(eqOpen: Bool, plOpen: Bool) {
        eqToggle.isActive = eqOpen
        plToggle.isActive = plOpen
    }

    private func configureControls() {
        timeDisplay.audioPlayer = audioPlayer
        positionBar.audioPlayer = audioPlayer

        volumeSlider.range = 0 ... 1
        volumeSlider.showsGradient = true
        volumeSlider.onChange = { [weak audioPlayer] value in
            audioPlayer?.setVolume(Float(value))
        }

        balanceSlider.range = 0 ... 1
        balanceSlider.showsGradient = true
        balanceSlider.onChange = { [weak audioPlayer] value in
            audioPlayer?.setBalance(Float(value * 2 - 1))
        }

        positionBar.onChange = { [weak audioPlayer] seconds in
            audioPlayer?.seek(to: seconds)
        }

        eqToggle.label = "EQ"
        eqToggle.showsActiveIndicator = true
        eqToggle.accessibilityTitle = "Equalizer"
        eqToggle.action = { [weak self] in
            self?.onToggleModule(.equalizer)
        }

        plToggle.label = "PL"
        plToggle.showsActiveIndicator = true
        plToggle.accessibilityTitle = "Playlist"
        plToggle.action = { [weak self] in
            self?.onToggleModule(.playlist)
        }

        let transportIcons: [AmpXIcon?] = [
            .previous, .play, .pause, .stop, .next, .eject, nil, .`repeat`, .menu,
        ]
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() {
            let button = AmpXButton(skin: skin)
            button.frame = frame
            if index == 6 {
                button.label = "SHUFFLE"
                button.showsActiveIndicator = true
                button.accessibilityTitle = "Shuffle"
                button.action = { [weak self] in
                    guard let self else { return }
                    self.playlistManager.shuffleEnabled.toggle()
                }
            } else if index == 8 {
                button.style = .menu
                button.icon = .menu
                button.accessibilityTitle = "Menu"
            } else if let icon = transportIcons[index] {
                button.icon = icon
                button.accessibilityTitle = transportLabel(for: icon)
                button.action = transportAction(for: icon)
            }
            transportButtons.append(button)
            addSubview(button)
        }

        for control in [spectrumWell, timeDisplay, volumeSlider, balanceSlider, positionBar, eqToggle, plToggle] {
            addSubview(control)
        }
        layoutControls()
    }

    private func bindModels() {
        audioPlayer.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.showPlayGlyph = !isPlaying
                self?.needsDisplay = true
                self?.updateTransportPlayIcon()
            }
            .store(in: &cancellables)

        audioPlayer.$volume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volume in
                self?.volumeSlider.setValue(Double(volume), sendChange: false)
            }
            .store(in: &cancellables)

        audioPlayer.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.balanceSlider.setValue(Double((balance + 1) / 2), sendChange: false)
            }
            .store(in: &cancellables)

        audioPlayer.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPlaybackDisplay()
            }
            .store(in: &cancellables)

        audioPlayer.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTrackTitle()
                self?.needsDisplay = true
            }
            .store(in: &cancellables)

        audioPlayer.$currentBitrate
            .combineLatest(audioPlayer.$currentSampleRate, audioPlayer.$currentChannels)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bitrate, sampleRate, channels in
                self?.bitrateText = "\(bitrate)"
                self?.sampleRateText = AudioFormatInfo.sampleRateDisplayKHz(sampleRate)
                self?.isMono = channels == 1
                self?.isStereo = channels >= 2
                self?.needsDisplay = true
            }
            .store(in: &cancellables)

        playlistManager.$currentIndex
            .combineLatest(playlistManager.$tracks)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshTrackTitle()
                self?.needsDisplay = true
            }
            .store(in: &cancellables)

        playlistManager.$shuffleEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.transportButtons[safe: 6]?.isActive = enabled
            }
            .store(in: &cancellables)

        playlistManager.$repeatEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.transportButtons[safe: 7]?.isActive = enabled
            }
            .store(in: &cancellables)
    }

    private func refreshStaticDisplayState() {
        volumeSlider.setValue(Double(audioPlayer.volume), sendChange: false)
        balanceSlider.setValue(Double((audioPlayer.balance + 1) / 2), sendChange: false)
        transportButtons[safe: 6]?.isActive = playlistManager.shuffleEnabled
        transportButtons[safe: 7]?.isActive = playlistManager.repeatEnabled
        showPlayGlyph = !audioPlayer.isPlaying
        updateTransportPlayIcon()
        refreshTrackTitle()
        refreshPlaybackDisplay()
    }

    private func refreshPlaybackDisplay() {
        positionBar.updatePlayback(
            current: audioPlayer.playbackClock.currentTime,
            duration: audioPlayer.duration
        )
    }

    private func refreshTrackTitle() {
        let displayTrack = playlistManager.currentTrack ?? audioPlayer.currentTrack
        guard let displayTrack else {
            trackTitle = ""
            return
        }

        let artist = displayTrack.artist.isEmpty ? "Unknown Artist" : displayTrack.artist
        let title = displayTrack.title.isEmpty ? "Unknown Title" : displayTrack.title
        var text = "\(artist) - \(title)"
        if playlistManager.currentIndex >= 0 {
            text = "\(playlistManager.currentIndex + 1). " + text
        }
        if displayTrack.duration > 0 {
            text += " (\(AmpXTimeFormatting.format(displayTrack.duration)))"
        }
        trackTitle = text
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        let displayWell = AmpXMetrics.playerDisplayWell
        spectrumWell.frame = displayWell
        timeDisplay.frame = CGRect(
            x: displayWell.minX + AmpXMetrics.playerTimer.minX,
            y: displayWell.minY + AmpXMetrics.playerTimer.minY,
            width: AmpXMetrics.playerTimer.width,
            height: AmpXMetrics.playerTimer.height
        )
        volumeSlider.frame = AmpXMetrics.playerVolume
        balanceSlider.frame = AmpXMetrics.playerBalance
        positionBar.frame = AmpXMetrics.playerPosition
        eqToggle.frame = AmpXMetrics.playerEQToggle
        plToggle.frame = AmpXMetrics.playerPLToggle
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() where index < transportButtons.count {
            transportButtons[index].frame = frame
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.inset(bounds, in: context, backingScale: backingScale)

        skin.displayWell(AmpXMetrics.playerDisplayWell, in: context, backingScale: backingScale)
        skin.displayWell(AmpXMetrics.playerTrackWell, in: context, backingScale: backingScale)

        if showPlayGlyph {
            drawPlayGlyph(in: context)
        }

        drawTrackTitle(in: context)
        drawMetadata(in: context)
    }

    private func updateTransportPlayIcon() {
        if let playButton = transportButtons[safe: 1] {
            playButton.iconColor = showPlayGlyph ? skin.green : skin.text
        }
    }

    private func transportAction(for icon: AmpXIcon) -> (() -> Void)? {
        switch icon {
        case .previous:
            return { [weak playlistManager] in playlistManager?.previous() }
        case .play:
            return { [weak audioPlayer] in audioPlayer?.playOrResume() }
        case .pause:
            return { [weak audioPlayer] in audioPlayer?.pause() }
        case .stop:
            return { [weak audioPlayer] in audioPlayer?.stop() }
        case .next:
            return { [weak playlistManager] in playlistManager?.next() }
        case .eject:
            return { [weak playlistManager] in playlistManager?.showFilePicker() }
        case .repeat:
            return { [weak self] in
                self?.playlistManager.repeatEnabled.toggle()
            }
        default:
            return nil
        }
    }

    private func transportLabel(for icon: AmpXIcon) -> String {
        switch icon {
        case .previous: "Previous"
        case .play: "Play"
        case .pause: "Pause"
        case .stop: "Stop"
        case .next: "Next"
        case .eject: "Eject"
        case .repeat: "Repeat"
        default: "Transport"
        }
    }

    private func drawPlayGlyph(in context: CGContext) {
        let glyph = CGRect(
            x: AmpXMetrics.playerDisplayWell.minX + AmpXMetrics.playerPlayGlyph.minX,
            y: AmpXMetrics.playerDisplayWell.minY + AmpXMetrics.playerPlayGlyph.minY,
            width: AmpXMetrics.playerPlayGlyph.width,
            height: AmpXMetrics.playerPlayGlyph.height
        )
        AmpXIcon.play.draw(
            in: glyph,
            context: context,
            skin: skin,
            color: skin.green
        )
    }

    private func drawTrackTitle(in context: CGContext) {
        let inset = AmpXMetrics.playerTrackWell.insetBy(dx: 5.5, dy: 7)
        let title = trackTitle.isEmpty ? " " : trackTitle
        AmpXLabel(text: title, color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: inset, context: context, skin: skin)
    }

    private func drawMetadata(in context: CGContext) {
        let rect = AmpXMetrics.playerMetadata
        AmpXLabel(text: bitrateText, color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: CGRect(x: rect.minX, y: rect.minY, width: 28, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "kbps", color: skin.green, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.minX + 26, y: rect.minY + 2, width: 28, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: sampleRateText, color: skin.green, fontSize: 11, weight: .medium)
            .draw(in: CGRect(x: rect.minX + 54, y: rect.minY, width: 22, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "kHz", color: skin.green, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.minX + 72, y: rect.minY + 2, width: 24, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "mono", color: isMono ? skin.green : skin.textDim, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.maxX - 52, y: rect.minY + 2, width: 24, height: rect.height), context: context, skin: skin)
        AmpXLabel(text: "stereo", color: isStereo ? skin.green : skin.textDim, fontSize: 8, weight: .regular)
            .draw(in: CGRect(x: rect.maxX - 28, y: rect.minY + 2, width: 28, height: rect.height), context: context, skin: skin)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
