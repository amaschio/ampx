import SwiftUI

/// Drag-to-reorder modifier for playlist rows (disabled when a search filter is active).
struct PlaylistTrackReorderModifier: ViewModifier {
    let trackIndex: Int
    let searchTextEmpty: Bool
    @Binding var draggedTrackIndex: Int?
    let onMove: (Int, Int) -> Void

    func body(content: Content) -> some View {
        content
            .onDrag {
                guard self.searchTextEmpty else {
                    return NSItemProvider()
                }
                self.draggedTrackIndex = self.trackIndex
                return NSItemProvider(object: String(self.trackIndex) as NSString)
            }
            .onDrop(
                of: [.plainText],
                delegate: PlaylistRowDropDelegate(
                    destinationIndex: self.trackIndex,
                    draggedIndex: self.$draggedTrackIndex,
                    isEnabled: self.searchTextEmpty,
                    onMove: self.onMove
                )
            )
    }
}

struct PlaylistRowDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var draggedIndex: Int?
    let isEnabled: Bool
    let onMove: (Int, Int) -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        self.isEnabled && self.draggedIndex != nil
    }

    func dropEntered(info _: DropInfo) {
        guard self.isEnabled, let from = draggedIndex, from != destinationIndex else { return }
        self.onMove(from, self.destinationIndex)
        self.draggedIndex = self.destinationIndex
    }

    func performDrop(info _: DropInfo) -> Bool {
        self.draggedIndex = nil
        return true
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: self.isEnabled ? .move : .forbidden)
    }
}

/// Bridges playlist keyboard commands from `AppDelegate` into view-local selection state.
@MainActor
final class PlaylistKeyboardNavigation: WinampPlaylistKeyboard.Handling {
    private weak var playlistManager: PlaylistManager?
    private var isMinimized: (() -> Bool)?
    private var visibleTracks: (() -> [(index: Int, track: Track)])?
    private var selectedTrack: Binding<Track.ID?>?
    private var userInitiatedPlayback: Binding<Bool>?

    func bind(
        playlistManager: PlaylistManager,
        isMinimized: @escaping () -> Bool,
        visibleTracks: @escaping () -> [(index: Int, track: Track)],
        selectedTrack: Binding<Track.ID?>,
        userInitiatedPlayback: Binding<Bool>
    ) {
        self.playlistManager = playlistManager
        self.isMinimized = isMinimized
        self.visibleTracks = visibleTracks
        self.selectedTrack = selectedTrack
        self.userInitiatedPlayback = userInitiatedPlayback
    }

    func unbind() {
        self.playlistManager = nil
        self.isMinimized = nil
        self.visibleTracks = nil
        self.selectedTrack = nil
        self.userInitiatedPlayback = nil
    }

    func moveSelection(by offset: Int) {
        guard self.isMinimized?() == false,
              let visibleTracks = self.visibleTracks?(),
              !visibleTracks.isEmpty,
              let selectedTrack = self.selectedTrack
        else { return }

        let anchorIndex = Self.anchorVisibleIndex(
            in: visibleTracks,
            selectedID: selectedTrack.wrappedValue,
            currentPlaylistIndex: self.playlistManager?.currentIndex ?? -1
        )
        let nextIndex = min(max(anchorIndex + offset, 0), visibleTracks.count - 1)
        selectedTrack.wrappedValue = visibleTracks[nextIndex].track.id
    }

    func playSelectedTrack() {
        guard let playlistManager = self.playlistManager,
              let visibleTracks = self.visibleTracks?(),
              let selectedID = self.selectedTrack?.wrappedValue,
              let indexedTrack = visibleTracks.first(where: { $0.track.id == selectedID })
        else { return }

        self.userInitiatedPlayback?.wrappedValue = true
        playlistManager.playTrack(at: indexedTrack.index)
    }

    private static func anchorVisibleIndex(
        in visibleTracks: [(index: Int, track: Track)],
        selectedID: Track.ID?,
        currentPlaylistIndex: Int
    ) -> Int {
        if let selectedID,
           let selectedIndex = visibleTracks.firstIndex(where: { $0.track.id == selectedID })
        {
            return selectedIndex
        }
        if currentPlaylistIndex >= 0,
           let currentIndex = visibleTracks.firstIndex(where: { $0.index == currentPlaylistIndex })
        {
            return currentIndex
        }
        return 0
    }
}
