import AppKit
import Combine
import CoreGraphics

final class PlaylistModuleContent: AmpXModuleContent {
    private let manager: PlaylistManager
    private let audioPlayer: AudioPlayer
    private let keyboardAdapter: PlaylistKeyboardAdapter
    private let rowsView: PlaylistRowsView
    private let footerView: PlaylistFooterView
    private let scrollbar: AmpXScrollbar

    private var rowViewportHeight = AmpXMetrics.playlistRows.height
    private var cancellables = Set<AnyCancellable>()
    private var playlistIsActive = false

    var canScrollVertically: Bool {
        scrollbar.contentLength > scrollbar.viewportLength
    }

    init(
        skin: any AmpXSkin,
        manager: PlaylistManager,
        audioPlayer: AudioPlayer
    ) {
        self.manager = manager
        self.audioPlayer = audioPlayer
        self.keyboardAdapter = PlaylistKeyboardAdapter(manager: manager)
        self.rowsView = PlaylistRowsView(skin: skin)
        self.footerView = PlaylistFooterView(
            skin: skin,
            manager: manager,
            audioPlayer: audioPlayer,
            keyboardAdapter: keyboardAdapter
        )
        self.scrollbar = AmpXScrollbar(skin: skin)
        super.init(skin: skin)
        configureControls()
        bindModels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            if playlistIsActive {
                AmpXPlaylistKeyboard.unregister(keyboardAdapter)
            }
        }
    }

    override func setEffectivelyVisible(_ visible: Bool) {
        super.setEffectivelyVisible(visible)
        footerView.setEffectivelyVisible(visible)
        guard visible != playlistIsActive else { return }
        playlistIsActive = visible
        if visible {
            AmpXPlaylistKeyboard.register(keyboardAdapter)
        } else {
            AmpXPlaylistKeyboard.unregister(keyboardAdapter)
        }
    }

    func setRowViewportHeight(_ height: CGFloat) {
        rowViewportHeight = max(height, AmpXMetrics.minimumPlaylistViewportHeight)
        scrollbar.viewportLength = rowViewportHeight
        layoutControls()
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        if canScrollVertically {
            scrollbar.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func configureControls() {
        rowsView.manager = manager
        rowsView.keyboardAdapter = keyboardAdapter
        rowsView.onScrollOffsetChange = { [weak self] offset in
            self?.setScrollOffset(offset)
        }

        keyboardAdapter.onSelectionChanged = { [weak self] in
            self?.rowsView.needsDisplay = true
        }
        keyboardAdapter.onRevealCursor = { [weak self] in
            self?.rowsView.revealCursor()
        }

        scrollbar.onScroll = { [weak self] offset in
            self?.setScrollOffset(offset)
        }

        addSubview(rowsView)
        addSubview(footerView)
        addSubview(scrollbar)
        updateScrollbarMetrics()
        layoutControls()
    }

    private func bindModels() {
        manager.$tracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                self.keyboardAdapter.selection.prune(toValidIDs: Set(tracks.map(\.id)))
                self.updateScrollbarMetrics()
                self.rowsView.needsDisplay = true
            }
            .store(in: &cancellables)

        manager.$currentIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rowsView.needsDisplay = true
            }
            .store(in: &cancellables)
    }

    private func setScrollOffset(_ offset: CGFloat) {
        scrollbar.offset = offset
        rowsView.scrollOffset = offset
    }

    private func updateScrollbarMetrics() {
        scrollbar.contentLength = CGFloat(manager.tracks.count) * PlaylistRowLayout.rowHeight
        scrollbar.viewportLength = rowViewportHeight
        let clamped = AmpXControlMath.clampedScrollOffset(
            scrollbar.offset,
            contentLength: scrollbar.contentLength,
            viewportLength: scrollbar.viewportLength
        )
        if clamped != scrollbar.offset {
            setScrollOffset(clamped)
        }
    }

    private func layoutControls() {
        let rowsFrame = CGRect(
            x: AmpXMetrics.playlistRows.minX,
            y: AmpXMetrics.playlistRows.minY,
            width: AmpXMetrics.playlistRows.width,
            height: rowViewportHeight
        )
        rowsView.frame = rowsFrame
        scrollbar.frame = CGRect(
            x: AmpXMetrics.playlistScrollbar.minX,
            y: rowsFrame.minY,
            width: AmpXMetrics.playlistScrollbar.width,
            height: rowViewportHeight
        )
        footerView.frame = AmpXMetrics.playlistFooter
    }
}
