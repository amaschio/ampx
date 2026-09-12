import AppKit
import UniformTypeIdentifiers

@MainActor
final class PlaylistRowsView: AmpXControlView {
    private static let dragThreshold: CGFloat = 6

    weak var manager: PlaylistManager?
    weak var keyboardAdapter: PlaylistKeyboardAdapter?

    var scrollOffset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var onScrollOffsetChange: ((CGFloat) -> Void)?

    private var pressedIndex: Int?
    private var draggedTrackIndex: Int?
    private var dragStartPoint: NSPoint?

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        setAccessibilityRole(.list)
        setAccessibilityLabel("Playlist tracks")
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func revealCursor() {
        guard let adapter = keyboardAdapter,
              let cursorID = adapter.selection.cursorID,
              let index = manager?.tracks.firstIndex(where: { $0.id == cursorID })
        else { return }

        let rowTop = CGFloat(index) * PlaylistRowLayout.rowHeight
        let rowBottom = rowTop + PlaylistRowLayout.rowHeight
        let viewport = bounds.height

        if rowTop < scrollOffset {
            onScrollOffsetChange?(rowTop)
        } else if rowBottom > scrollOffset + viewport {
            onScrollOffsetChange?(rowBottom - viewport)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let manager else { return }

        let backingScale = window?.backingScaleFactor ?? 1
        skin.displayWell(bounds, in: context, backingScale: backingScale)

        let tracks = manager.tracks
        let currentIndex = manager.currentIndex
        let selection = keyboardAdapter?.selection ?? PlaylistSelectionModel()
        let range = PlaylistRowLayout.visibleRange(
            offset: scrollOffset,
            viewport: bounds.height,
            count: tracks.count
        )

        for index in range {
            let track = tracks[index]
            let contentRow = PlaylistRowLayout.rowRect(index: index, width: bounds.width)
            let row = contentRow.offsetBy(dx: 0, dy: -scrollOffset)
            guard row.intersects(bounds) else { continue }

            let isSelected = selection.selectedIDs.contains(track.id)
            let isCurrent = index == currentIndex

            if isSelected {
                context.setFillColor(skin.selection.cgColor)
                context.fill(row)
            }

            let textColor = (isSelected || isCurrent) ? skin.text : skin.green
            let title = "\(index + 1). \(track.artist) - \(track.title)"
            AmpXLabel(text: title, color: textColor, fontSize: 11, weight: .medium)
                .draw(in: PlaylistRowLayout.titleRect(in: row), context: context, skin: skin)

            AmpXLabel(
                text: AmpXTimeFormatting.format(track.duration),
                color: textColor,
                fontSize: 11,
                weight: .medium,
                alignment: .right
            )
            .draw(
                in: PlaylistRowLayout.durationRect(in: row).insetBy(dx: 4, dy: 0),
                context: context,
                skin: skin
            )
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        pressedIndex = trackIndex(at: point)
        dragStartPoint = point
        draggedTrackIndex = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)

        if draggedTrackIndex == nil, let start = dragStartPoint, let pressedIndex {
            let distance = hypot(point.x - start.x, point.y - start.y)
            if distance >= Self.dragThreshold {
                draggedTrackIndex = pressedIndex
            }
        }

        guard let from = draggedTrackIndex,
              let to = trackIndex(at: point),
              from != to
        else { return }

        manager?.moveTrack(from: from, to: to)
        draggedTrackIndex = to
        pressedIndex = to
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        defer {
            pressedIndex = nil
            draggedTrackIndex = nil
            dragStartPoint = nil
        }

        guard draggedTrackIndex == nil,
              let index = pressedIndex,
              let manager,
              index >= 0,
              index < manager.tracks.count
        else { return }

        let track = manager.tracks[index]
        if event.clickCount >= 2 {
            manager.playTrack(at: index)
            return
        }

        applyClickSelection(to: track.id)
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else {
            nextResponder?.scrollWheel(with: event)
            return
        }
        let next = AmpXControlMath.clampedScrollOffset(
            scrollOffset - event.deltaY * 8,
            contentLength: contentLength,
            viewportLength: bounds.height
        )
        guard next != scrollOffset else { return }
        scrollOffset = next
        onScrollOffsetChange?(next)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let manager else { return false }
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) as? [URL], !urls.isEmpty
        else { return false }

        for url in urls {
            manager.importDroppedURL(url)
        }
        return true
    }

    override func isAccessibilityElement() -> Bool {
        false
    }

    override func accessibilityValue() -> Any? {
        guard let manager, let adapter = keyboardAdapter else { return nil }
        let tracks = manager.tracks
        let range = PlaylistRowLayout.visibleRange(
            offset: scrollOffset,
            viewport: bounds.height,
            count: tracks.count
        )
        let visible = range.map { index in
            let track = tracks[index]
            return "\(index + 1). \(track.artist) - \(track.title)"
        }
        let selected = tracks.enumerated().compactMap { index, track -> String? in
            guard adapter.selection.selectedIDs.contains(track.id) else { return nil }
            return "\(index + 1). \(track.artist) - \(track.title)"
        }
        return "Visible rows: \(visible.joined(separator: "; ")). Selected rows: \(selected.joined(separator: "; "))"
    }

    private var contentLength: CGFloat {
        CGFloat(manager?.tracks.count ?? 0) * PlaylistRowLayout.rowHeight
    }

    private func trackIndex(at point: NSPoint) -> Int? {
        guard let manager, !manager.tracks.isEmpty else { return nil }
        let contentY = point.y + scrollOffset
        let index = Int(contentY / PlaylistRowLayout.rowHeight)
        guard index >= 0, index < manager.tracks.count else { return nil }
        return index
    }

    private func applyClickSelection(to id: UUID) {
        guard let adapter = keyboardAdapter else { return }
        let flags = NSEvent.modifierFlags.intersection([.command, .shift])
        let ordered = manager?.tracks.map(\.id) ?? []
        if flags.contains(.shift) {
            adapter.selection.selectRange(to: id, orderedIDs: ordered)
        } else if flags.contains(.command) {
            adapter.selection.toggle(id)
        } else {
            adapter.selection.selectOnly(id)
        }
        keyboardAdapter?.onSelectionChanged?()
        needsDisplay = true
    }
}
