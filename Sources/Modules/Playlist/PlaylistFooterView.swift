import AppKit

@MainActor
final class PlaylistFooterView: AmpXDrawingView {
    private static let footerButtons: [(label: String, rect: CGRect)] = [
        ("ADD", CGRect(x: 0.0, y: 25.0, width: 35.0, height: 40.5)),
        ("REM", CGRect(x: 41.0, y: 25.0, width: 40.5, height: 40.5)),
        ("SEL", CGRect(x: 87.0, y: 24.5, width: 41.0, height: 41.0)),
        ("MISC", CGRect(x: 133.0, y: 25.0, width: 43.0, height: 40.5)),
        ("LIST\nOPTS", CGRect(x: 399.5, y: 21.0, width: 41.5, height: 47.5)),
    ]

    private static let timeCounterWell = CGRect(x: 186.0, y: 22.0, width: 203.0, height: 18.5)
    private static let remainingTimeWell = CGRect(x: 341.0, y: 49.0, width: 48.0, height: 18.0)

    private static let miniTransport: [(icon: AmpXIcon, rect: CGRect)] = [
        (.previous, CGRect(x: 187.5, y: 45.0, width: 23.0, height: 24.0)),
        (.play, CGRect(x: 217.0, y: 46.5, width: 23.0, height: 22.5)),
        (.pause, CGRect(x: 246.5, y: 45.0, width: 24.0, height: 24.0)),
        (.stop, CGRect(x: 276.5, y: 45.5, width: 23.5, height: 23.5)),
        (.next, CGRect(x: 306.5, y: 45.5, width: 24.0, height: 23.5)),
    ]

    private let manager: PlaylistManager
    private let audioPlayer: AudioPlayer
    private let keyboardAdapter: PlaylistKeyboardAdapter

    private var footerButtonsViews: [AmpXButton] = []
    private var miniTransportButtons: [AmpXButton] = []
    private let elapsedTotalReadout: PlaylistFooterTimeReadout
    private let remainingReadout: PlaylistFooterRemainingReadout

    init(
        skin: any AmpXSkin,
        manager: PlaylistManager,
        audioPlayer: AudioPlayer,
        keyboardAdapter: PlaylistKeyboardAdapter
    ) {
        self.manager = manager
        self.audioPlayer = audioPlayer
        self.keyboardAdapter = keyboardAdapter
        self.elapsedTotalReadout = PlaylistFooterTimeReadout(skin: skin)
        self.remainingReadout = PlaylistFooterRemainingReadout(skin: skin)
        super.init(skin: skin)
        configureControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setEffectivelyVisible(_ visible: Bool) {
        elapsedTotalReadout.setEffectivelyVisible(visible)
        remainingReadout.setEffectivelyVisible(visible)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func configureControls() {
        elapsedTotalReadout.audioPlayer = audioPlayer
        elapsedTotalReadout.playlistManager = manager
        remainingReadout.audioPlayer = audioPlayer

        for (label, localRect) in Self.footerButtons {
            let button = AmpXButton(skin: skin)
            button.label = label
            button.accessibilityTitle = label.replacingOccurrences(of: "\n", with: " ")
            button.action = { [weak self] in
                self?.showMenu(for: label, button: button)
            }
            footerButtonsViews.append(button)
            addSubview(button)
        }

        for (index, item) in Self.miniTransport.enumerated() {
            let button = AmpXButton(skin: skin)
            button.icon = item.icon
            button.accessibilityTitle = miniTransportLabel(for: item.icon)
            button.action = transportAction(for: item.icon)
            if item.icon == .play {
                button.iconColor = skin.green
                button.isActive = true
            }
            miniTransportButtons.append(button)
            addSubview(button)
        }

        addSubview(elapsedTotalReadout)
        addSubview(remainingReadout)
        layoutControls()
    }

    private func layoutControls() {
        let footer = AmpXMetrics.playlistFooter
        for (index, localRect) in Self.footerButtons.enumerated() where index < footerButtonsViews.count {
            footerButtonsViews[index].frame = footerRect(localRect.rect, in: footer)
        }
        for (index, item) in Self.miniTransport.enumerated() where index < miniTransportButtons.count {
            miniTransportButtons[index].frame = footerRect(item.rect, in: footer)
        }
        elapsedTotalReadout.frame = footerRect(Self.timeCounterWell, in: footer)
        remainingReadout.frame = footerRect(Self.remainingTimeWell, in: footer)
    }

    private func showMenu(for label: String, button: AmpXButton) {
        let menu = NSMenu()
        switch label {
        case "ADD":
            menu.addItem(menuItem(title: "Add File…", action: #selector(PlaylistFooterMenuActions.addFile)))
            menu.addItem(menuItem(title: "Add Directory…", action: #selector(PlaylistFooterMenuActions.addDirectory)))
        case "REM":
            menu.addItem(menuItem(title: "Remove", action: #selector(PlaylistFooterMenuActions.removeSelected)))
            menu.addItem(menuItem(title: "Crop", action: #selector(PlaylistFooterMenuActions.cropSelected)))
            menu.addItem(menuItem(title: "Clear Playlist", action: #selector(PlaylistFooterMenuActions.clearPlaylist)))
        case "SEL":
            menu.addItem(menuItem(title: "Select All", action: #selector(PlaylistFooterMenuActions.selectAll)))
            menu.addItem(menuItem(title: "Select None", action: #selector(PlaylistFooterMenuActions.selectNone)))
            menu.addItem(menuItem(title: "Invert Selection", action: #selector(PlaylistFooterMenuActions.invertSelection)))
        case "MISC":
            menu.addItem(menuItem(title: "Sort by Title", action: #selector(PlaylistFooterMenuActions.sortByTitle)))
            menu.addItem(menuItem(title: "Sort by Filename", action: #selector(PlaylistFooterMenuActions.sortByFilename)))
            menu.addItem(menuItem(title: "Sort by Path", action: #selector(PlaylistFooterMenuActions.sortByPath)))
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "Reverse", action: #selector(PlaylistFooterMenuActions.reverseTracks)))
            menu.addItem(menuItem(title: "Randomize", action: #selector(PlaylistFooterMenuActions.randomizeTracks)))
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "File Info", action: #selector(PlaylistFooterMenuActions.fileInfo)))
        case "LIST\nOPTS":
            menu.addItem(menuItem(title: "New List", action: #selector(PlaylistFooterMenuActions.newList)))
            menu.addItem(menuItem(title: "Save List…", action: #selector(PlaylistFooterMenuActions.saveList)))
            menu.addItem(menuItem(title: "Load List…", action: #selector(PlaylistFooterMenuActions.loadList)))
        default:
            return
        }

        let actions = PlaylistFooterMenuActions(
            manager: manager,
            keyboardAdapter: keyboardAdapter
        )
        menu.items.forEach { $0.target = actions }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func footerRect(_ local: CGRect, in footer: CGRect) -> CGRect {
        CGRect(
            x: footer.minX + local.minX,
            y: footer.minY + local.minY,
            width: local.width,
            height: local.height
        )
    }

    private func miniTransportLabel(for icon: AmpXIcon) -> String {
        switch icon {
        case .previous: "Previous"
        case .play: "Play"
        case .pause: "Pause"
        case .stop: "Stop"
        case .next: "Next"
        default: "Transport"
        }
    }

    private func transportAction(for icon: AmpXIcon) -> (() -> Void)? {
        switch icon {
        case .previous:
            return { [weak manager] in manager?.previous() }
        case .play:
            return { [weak audioPlayer] in audioPlayer?.playOrResume() }
        case .pause:
            return { [weak audioPlayer] in audioPlayer?.pause() }
        case .stop:
            return { [weak audioPlayer] in audioPlayer?.stop() }
        case .next:
            return { [weak manager] in manager?.next() }
        default:
            return nil
        }
    }
}

@MainActor
private final class PlaylistFooterMenuActions: NSObject {
    private let manager: PlaylistManager
    private let keyboardAdapter: PlaylistKeyboardAdapter

    init(manager: PlaylistManager, keyboardAdapter: PlaylistKeyboardAdapter) {
        self.manager = manager
        self.keyboardAdapter = keyboardAdapter
    }

    @objc func addFile() { manager.showFilePicker() }
    @objc func addDirectory() { manager.showFolderPicker() }

    @objc func removeSelected() { keyboardAdapter.removeSelectedTracks() }
    @objc func cropSelected() { keyboardAdapter.cropToSelection() }
    @objc func clearPlaylist() {
        PlaylistChromeActions.clearList(manager: manager, selection: &keyboardAdapter.selection)
        keyboardAdapter.onSelectionChanged?()
    }

    @objc func selectAll() { keyboardAdapter.selectAll() }
    @objc func selectNone() { PlaylistChromeActions.selectNone(selection: &keyboardAdapter.selection); keyboardAdapter.onSelectionChanged?() }
    @objc func invertSelection() { keyboardAdapter.invertSelection() }

    @objc func sortByTitle() { manager.sortTracks(by: .title) }
    @objc func sortByFilename() { manager.sortTracks(by: .fileName) }
    @objc func sortByPath() { manager.sortTracks(by: .path) }
    @objc func reverseTracks() { manager.reverseTracks() }
    @objc func randomizeTracks() { manager.randomizeTracks() }
    @objc func fileInfo() { PlaylistChromeActions.presentFileInfo(manager: manager, selection: keyboardAdapter.selection) }

    @objc func newList() { clearPlaylist() }
    @objc func saveList() { manager.saveM3UPlaylist() }
    @objc func loadList() { manager.showLoadM3UPicker() }
}

@MainActor
private final class PlaylistFooterTimeReadout: AmpXContinuousView {
    weak var audioPlayer: AudioPlayer?
    weak var playlistManager: PlaylistManager?

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let audioPlayer else { return }

        let backingScale = window?.backingScaleFactor ?? 1
        skin.displayWell(bounds, in: context, backingScale: backingScale)

        let total = playlistManager?.tracks.reduce(0) { $0 + $1.duration } ?? audioPlayer.duration
        let current = audioPlayer.playbackClock.currentTime
        let text = "\(AmpXTimeFormatting.format(current))/\(AmpXTimeFormatting.format(total))"
        AmpXLabel(text: text, color: skin.green, fontSize: 9, weight: .medium, alignment: .center)
            .draw(in: bounds, context: context, skin: skin)
    }
}

@MainActor
private final class PlaylistFooterRemainingReadout: AmpXContinuousView {
    weak var audioPlayer: AudioPlayer?

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let audioPlayer else { return }

        let backingScale = window?.backingScaleFactor ?? 1
        skin.displayWell(bounds, in: context, backingScale: backingScale)

        let remaining = max(0, audioPlayer.duration - audioPlayer.playbackClock.currentTime)
        let text = AmpXTimeFormatting.format(-remaining, showNegative: true)
        AmpXLabel(text: text, color: skin.green, fontSize: 9, weight: .medium, alignment: .center)
            .draw(in: bounds, context: context, skin: skin)
    }
}
