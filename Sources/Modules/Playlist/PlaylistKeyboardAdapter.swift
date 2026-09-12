import Foundation

@MainActor
final class PlaylistKeyboardAdapter: AmpXPlaylistKeyboard.Handling {
    private let manager: PlaylistManager

    var selection = PlaylistSelectionModel()
    var onSelectionChanged: (() -> Void)?
    var onRevealCursor: (() -> Void)?

    init(manager: PlaylistManager) {
        self.manager = manager
    }

    func moveSelection(by offset: Int, extend: Bool) {
        let ordered = orderedIDs()
        guard !ordered.isEmpty else { return }
        selection.moveCursor(by: offset, extend: extend, orderedIDs: ordered)
        notifySelectionChanged(revealCursor: true)
    }

    func jumpToStart(extend: Bool) {
        let ordered = orderedIDs()
        guard !ordered.isEmpty else { return }
        selection.jumpToStart(extend: extend, orderedIDs: ordered)
        notifySelectionChanged(revealCursor: true)
    }

    func jumpToEnd(extend: Bool) {
        let ordered = orderedIDs()
        guard !ordered.isEmpty else { return }
        selection.jumpToEnd(extend: extend, orderedIDs: ordered)
        notifySelectionChanged(revealCursor: true)
    }

    func pageSelection(direction: Int, extend: Bool) {
        let ordered = orderedIDs()
        guard !ordered.isEmpty else { return }
        let step = PlaylistSelectionModel.pageStep(count: ordered.count) * (direction >= 0 ? 1 : -1)
        moveSelection(by: step, extend: extend)
    }

    func playSelectedTrack() {
        let playID = selection.cursorID ?? selection.selectedIDs.first
        guard let playID,
              let index = manager.tracks.firstIndex(where: { $0.id == playID })
        else { return }
        manager.playTrack(at: index)
    }

    func removeSelectedTracks() {
        PlaylistChromeActions.removeSelected(manager: manager, selection: &selection)
        notifySelectionChanged()
    }

    func cropToSelection() {
        PlaylistChromeActions.cropToSelected(manager: manager, selection: &selection)
        notifySelectionChanged()
    }

    func clearSelection() {
        selection = PlaylistSelectionModel()
        notifySelectionChanged()
    }

    func selectAll() {
        selection.selectAll(orderedIDs: orderedIDs())
        notifySelectionChanged()
    }

    func invertSelection() {
        selection.invert(orderedIDs: orderedIDs())
        notifySelectionChanged()
    }

    func moveSelectedTracks(by delta: Int) {
        let indices = selectedIndices()
        guard !indices.isEmpty else { return }
        let selectedIDs = selection.selectedIDs
        let cursorID = selection.cursorID
        let anchorID = selection.anchorID
        manager.moveSelectedTracks(indices: indices, by: delta)
        selection = PlaylistSelectionModel()
        selection.selectedIDs = selectedIDs
        selection.cursorID = cursorID
        selection.anchorID = anchorID
        notifySelectionChanged(revealCursor: true)
    }

    private func orderedIDs() -> [UUID] {
        manager.tracks.map(\.id)
    }

    private func selectedIndices() -> IndexSet {
        PlaylistChromeActions.selectedIndices(tracks: manager.tracks, selection: selection)
    }

    private func notifySelectionChanged(revealCursor: Bool = false) {
        onSelectionChanged?()
        if revealCursor {
            onRevealCursor?()
        }
    }
}
