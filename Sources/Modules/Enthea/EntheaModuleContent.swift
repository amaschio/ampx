import AppKit
import Combine

private final class EntheaPlaybackTickView: AmpXContinuousView {
    weak var hostView: EntheaWKHostView?
    weak var audioPlayer: AudioPlayer?
    var isTheater: () -> Bool = { false }

    override func tick(at time: TimeInterval) {
        guard let hostView, let audioPlayer else { return }
        hostView.updatePlayback(
            trackURL: audioPlayer.currentTrack?.url,
            seconds: audioPlayer.playbackClock.currentTime,
            isPlaying: audioPlayer.isPlaying,
            isTheater: isTheater()
        )
    }
}

@MainActor
final class EntheaModuleContent: AmpXModuleContent {
    private static let controlStripHeight: CGFloat = 18

    private let audioPlayer: AudioPlayer
    private let isTheater: () -> Bool
    private let onToggleTheater: () -> Void
    private let panelController = EntheaPanelController()
    private let playbackTickView: EntheaPlaybackTickView
    private let previousButton: AmpXButton
    private let titleButton: AmpXButton
    private let looksButton: AmpXButton
    private let dropButton: AmpXButton
    private let theaterButton: AmpXButton
    private let nextButton: AmpXButton

    private var lifecycle: EntheaHostLifecycle?
    private var hostView: EntheaWKHostView?
    private var hostGeneration = 0
    private var isModuleClosed = true
    private var isEffectivelyVisibleFlag = false
    private var cancellables = Set<AnyCancellable>()
    private var lastTitle = ""

    var hostViewForTesting: EntheaWKHostView? { hostView }
    var lifecycleForTesting: EntheaHostLifecycle? { lifecycle }

    init(
        skin: any AmpXSkin,
        audioPlayer: AudioPlayer,
        isTheater: @escaping () -> Bool,
        onToggleTheater: @escaping () -> Void
    ) {
        self.audioPlayer = audioPlayer
        self.isTheater = isTheater
        self.onToggleTheater = onToggleTheater
        self.playbackTickView = EntheaPlaybackTickView(skin: skin)
        self.previousButton = AmpXButton(skin: skin)
        self.titleButton = AmpXButton(skin: skin)
        self.looksButton = AmpXButton(skin: skin)
        self.dropButton = AmpXButton(skin: skin)
        self.theaterButton = AmpXButton(skin: skin)
        self.nextButton = AmpXButton(skin: skin)
        super.init(skin: skin)
        configureControls()
        bindModels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reopenHost() {
        isModuleClosed = false
        ensureHostLoaded()
        if isEffectivelyVisibleFlag {
            lifecycle?.setVisible(true)
            syncPlaybackToHost()
        }
    }

    func closeHost() {
        hostGeneration += 1
        lifecycle?.close()
        lifecycle = nil
        hostView?.removeFromSuperview()
        hostView = nil
        isModuleClosed = true
        playbackTickView.hostView = nil
    }

    override func setEffectivelyVisible(_ visible: Bool) {
        guard !isModuleClosed else { return }
        playbackTickView.setEffectivelyVisible(visible)
        guard visible != isEffectivelyVisibleFlag else { return }
        isEffectivelyVisibleFlag = visible
        ensureHostLoaded()
        lifecycle?.setVisible(visible)
        if visible {
            syncPlaybackToHost()
            applyBackingScaleIfNeeded()
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
        applyBackingScaleIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyBackingScaleIfNeeded()
        lifecycle?.setVisible(isEffectivelyVisibleFlag && !isModuleClosed)
    }

    func refreshTheaterPresentation() {
        refreshTheaterButton()
        syncPlaybackToHost()
        applyBackingScaleIfNeeded()
    }

    func scheduleDeferredLayoutForTesting() {
        let generation = hostGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self, self.hostGeneration == generation, self.hostView != nil else { return }
            self.applyBackingScaleIfNeeded()
        }
    }

    private func configureControls() {
        playbackTickView.audioPlayer = audioPlayer
        playbackTickView.isTheater = { [weak self] in self?.isTheater() ?? false }

        previousButton.label = "◀"
        previousButton.accessibilityTitle = "Previous ENTHEA mode"
        previousButton.action = { [weak self] in
            guard let self else { return }
            if NSEvent.modifierFlags.contains(.shift) {
                self.panelController.nudgeDose(-0.05)
            } else {
                self.panelController.previousMode()
            }
            self.refreshTitleButton()
        }

        titleButton.accessibilityTitle = "ENTHEA mode title"
        titleButton.action = { [weak self] in
            self?.panelController.toggleAutopilot()
            self?.refreshTitleButton()
        }

        looksButton.label = "LOOKS"
        looksButton.style = .menu
        looksButton.accessibilityTitle = "ENTHEA looks"
        looksButton.action = { [weak self] in
            self?.showLooksMenu()
        }

        dropButton.label = "DROP"
        dropButton.accessibilityTitle = "Force drop effect"
        dropButton.action = { [weak self] in
            self?.panelController.fireDrop()
        }

        theaterButton.label = "⛶"
        theaterButton.accessibilityTitle = "Theater mode"
        theaterButton.action = { [weak self] in
            self?.onToggleTheater()
            self?.syncPlaybackToHost()
            self?.refreshTheaterButton()
        }

        nextButton.label = "▶"
        nextButton.accessibilityTitle = "Next ENTHEA mode"
        nextButton.action = { [weak self] in
            guard let self else { return }
            if NSEvent.modifierFlags.contains(.shift) {
                self.panelController.nudgeDose(0.05)
            } else {
                self.panelController.nextMode()
            }
            self.refreshTitleButton()
        }

        for control in [
            previousButton, titleButton, looksButton, dropButton, theaterButton, nextButton, playbackTickView,
        ] {
            addSubview(control)
        }
        refreshTitleButton()
        refreshTheaterButton()
        layoutControls()
    }

    private func bindModels() {
        audioPlayer.$currentTrack
            .combineLatest(audioPlayer.$isPlaying)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.syncPlaybackToHost()
            }
            .store(in: &cancellables)

        panelController.$modeName
            .combineLatest(panelController.$autopilot)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshTitleButton()
            }
            .store(in: &cancellables)
    }

    private func ensureHostLoaded() {
        guard hostView == nil, !isModuleClosed else { return }
        let host = EntheaWKHostView(frame: hostBodyFrame)
        host.panelController = panelController
        host.loadEnthea()
        hostView = host
        lifecycle = EntheaHostLifecycle(host: host)
        playbackTickView.hostView = host
        addSubview(host)
        layoutControls()
    }

    private func syncPlaybackToHost() {
        guard let hostView else { return }
        hostView.updatePlayback(
            trackURL: audioPlayer.currentTrack?.url,
            seconds: audioPlayer.playbackClock.currentTime,
            isPlaying: audioPlayer.isPlaying,
            isTheater: isTheater()
        )
    }

    private func applyBackingScaleIfNeeded() {
        guard let hostView, isEffectivelyVisibleFlag, !isModuleClosed else { return }
        hostView.applyBackingScale(for: hostBodyFrame.size)
    }

    private func refreshTitleButton() {
        let title = panelController.stripTitle
        guard title != lastTitle else { return }
        lastTitle = title
        titleButton.label = title
    }

    private func refreshTheaterButton() {
        theaterButton.label = isTheater() ? "▣" : "⛶"
    }

    private func showLooksMenu() {
        let menu = NSMenu()
        for preset in EntheaLookPreset.all {
            let item = NSMenuItem(title: preset.title, action: #selector(applyLookPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: looksButton.bounds.height), in: looksButton)
    }

    @objc private func applyLookPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? EntheaLookPreset else { return }
        panelController.applyLook(preset)
        refreshTitleButton()
    }

    private var hostBodyFrame: CGRect {
        CGRect(
            x: 0,
            y: Self.controlStripHeight,
            width: bounds.width,
            height: max(0, bounds.height - Self.controlStripHeight)
        )
    }

    private func layoutControls() {
        let stripY = bounds.minY
        let buttonWidth: CGFloat = 28
        let titleWidth = max(120, bounds.width - buttonWidth * 5 - 16)
        var x = bounds.minX + 4
        previousButton.frame = CGRect(x: x, y: stripY + 1, width: buttonWidth, height: Self.controlStripHeight - 2)
        x += buttonWidth + 2
        titleButton.frame = CGRect(x: x, y: stripY + 1, width: titleWidth, height: Self.controlStripHeight - 2)
        x += titleWidth + 2
        looksButton.frame = CGRect(x: x, y: stripY + 1, width: 44, height: Self.controlStripHeight - 2)
        x += 46
        dropButton.frame = CGRect(x: x, y: stripY + 1, width: 40, height: Self.controlStripHeight - 2)
        x += 42
        theaterButton.frame = CGRect(x: x, y: stripY + 1, width: buttonWidth, height: Self.controlStripHeight - 2)
        x += buttonWidth + 2
        nextButton.frame = CGRect(x: x, y: stripY + 1, width: buttonWidth, height: Self.controlStripHeight - 2)
        hostView?.frame = hostBodyFrame
        playbackTickView.frame = .zero
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        skin.inset(bounds, in: context, backingScale: backingScale)
        let strip = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: Self.controlStripHeight)
        skin.displayWell(strip, in: context, backingScale: backingScale)
    }
}
