import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Classic Winamp 2.x playlist editor: green-on-black 13 px rows framed by the
/// PLEDIT-style chrome (20 px title bar, 38 px bottom bar), resizable from the
/// bottom-right grip.
struct ClassicPlaylistView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.winampUIScale) private var uiScale
    @Binding var playlistSize: CGSize
    @Binding var isMinimized: Bool
    @Binding var showPlaylist: Bool

    @State private var selection = PlaylistSelectionModel()
    @State private var isDraggingResize = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var draggedTrackIndex: Int?
    @State private var keyboardNavigation = PlaylistKeyboardNavigation()
    @State private var userInitiatedPlayback = false

    private var s: CGFloat {
        self.uiScale
    }

    private var indexedTracks: [(index: Int, track: Track)] {
        Array(self.playlistManager.tracks.enumerated()).map { (index: $0.offset, track: $0.element) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if self.isMinimized {
                ClassicPlaylistShadeBar(
                    isMinimized: self.$isMinimized,
                    showPlaylist: self.$showPlaylist,
                    scale: self.s
                )
            } else {
                // Side rails run full height behind title/bottom so junctions stay covered.
                HStack(spacing: 0) {
                    ClassicPlaylistTiledStrip(
                        sprite: WinampSkinSprites.Pledit.leftTile,
                        scale: self.s,
                        axis: .vertical
                    )
                    .frame(width: 12 * self.s)
                    .frame(maxHeight: .infinity)

                    Spacer(minLength: 0)

                    ClassicPlaylistTiledStrip(
                        sprite: WinampSkinSprites.Pledit.rightTile,
                        scale: self.s,
                        axis: .vertical
                    )
                    .frame(width: 20 * self.s)
                    .frame(maxHeight: .infinity)
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    ClassicPlaylistTitleBar(
                        isMinimized: self.$isMinimized,
                        showPlaylist: self.$showPlaylist,
                        scale: self.s
                    )

                    HStack(spacing: 0) {
                        Color.clear.frame(width: 12 * self.s)
                        self.trackList
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Color.clear.frame(width: 20 * self.s)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    self.bottomBar
                        .frame(height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)
                }
            }
        }
        .background(self.isMinimized ? Color.clear : ClassicSkinColors.body)
        .frame(
            width: self.playlistSize.width,
            height: self.isMinimized
                ? ClassicSkinMetrics.playlistShadeHeight * self.s
                : self.playlistSize.height
        )
        .clipped()
        .onAppear {
            self.keyboardNavigation.bind(
                playlistManager: self.playlistManager,
                isMinimized: { self.isMinimized },
                visibleTracks: { self.indexedTracks },
                selection: self.$selection,
                userInitiatedPlayback: self.$userInitiatedPlayback
            )
            WinampPlaylistKeyboard.register(self.keyboardNavigation)
        }
        .onDisappear {
            WinampPlaylistKeyboard.unregister(self.keyboardNavigation)
            self.keyboardNavigation.unbind()
        }
        .onChange(of: self.playlistManager.tracks.map(\.id)) { ids in
            var model = self.selection
            model.prune(toValidIDs: Set(ids))
            self.selection = model
        }
    }

    private var trackList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.indexedTracks, id: \.track.id) { indexed in
                        Button {
                            self.applyClickSelection(to: indexed.track.id)
                        } label: {
                            ClassicSkinPlaylistRow(
                                index: indexed.index,
                                track: indexed.track,
                                isCurrent: indexed.index == self.playlistManager.currentIndex,
                                isSelected: self.selection.selectedIDs.contains(indexed.track.id),
                                scale: self.s
                            )
                        }
                        .buttonStyle(.plain)
                        .id(indexed.track.id)
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                self.userInitiatedPlayback = true
                                self.playlistManager.playTrack(at: indexed.index)
                            }
                        )
                        .contextMenu {
                            Button("Play") {
                                self.userInitiatedPlayback = true
                                self.playlistManager.playTrack(at: indexed.index)
                            }
                            Button("Get Info") {
                                self.playlistManager.presentTrackInfo(at: indexed.index)
                            }
                            Divider()
                            Button("Remove from Playlist") {
                                let removedID = self.playlistManager.tracks[indexed.index].id
                                self.playlistManager.removeTrack(at: indexed.index)
                                self.selection.prune(toValidIDs: Set(self.playlistManager.tracks.map(\.id)))
                                _ = removedID
                            }
                            Button("Remove from Disk…", role: .destructive) {
                                if self.playlistManager.removeTrackFromDisk(at: indexed.index) {
                                    self.selection.prune(toValidIDs: Set(self.playlistManager.tracks.map(\.id)))
                                }
                            }
                        }
                        .modifier(PlaylistTrackReorderModifier(
                            trackIndex: indexed.index,
                            searchTextEmpty: true,
                            draggedTrackIndex: self.$draggedTrackIndex,
                            onMove: { from, to in
                                self.playlistManager.moveTrack(from: from, to: to)
                            }
                        ))
                    }
                }
            }
            .background(Color.black)
            .onChange(of: self.playlistManager.currentIndex) { newIndex in
                guard newIndex >= 0, newIndex < self.playlistManager.tracks.count else { return }
                proxy.scrollTo(self.playlistManager.tracks[newIndex].id, anchor: .center)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                self.handleDrop(providers: providers)
                return true
            }
        }
    }

    private var bottomBar: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                // Widen left chrome by moving the 8px border out of the button sprite.
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomLeftBorder, scale: self.s)
                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomLeftInset, scale: self.s)
                        .allowsHitTesting(false)
                    HStack(spacing: 0) {
                        ClassicPlaylistMenuSlot(scale: self.s) {
                            Button("Add File…") { self.playlistManager.showFilePicker() }
                            Button("Add Directory…") { self.playlistManager.showFolderPicker() }
                        }
                        ClassicPlaylistMenuSlot(scale: self.s) {
                            Button("Remove") {
                                var model = self.selection
                                PlaylistChromeActions.removeSelected(manager: self.playlistManager, selection: &model)
                                self.selection = model
                            }
                            .disabled(self.selection.isEmpty)
                            Button("Crop") {
                                var model = self.selection
                                PlaylistChromeActions.cropToSelected(manager: self.playlistManager, selection: &model)
                                self.selection = model
                            }
                            .disabled(self.selection.isEmpty)
                            Button("Clear Playlist") {
                                var model = self.selection
                                PlaylistChromeActions.clearList(manager: self.playlistManager, selection: &model)
                                self.selection = model
                            }
                        }
                        ClassicPlaylistMenuSlot(scale: self.s) {
                            Button("Select All") {
                                var model = self.selection
                                PlaylistChromeActions.selectAll(tracks: self.playlistManager.tracks, selection: &model)
                                self.selection = model
                            }
                            Button("Select None") {
                                var model = self.selection
                                PlaylistChromeActions.selectNone(selection: &model)
                                self.selection = model
                            }
                            Button("Invert Selection") {
                                var model = self.selection
                                PlaylistChromeActions.invertSelection(tracks: self.playlistManager.tracks, selection: &model)
                                self.selection = model
                            }
                        }
                        ClassicPlaylistMenuSlot(scale: self.s) {
                            Button("Sort by Title") { self.playlistManager.sortTracks(by: .title) }
                            Button("Sort by Filename") { self.playlistManager.sortTracks(by: .fileName) }
                            Button("Sort by Path") { self.playlistManager.sortTracks(by: .path) }
                            Button("Reverse") { self.playlistManager.reverseTracks() }
                            Button("Randomize") { self.playlistManager.randomizeTracks() }
                            Button("File Info") {
                                PlaylistChromeActions.presentFileInfo(
                                    manager: self.playlistManager,
                                    selection: self.selection
                                )
                            }
                            .disabled(
                                PlaylistChromeActions.fileInfoIndex(
                                    tracks: self.playlistManager.tracks,
                                    selection: self.selection,
                                    currentIndex: self.playlistManager.currentIndex
                                ) == nil
                            )
                        }
                    }
                    // Faces at ~6,12 inside the inset sprite (was 14,12 in full bottomLeft)
                    .offset(x: 6 * self.s, y: 12 * self.s)
                }
                .frame(width: 117 * self.s, height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)

                ClassicPlaylistTiledStrip(sprite: WinampSkinSprites.Pledit.bottomTile, scale: self.s)
                    .frame(maxWidth: .infinity)
                    .frame(height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)

                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomRightInset, scale: self.s)
                        .allowsHitTesting(false)

                    ClassicPlaylistTimeReadout(totalDuration: self.totalDuration, scale: self.s)
                        .frame(width: 92 * self.s, height: 10 * self.s)
                        .background(Color.black)
                        .clipped()
                        .offset(x: 5 * self.s, y: 8 * self.s)

                    ClassicPlaylistRemainingTimeLabel(scale: self.s)
                        .frame(width: 34 * self.s, height: 8 * self.s)
                        .background(Color.black)
                        .clipped()
                        .offset(x: 63 * self.s, y: 22 * self.s)

                    Menu {
                        Button("New List") {
                            var model = self.selection
                            PlaylistChromeActions.clearList(manager: self.playlistManager, selection: &model)
                            self.selection = model
                        }
                        Button("Save List…") { self.playlistManager.saveM3UPlaylist() }
                        Button("Load List…") { self.playlistManager.showLoadM3UPicker() }
                    } label: {
                        Color.clear
                            .frame(width: 44 * self.s, height: 28 * self.s)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .offset(x: 102 * self.s, y: 5 * self.s)
                }
                .frame(width: 142 * self.s, height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomRightBorder, scale: self.s)
            }
            // Fill the panel width so ZStack's trailing alignment can't pin a
            // content-sized HStack and clip the leading chrome when widened.
            .frame(maxWidth: .infinity, alignment: .leading)

            self.resizeGrip
        }
        .frame(maxWidth: .infinity)
        .frame(height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)
        .background(ClassicSkinColors.body)
        .contentShape(Rectangle())
    }

    private var resizeGrip: some View {
        // Skin already draws the BR hatch in bottomRight — keep an invisible hit target only.
        Color.clear
            .frame(width: 12 * self.s, height: 12 * self.s)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !self.isDraggingResize {
                            self.resizeStartSize = self.playlistSize
                            self.isDraggingResize = true
                        }
                        let minWidth = ClassicSkinMetrics.windowWidth * self.s
                        let minHeight = ClassicSkinMetrics.playlistMinHeight * self.s
                        let newSize = CGSize(
                            width: max(minWidth, self.resizeStartSize.width + value.translation.width),
                            height: max(minHeight, self.resizeStartSize.height + value.translation.height)
                        )
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.playlistSize = newSize
                        }
                        // Grow/shrink the NSWindow in the same turn as the SwiftUI frame so
                        // `.clipped()` doesn't chop chrome while content leads the window.
                        WinampPanelWindowManager.shared.resizePlaylistPanel()
                    }
                    .onEnded { _ in self.isDraggingResize = false }
            )
    }

    private var totalDuration: TimeInterval {
        self.playlistManager.tracks.reduce(0) { $0 + $1.duration }
    }

    private func applyClickSelection(to id: UUID) {
        let flags = NSEvent.modifierFlags.intersection([.command, .shift])
        let ordered = self.indexedTracks.map(\.track.id)
        if flags.contains(.shift) {
            self.selection.selectRange(to: id, orderedIDs: ordered)
        } else if flags.contains(.command) {
            self.selection.toggle(id)
        } else {
            self.selection.selectOnly(id)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    self.playlistManager.importDroppedURL(url)
                }
            }
        }
    }
}

// MARK: - Playlist title bar (PLEDIT chrome)

private struct ClassicPlaylistTitleBar: View {
    @Binding var isMinimized: Bool
    @Binding var showPlaylist: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.topLeft, scale: self.scale)

                ClassicPlaylistTiledStrip(
                    sprite: WinampSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.titleLabel, scale: self.scale)

                ClassicPlaylistTiledStrip(
                    sprite: WinampSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.topRight, scale: self.scale)
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            // Drag everywhere except the trailing shade/close icons.
            PanelTitleBarDragOverlay()
                .padding(.trailing, 28 * self.scale)

            HStack(spacing: 3 * self.scale) {
                Spacer(minLength: 0)
                Button { self.isMinimized.toggle() } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { self.showPlaylist = false } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4 * self.scale)
            .padding(.top, 3 * self.scale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ClassicSkinMetrics.playlistTopBarHeight * self.scale)
        .background(ClassicSkinColors.body)
        .accessibilityLabel("RE:AMP PLAYLIST")
    }
}

/// 14 px pledit windowshade strip (Webamp PLAYLIST_SHADE_*).
private struct ClassicPlaylistShadeBar: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var isMinimized: Bool
    @Binding var showPlaylist: Bool
    var scale: CGFloat = 1.0

    private var timeLabel: String {
        let current = WinampTimeFormatting.format(self.clock.currentTime)
        let total = WinampTimeFormatting.format(
            self.playlistManager.currentTrack?.duration ?? self.audioPlayer.duration
        )
        return "\(current)/\(total)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.shadeLeft, scale: self.scale)

                ClassicPlaylistTiledStrip(
                    sprite: WinampSkinSprites.Pledit.shadeTile,
                    scale: self.scale,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)
                .frame(height: ClassicSkinMetrics.playlistShadeHeight * self.scale)

                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.Pledit.shadeRight, scale: self.scale)

                    // Time sits in the shade-right black well (before the mini-viz / buttons).
                    ClassicPlaylistShadeTime(text: self.timeLabel, scale: self.scale)
                        .offset(x: 2 * self.scale, y: 4 * self.scale)
                }
            }
            .allowsHitTesting(false)

            PanelTitleBarDragOverlay()
                .padding(.trailing, 28 * self.scale)

            HStack(spacing: 3 * self.scale) {
                Spacer(minLength: 0)
                Button { self.isMinimized = false } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { self.showPlaylist = false } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4 * self.scale)
            .padding(.top, 3 * self.scale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ClassicSkinMetrics.playlistShadeHeight * self.scale)
        .accessibilityLabel("RE:AMP PLAYLIST")
    }
}

private struct ClassicPlaylistShadeTime: View {
    let text: String
    var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(self.text.lowercased().enumerated()), id: \.offset) { _, char in
                if let pos = ClassicMarqueeTypography.fontLookup[char] {
                    SkinSpriteView(
                        sprite: Sprite(
                            sheet: .text,
                            x: CGFloat(pos.col) * 5,
                            y: CGFloat(pos.row) * 6,
                            width: 5,
                            height: 6
                        ),
                        scale: self.scale
                    )
                }
            }
        }
    }
}

private enum ClassicPlaylistTileAxis {
    case horizontal
    case vertical
}

/// Repeats a pledit strip sprite along one axis without stretching.
private struct ClassicPlaylistTiledStrip: View {
    let sprite: Sprite
    var scale: CGFloat = 1.0
    var axis: ClassicPlaylistTileAxis = .horizontal

    var body: some View {
        GeometryReader { geo in
            switch self.axis {
            case .horizontal:
                let tileW = max(self.sprite.width * self.scale, 1)
                let count = ClassicPleditTiling.tileCount(
                    containerLength: geo.size.width,
                    tileLength: tileW
                )
                HStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
            case .vertical:
                let tileH = max(self.sprite.height * self.scale, 1)
                let count = ClassicPleditTiling.tileCount(
                    containerLength: geo.size.height,
                    tileLength: tileH
                )
                VStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
            }
        }
        .frame(
            maxWidth: self.axis == .horizontal ? .infinity : nil,
            maxHeight: self.axis == .vertical ? .infinity : nil
        )
        .frame(
            width: self.axis == .vertical ? self.sprite.width * self.scale : nil,
            height: self.axis == .horizontal ? self.sprite.height * self.scale : nil
        )
        .clipped()
    }
}

/// Shared pledit tile-count math (playlist + MilkDrop chrome).
enum ClassicPleditTiling {
    /// How many sprite tiles are needed to cover `containerLength` without stretching.
    /// Returns 0 when the flex slot has no measurable size so a forced tile can't overflow.
    static func tileCount(containerLength: CGFloat, tileLength: CGFloat) -> Int {
        guard containerLength > 0.5, tileLength > 0 else { return 0 }
        return Int(ceil(containerLength / tileLength))
    }
}

// MARK: - Row

private struct ClassicSkinPlaylistRow: View {
    let index: Int
    let track: Track
    let isCurrent: Bool
    let isSelected: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            Text("\(self.index + 1). \(self.track.artist) - \(self.track.title)")
                .winampFont(size: 8, scale: self.scale)
                .foregroundColor(self.rowForeground)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(WinampTimeFormatting.format(self.track.duration))
                .winampFont(size: 8, scale: self.scale)
                .foregroundColor(self.rowForeground)
        }
        .padding(.horizontal, 3 * self.scale)
        .frame(height: ClassicSkinMetrics.playlistRowHeight * self.scale)
        // PLEDIT: only the selection cursor gets the blue bar. The playing track is
        // white-on-black unless it is also selected (otherwise two rows look "selected").
        .background(self.isSelected ? ClassicSkinColors.playlistSelectedBg : Color.black)
        .contentShape(Rectangle())
    }

    private var rowForeground: Color {
        if self.isSelected || self.isCurrent {
            ClassicSkinColors.playlistCurrent
        } else {
            ClassicSkinColors.playlistText
        }
    }
}

// MARK: - Bottom bar controls

/// Invisible menu label over a PLEDIT bottom-bar button slot (~22×18).
private struct ClassicPlaylistMenuSlot<Content: View>: View {
    var scale: CGFloat = 1.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            self.content()
        } label: {
            Color.clear
                .frame(width: 22 * self.scale, height: 18 * self.scale)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

/// `elapsed/total` green readout in the playlist bottom bar.
private struct ClassicPlaylistTimeReadout: View {
    @EnvironmentObject var clock: PlaybackClock
    let totalDuration: TimeInterval
    var scale: CGFloat = 1.0

    var body: some View {
        Text("\(WinampTimeFormatting.format(self.clock.currentTime))/\(WinampTimeFormatting.format(self.totalDuration))")
            .winampFont(size: 7, weight: .bold, scale: self.scale)
            .foregroundColor(ClassicSkinColors.led)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Remaining-time box on the playlist bottom-right chrome.
private struct ClassicPlaylistRemainingTimeLabel: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    var scale: CGFloat = 1.0

    var body: some View {
        let remaining = max(0, self.audioPlayer.duration - self.clock.currentTime)
        Text(WinampTimeFormatting.format(-remaining, showNegative: true))
            .winampFont(size: 6, weight: .bold, scale: self.scale)
            .foregroundColor(ClassicSkinColors.led)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
