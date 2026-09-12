import AppKit
import SwiftUI

/// Drag-to-reorder for playlist rows.
///
/// Uses a movement-threshold `DragGesture` instead of `onDrag`/`NSItemProvider`. The system
/// drag-and-drop recognizer delays click delivery while it waits to see if the press becomes a
/// drag — that made playlist selection feel sluggish.
struct PlaylistTrackReorderModifier: ViewModifier {
    let trackIndex: Int
    let searchTextEmpty: Bool
    @Binding var draggedTrackIndex: Int?
    let onMove: (Int, Int) -> Void

    private static let dragThreshold: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: Self.dragThreshold)
                    .onChanged { _ in
                        guard self.searchTextEmpty else { return }
                        if self.draggedTrackIndex == nil {
                            self.draggedTrackIndex = self.trackIndex
                        }
                    }
                    .onEnded { _ in
                        self.draggedTrackIndex = nil
                    }
            )
            .overlay {
                if self.searchTextEmpty, self.draggedTrackIndex != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            guard hovering,
                                  let from = self.draggedTrackIndex,
                                  from != self.trackIndex
                            else { return }
                            self.onMove(from, self.trackIndex)
                            self.draggedTrackIndex = self.trackIndex
                        }
                        .allowsHitTesting(true)
                }
            }
    }
}

/// Bridges playlist keyboard commands from `AmpXHotkeys` into view-local selection state.
@MainActor
final class PlaylistKeyboardNavigation: AmpXPlaylistKeyboard.Handling {
    private weak var playlistManager: PlaylistManager?
    private var isMinimized: (() -> Bool)?
    private var visibleTracks: (() -> [(index: Int, track: Track)])?
    private var selection: Binding<PlaylistSelectionModel>?
    private var userInitiatedPlayback: Binding<Bool>?

    func bind(
        playlistManager: PlaylistManager,
        isMinimized: @escaping () -> Bool,
        visibleTracks: @escaping () -> [(index: Int, track: Track)],
        selection: Binding<PlaylistSelectionModel>,
        userInitiatedPlayback: Binding<Bool>
    ) {
        self.playlistManager = playlistManager
        self.isMinimized = isMinimized
        self.visibleTracks = visibleTracks
        self.selection = selection
        self.userInitiatedPlayback = userInitiatedPlayback
    }

    func unbind() {
        self.playlistManager = nil
        self.isMinimized = nil
        self.visibleTracks = nil
        self.selection = nil
        self.userInitiatedPlayback = nil
    }

    func moveSelection(by offset: Int, extend: Bool) {
        guard self.isMinimized?() == false,
              let ordered = self.orderedIDs(),
              !ordered.isEmpty,
              var model = self.selection?.wrappedValue
        else { return }
        model.moveCursor(by: offset, extend: extend, orderedIDs: ordered)
        self.selection?.wrappedValue = model
    }

    func jumpToStart(extend: Bool) {
        guard self.isMinimized?() == false,
              let ordered = self.orderedIDs(),
              var model = self.selection?.wrappedValue
        else { return }
        model.jumpToStart(extend: extend, orderedIDs: ordered)
        self.selection?.wrappedValue = model
    }

    func jumpToEnd(extend: Bool) {
        guard self.isMinimized?() == false,
              let ordered = self.orderedIDs(),
              var model = self.selection?.wrappedValue
        else { return }
        model.jumpToEnd(extend: extend, orderedIDs: ordered)
        self.selection?.wrappedValue = model
    }

    func pageSelection(direction: Int, extend: Bool) {
        guard let ordered = self.orderedIDs() else { return }
        let step = PlaylistSelectionModel.pageStep(count: ordered.count) * (direction >= 0 ? 1 : -1)
        self.moveSelection(by: step, extend: extend)
    }

    func playSelectedTrack() {
        guard let playlistManager = self.playlistManager,
              let visibleTracks = self.visibleTracks?(),
              let model = self.selection?.wrappedValue
        else { return }

        let playID = model.cursorID
            ?? model.selectedIDs.first
        guard let playID,
              let indexed = visibleTracks.first(where: { $0.track.id == playID })
        else { return }

        self.userInitiatedPlayback?.wrappedValue = true
        playlistManager.playTrack(at: indexed.index)
    }

    func removeSelectedTracks() {
        guard let playlistManager = self.playlistManager,
              let indices = self.selectedIndices(),
              !indices.isEmpty
        else { return }
        playlistManager.removeTracks(at: indices)
        self.pruneSelectionToPlaylist()
    }

    func cropToSelection() {
        guard let playlistManager = self.playlistManager,
              let indices = self.selectedIndices(),
              !indices.isEmpty
        else { return }
        playlistManager.cropToTracks(at: indices)
        self.pruneSelectionToPlaylist()
    }

    func clearSelection() {
        self.selection?.wrappedValue = PlaylistSelectionModel()
    }

    func selectAll() {
        guard let ordered = self.orderedIDs(),
              var model = self.selection?.wrappedValue
        else { return }
        model.selectAll(orderedIDs: ordered)
        self.selection?.wrappedValue = model
    }

    func invertSelection() {
        guard let ordered = self.orderedIDs(),
              var model = self.selection?.wrappedValue
        else { return }
        model.invert(orderedIDs: ordered)
        self.selection?.wrappedValue = model
    }

    func moveSelectedTracks(by delta: Int) {
        guard let playlistManager = self.playlistManager,
              let indices = self.selectedIndices(),
              !indices.isEmpty
        else { return }
        let selectedIDs = self.selection?.wrappedValue.selectedIDs ?? []
        let cursorID = self.selection?.wrappedValue.cursorID
        let anchorID = self.selection?.wrappedValue.anchorID
        playlistManager.moveSelectedTracks(indices: indices, by: delta)
        // Selection is by track id — still valid after reorder.
        var model = PlaylistSelectionModel()
        model.selectedIDs = selectedIDs
        model.cursorID = cursorID
        model.anchorID = anchorID
        self.selection?.wrappedValue = model
    }

    private func orderedIDs() -> [UUID]? {
        self.visibleTracks?().map(\.track.id)
    }

    private func selectedIndices() -> IndexSet? {
        guard let visibleTracks = self.visibleTracks?(),
              let selected = self.selection?.wrappedValue.selectedIDs,
              !selected.isEmpty
        else { return nil }
        var indices = IndexSet()
        for item in visibleTracks where selected.contains(item.track.id) {
            indices.insert(item.index)
        }
        return indices
    }

    private func pruneSelectionToPlaylist() {
        guard var model = self.selection?.wrappedValue else { return }
        let valid = Set(self.playlistManager?.tracks.map(\.id) ?? [])
        model.prune(toValidIDs: valid)
        self.selection?.wrappedValue = model
    }
}
