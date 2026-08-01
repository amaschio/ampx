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

    @State private var selectedTrack: Track.ID?
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

                VStack(spacing: 0) {
                    ClassicPlaylistTitleBar(
                        isMinimized: self.$isMinimized,
                        showPlaylist: self.$showPlaylist,
                        scale: self.s
                    )

                    HStack(spacing: 0) {
                        Color.clear.frame(width: 12 * self.s)
                        self.trackList
                        Color.clear.frame(width: 20 * self.s)
                    }

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
                selectedTrack: self.$selectedTrack,
                userInitiatedPlayback: self.$userInitiatedPlayback
            )
            WinampPlaylistKeyboard.register(self.keyboardNavigation)
        }
        .onDisappear {
            WinampPlaylistKeyboard.unregister(self.keyboardNavigation)
            self.keyboardNavigation.unbind()
        }
    }

    private var trackList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.indexedTracks, id: \.track.id) { indexed in
                        ClassicSkinPlaylistRow(
                            index: indexed.index,
                            track: indexed.track,
                            isCurrent: indexed.index == self.playlistManager.currentIndex,
                            isSelected: indexed.track.id == self.selectedTrack,
                            scale: self.s
                        )
                        .id(indexed.track.id)
                        .onTapGesture(count: 2) {
                            self.userInitiatedPlayback = true
                            self.playlistManager.playTrack(at: indexed.index)
                        }
                        .onTapGesture {
                            self.selectedTrack = indexed.track.id
                        }
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
                                if self.selectedTrack == removedID {
                                    self.selectedTrack = nil
                                }
                            }
                            Button("Remove from Disk…", role: .destructive) {
                                let removedID = self.playlistManager.tracks[indexed.index].id
                                if self.playlistManager.removeTrackFromDisk(at: indexed.index),
                                   self.selectedTrack == removedID
                                {
                                    self.selectedTrack = nil
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
                    HStack(spacing: 0) {
                        ClassicPlaylistHitTarget(scale: self.s) {
                            self.playlistManager.showFilePicker()
                        }
                        ClassicPlaylistHitTarget(scale: self.s) {
                            if let selected = self.selectedTrack,
                               let index = self.playlistManager.tracks.firstIndex(where: { $0.id == selected })
                            {
                                self.playlistManager.removeTrack(at: index)
                                self.selectedTrack = nil
                            }
                        }
                        ClassicPlaylistHitTarget(scale: self.s) {
                            if let current = self.playlistManager.currentTrack {
                                self.selectedTrack = current.id
                            }
                        }
                        ClassicPlaylistHitTarget(scale: self.s) {
                            self.playlistManager.showFolderPicker()
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
                        Button("Save Playlist…") { self.playlistManager.saveM3UPlaylist() }
                        Button("Clear Playlist") { self.playlistManager.clearPlaylist() }
                    } label: {
                        Color.clear
                            .frame(width: 44 * self.s, height: 28 * self.s)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .offset(x: 102 * self.s, y: 5 * self.s)
                }
                .frame(width: 142 * self.s, height: ClassicSkinMetrics.playlistBottomBarHeight * self.s)

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomRightBorder, scale: self.s)
            }

            self.resizeGrip
        }
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
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.playlistSize = CGSize(
                                width: max(minWidth, self.resizeStartSize.width + value.translation.width),
                                height: max(minHeight, self.resizeStartSize.height + value.translation.height)
                            )
                        }
                    }
                    .onEnded { _ in self.isDraggingResize = false }
            )
    }

    private var totalDuration: TimeInterval {
        self.playlistManager.tracks.reduce(0) { $0 + $1.duration }
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

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.titleLabel, scale: self.scale)

                ClassicPlaylistTiledStrip(
                    sprite: WinampSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.topRight, scale: self.scale)
            }
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
                let count = max(1, Int(ceil(geo.size.width / tileW)))
                HStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
            case .vertical:
                let tileH = max(self.sprite.height * self.scale, 1)
                let count = max(1, Int(ceil(geo.size.height / tileH)))
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
        .layoutPriority(-1)
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
                .foregroundColor(
                    (self.isCurrent || self.isSelected)
                        ? ClassicSkinColors.playlistCurrent
                        : ClassicSkinColors.playlistText
                )
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(WinampTimeFormatting.format(self.track.duration))
                .winampFont(size: 8, scale: self.scale)
                .foregroundColor(
                    (self.isCurrent || self.isSelected)
                        ? ClassicSkinColors.playlistCurrent
                        : ClassicSkinColors.playlistText
                )
        }
        .padding(.horizontal, 3 * self.scale)
        .frame(height: ClassicSkinMetrics.playlistRowHeight * self.scale)
        .background(
            (self.isSelected || self.isCurrent)
                ? ClassicSkinColors.playlistSelectedBg
                : Color.black
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Bottom bar controls

/// Invisible hit target over a PLEDIT bottom-bar button slot (~22×18).
private struct ClassicPlaylistHitTarget: View {
    var scale: CGFloat = 1.0
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Color.clear
                .frame(width: 22 * self.scale, height: 18 * self.scale)
        }
        .buttonStyle(.plain)
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
