import AppKit
import Combine
import CoreGraphics

/// Display-only values for deterministic reference captures. Never written to audio, playlist, or layout state.
struct PlayerReferencePresentation: Equatable {
    var trackTitle: String
    var timeText: String
    var bitrateText: String
    var sampleRateText: String
    var isMono: Bool
    var isStereo: Bool
    var isPlaying: Bool
    var spectrumLevels: [Float]
    var spectrumPeaks: [Float]
    var volume: Double
    var balance: Double
    var position: Double
    var equalizerOpen: Bool
    var playlistOpen: Bool
    var shuffleEnabled: Bool
    var repeatEnabled: Bool
}

final class PlayerModuleContent: AmpXModuleContent {
    private let audioPlayer: AudioPlayer
    private let playlistManager: PlaylistManager
    private let onToggleModule: (AmpXModuleID) -> Void
    var menuAction: ((AmpXButton) -> Void)?

    /// When set, rendering uses these values instead of live model state.
    var referencePresentation: PlayerReferencePresentation? {
        didSet { applyReferencePresentation() }
    }

    private let spectrumWell: SpectrumWellView
    private let timeDisplay: TimeDisplayView
    private let volumeSlider: AmpXSlider
    private let balanceSlider: AmpXSlider
    private let positionBar: PositionBarView
    private let eqToggle: AmpXButton
    private let plToggle: AmpXButton
    private var transportButtons: [AmpXButton] = []
    private var cancellables = Set<AnyCancellable>()

    private var isPlaying = false
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

        for slider in [volumeSlider, balanceSlider] {
            slider.range = 0 ... 1
            slider.thumbSize = AmpXMetrics.playerSliderThumbSize
            slider.thumbCrossOffset = AmpXMetrics.playerSliderThumbOffset
        }
        volumeSlider.artwork = .pill(.volume)
        volumeSlider.accessibilityTitle = "Volume"
        volumeSlider.onChange = { [weak audioPlayer] value in
            audioPlayer?.setVolume(Float(value))
        }

        balanceSlider.artwork = .pill(.balance)
        balanceSlider.accessibilityTitle = "Balance"
        balanceSlider.onChange = { [weak audioPlayer] value in
            audioPlayer?.setBalance(Float(value * 2 - 1))
        }

        positionBar.onChange = { [weak audioPlayer] seconds in
            audioPlayer?.seek(to: seconds)
        }

        configureToggle(eqToggle, label: "EQ", title: "Equalizer", indicator: AmpXMetrics.playerEQIndicator,
                        labelInk: AmpXMetrics.playerEQLabelInk, leftBearing: 1.1)
        eqToggle.action = { [weak self] in
            self?.onToggleModule(.equalizer)
        }
        configureToggle(plToggle, label: "PL", title: "Playlist", indicator: AmpXMetrics.playerPLIndicator,
                        labelInk: AmpXMetrics.playerPLLabelInk, leftBearing: 1.14)
        plToggle.action = { [weak self] in
            self?.onToggleModule(.playlist)
        }

        let transportIcons: [AmpXIcon?] = [
            .previous, .play, .pause, .stop, .next, .eject, nil, .`repeat`, .menu,
        ]
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() {
            let button = AmpXButton(skin: skin)
            button.frame = frame
            if let glyph = AmpXMetrics.playerTransportGlyphs[index] {
                button.iconRect = glyph.offsetBy(dx: -frame.minX, dy: -frame.minY)
            }
            if index == 6 {
                button.label = "SHUFFLE"
                button.labelFontSize = 12.5
                button.labelWeight = .regular
                button.labelBaselineOrigin = CGPoint(
                    x: AmpXMetrics.playerShuffleLabelInk.x - 0.62,
                    y: AmpXMetrics.playerShuffleLabelInk.y
                )
                button.showsActiveIndicator = true
                button.indicatorRect = AmpXMetrics.playerShuffleIndicator
                button.accessibilityTitle = "Shuffle"
                button.action = { [weak self] in
                    guard let self else { return }
                    self.playlistManager.shuffleEnabled.toggle()
                }
            } else if index == 8 {
                button.style = .menu
                button.icon = .menu
                button.iconColor = skin.text
                button.accessibilityTitle = "Menu"
                button.action = { [weak self] in
                    guard let self, let button = self.transportButtons[safe: 8] else { return }
                    self.menuAction?(button)
                }
            } else if let icon = transportIcons[index] {
                button.icon = icon
                button.showsActiveFace = icon == .play
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

    private func configureToggle(
        _ button: AmpXButton,
        label: String,
        title: String,
        indicator: CGRect,
        labelInk: CGPoint,
        leftBearing: CGFloat
    ) {
        button.label = label
        button.labelFontSize = 13.5
        button.labelWeight = .regular
        button.labelBaselineOrigin = CGPoint(x: labelInk.x - leftBearing, y: labelInk.y)
        button.showsActiveIndicator = true
        button.indicatorRect = indicator
        button.accessibilityTitle = title
    }

    private func bindModels() {
        audioPlayer.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
                self?.transportButtons[safe: 1]?.isActive = isPlaying
                self?.needsDisplay = true
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
        isPlaying = audioPlayer.isPlaying
        transportButtons[safe: 1]?.isActive = isPlaying
        refreshTrackTitle()
        refreshPlaybackDisplay()
    }

    private func applyReferencePresentation() {
        let reference = referencePresentation
        timeDisplay.referenceText = reference?.timeText
        spectrumWell.reference = reference.map { SpectrumWellView.Reference(levels: $0.spectrumLevels, peaks: $0.spectrumPeaks) }
        volumeSlider.displayValueOverride = reference?.volume
        balanceSlider.displayValueOverride = reference?.balance
        positionBar.referenceFraction = reference?.position
        eqToggle.displayActiveOverride = reference?.equalizerOpen
        plToggle.displayActiveOverride = reference?.playlistOpen
        transportButtons[safe: 1]?.displayActiveOverride = reference?.isPlaying
        transportButtons[safe: 6]?.displayActiveOverride = reference?.shuffleEnabled
        transportButtons[safe: 7]?.displayActiveOverride = reference?.repeatEnabled
        needsDisplay = true
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

    // MARK: - Layout

    /// Measured `01:51` timer ink; digit cells are right-aligned to its trailing edge.
    static var timerFrame: CGRect {
        AmpXMetrics.playerTimer
    }

    /// Timer view extends left of the reference ink so remaining-time signs fit without stretching.
    static var timerViewFrame: CGRect {
        let timer = timerFrame
        let minX = playGlyphFrame.maxX + 3
        return CGRect(x: minX, y: timer.minY, width: timer.maxX - minX, height: timer.height)
    }

    static var playGlyphFrame: CGRect {
        AmpXMetrics.playerPlayGlyph
    }

    private func layoutControls() {
        spectrumWell.frame = AmpXMetrics.playerDisplayWell
        timeDisplay.frame = Self.timerViewFrame
        volumeSlider.frame = AmpXMetrics.playerVolume
        volumeSlider.trackSize = CGSize(width: AmpXMetrics.playerVolume.width, height: AmpXMetrics.playerSliderTrackHeight)
        balanceSlider.frame = AmpXMetrics.playerBalance
        balanceSlider.trackSize = CGSize(width: AmpXMetrics.playerBalance.width, height: AmpXMetrics.playerSliderTrackHeight)
        positionBar.frame = AmpXMetrics.playerPosition
        eqToggle.frame = AmpXMetrics.playerEQToggle
        plToggle.frame = AmpXMetrics.playerPLToggle
        for (index, frame) in AmpXMetrics.playerTransport.enumerated() where index < transportButtons.count {
            transportButtons[index].frame = frame
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.displayWell(AmpXMetrics.playerDisplayWell, in: context, backingScale: backingScale)
        skin.dotGrid(AmpXMetrics.playerDisplayInterior, in: context)
        skin.displayWell(AmpXMetrics.playerTrackWell, in: context, backingScale: backingScale)
        skin.displayWell(AmpXMetrics.playerBitrateWell, in: context, backingScale: backingScale)
        skin.displayWell(AmpXMetrics.playerSampleRateWell, in: context, backingScale: backingScale)

        if referencePresentation?.isPlaying ?? isPlaying {
            AmpXIcon.play.draw(in: Self.playGlyphFrame, context: context, skin: skin, color: skin.green)
        }

        drawTrackTitle(in: context)
        drawMetadata(in: context)
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

    private func drawTrackTitle(in context: CGContext) {
        let title = referencePresentation?.trackTitle ?? trackTitle
        guard !title.isEmpty else { return }
        let ink = AmpXMetrics.playerTrackTextInk
        let label = AmpXLabel(text: title, color: skin.green, fontSize: 13.75, weight: .regular)
        context.saveGState()
        context.clip(to: AmpXMetrics.playerTrackWell.insetBy(dx: 2, dy: 2))
        // Baseline from the parenthesis descent (0.2256 em) below the measured ink bottom.
        label.draw(x: ink.minX - 0.44, baseline: ink.maxY - 13.75 * 0.2256, context: context, skin: skin)
        context.restoreGState()
    }

    private func drawMetadata(in context: CGContext) {
        let reference = referencePresentation
        let layout = Self.metadataLayout(
            bitrate: reference?.bitrateText ?? bitrateText,
            sampleRate: reference?.sampleRateText ?? sampleRateText
        )
        let mono = reference?.isMono ?? isMono
        let stereo = reference?.isStereo ?? isStereo
        for item in layout.items {
            let color: NSColor = switch item.role {
            case .mono: mono ? skin.green : skin.textDim
            case .stereo: stereo ? skin.green : skin.textDim
            case .kbps, .kHz: skin.text
            case .bitrate, .sampleRate: skin.green
            }
            AmpXLabel(text: item.text, color: color, fontSize: item.fontSize, weight: item.weight)
                .draw(x: item.rect.minX, baseline: item.baseline, context: context, skin: skin)
        }
    }

    /// Single-line metadata layout. Numeric readouts center in their wells and shrink only when a
    /// value is wider than the well; channel labels are right-aligned to the reference ink.
    static func metadataLayout(bitrate: String, sampleRate: String, skin: any AmpXSkin = ClassicModernSkin()) -> PlayerMetadataLayout {
        let baseline: CGFloat = 64.5

        func item(
            _ role: PlayerMetadataLayout.Role,
            _ text: String,
            size: CGFloat,
            weight: NSFont.Weight,
            x: (CGFloat) -> CGFloat
        ) -> PlayerMetadataLayout.Item {
            let label = AmpXLabel(text: text, color: skin.text, fontSize: size, weight: weight)
            let rect = label.lineRect(x: 0, baseline: baseline, skin: skin)
            return PlayerMetadataLayout.Item(
                role: role, text: text, fontSize: size, weight: weight, baseline: baseline,
                rect: rect.offsetBy(dx: x(rect.width), dy: 0)
            )
        }

        func numeric(_ role: PlayerMetadataLayout.Role, _ text: String, well: CGRect) -> PlayerMetadataLayout.Item {
            let preferred: CGFloat = 14.5
            let width = AmpXLabel(text: text, color: skin.text, fontSize: preferred, weight: .regular)
                .measuredSize(skin: skin).width
            let available = well.width - 3
            let size = width > available ? (preferred * available / width).rounded(.down) : preferred
            return item(role, text, size: size, weight: .regular) { well.midX - $0 / 2 }
        }

        return PlayerMetadataLayout(items: [
            numeric(.bitrate, bitrate, well: AmpXMetrics.playerBitrateWell),
            item(.kbps, "kbps", size: 12.5, weight: .regular) { _ in AmpXMetrics.playerKbpsInk.minX - 1.07 },
            numeric(.sampleRate, sampleRate, well: AmpXMetrics.playerSampleRateWell),
            item(.kHz, "kHz", size: 12.5, weight: .regular) { _ in AmpXMetrics.playerKHzInk.minX - 1.07 },
            item(.mono, "mono", size: 12.5, weight: .regular) { AmpXMetrics.playerMonoInk.maxX + 0.75 - $0 },
            item(.stereo, "stereo", size: 12.5, weight: .regular) { AmpXMetrics.playerStereoInk.maxX + 0.75 - $0 },
        ])
    }
}

struct PlayerMetadataLayout {
    enum Role {
        case bitrate, kbps, sampleRate, kHz, mono, stereo
    }

    struct Item {
        var role: Role
        var text: String
        var fontSize: CGFloat
        var weight: NSFont.Weight
        var baseline: CGFloat
        /// Typographic line box.
        var rect: CGRect
    }

    var items: [Item]

    func item(_ role: Role) -> Item? {
        items.first { $0.role == role }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
