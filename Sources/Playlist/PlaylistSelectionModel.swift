import Foundation

/// Pure playlist selection cursor / multi-select state (PLEDIT-style).
struct PlaylistSelectionModel: Equatable {
    var selectedIDs: Set<UUID> = []
    /// Origin for Shift-click / Shift-arrow ranges.
    var anchorID: UUID?
    /// Keyboard / click focus row.
    var cursorID: UUID?

    var isEmpty: Bool {
        self.selectedIDs.isEmpty
    }

    mutating func selectOnly(_ id: UUID) {
        self.selectedIDs = [id]
        self.anchorID = id
        self.cursorID = id
    }

    mutating func toggle(_ id: UUID) {
        if self.selectedIDs.contains(id) {
            self.selectedIDs.remove(id)
        } else {
            self.selectedIDs.insert(id)
            if self.anchorID == nil {
                self.anchorID = id
            }
        }
        self.cursorID = id
    }

    /// Inclusive range from `anchorID` (or cursor / `id`) to `id` along `orderedIDs`.
    mutating func selectRange(to id: UUID, orderedIDs: [UUID]) {
        let anchor = self.anchorID ?? self.cursorID ?? id
        guard let anchorIndex = orderedIDs.firstIndex(of: anchor),
              let targetIndex = orderedIDs.firstIndex(of: id)
        else {
            self.selectOnly(id)
            return
        }
        let lo = min(anchorIndex, targetIndex)
        let hi = max(anchorIndex, targetIndex)
        self.selectedIDs = Set(orderedIDs[lo ... hi])
        self.cursorID = id
        if self.anchorID == nil {
            self.anchorID = anchor
        }
    }

    mutating func moveCursor(by offset: Int, extend: Bool, orderedIDs: [UUID]) {
        guard !orderedIDs.isEmpty else { return }
        let currentIndex = self.cursorID.flatMap { orderedIDs.firstIndex(of: $0) }
            ?? orderedIDs.firstIndex(where: { self.selectedIDs.contains($0) })
            ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), orderedIDs.count - 1)
        let nextID = orderedIDs[nextIndex]
        if extend {
            if self.anchorID == nil {
                self.anchorID = self.cursorID ?? orderedIDs[currentIndex]
            }
            self.selectRange(to: nextID, orderedIDs: orderedIDs)
        } else {
            self.selectOnly(nextID)
        }
    }

    mutating func jumpToStart(extend: Bool, orderedIDs: [UUID]) {
        guard let first = orderedIDs.first else { return }
        if extend {
            if self.anchorID == nil {
                self.anchorID = self.cursorID ?? first
            }
            self.selectRange(to: first, orderedIDs: orderedIDs)
        } else {
            self.selectOnly(first)
        }
    }

    mutating func jumpToEnd(extend: Bool, orderedIDs: [UUID]) {
        guard let last = orderedIDs.last else { return }
        if extend {
            if self.anchorID == nil {
                self.anchorID = self.cursorID ?? last
            }
            self.selectRange(to: last, orderedIDs: orderedIDs)
        } else {
            self.selectOnly(last)
        }
    }

    mutating func selectAll(orderedIDs: [UUID]) {
        self.selectedIDs = Set(orderedIDs)
        self.anchorID = orderedIDs.first
        self.cursorID = orderedIDs.last
    }

    mutating func invert(orderedIDs: [UUID]) {
        let all = Set(orderedIDs)
        self.selectedIDs = all.subtracting(self.selectedIDs)
        if let cursor = self.cursorID, !self.selectedIDs.contains(cursor) {
            self.cursorID = self.selectedIDs.first
        }
        if let anchor = self.anchorID, !self.selectedIDs.contains(anchor) {
            self.anchorID = self.selectedIDs.first
        }
    }

    mutating func prune(toValidIDs valid: Set<UUID>) {
        self.selectedIDs = self.selectedIDs.intersection(valid)
        if let cursor = self.cursorID, !valid.contains(cursor) {
            self.cursorID = self.selectedIDs.first
        }
        if let anchor = self.anchorID, !valid.contains(anchor) {
            self.anchorID = self.selectedIDs.first
        }
    }

    /// Winamp Page Up/Down step: about one fifth of the list, at least one row.
    static func pageStep(count: Int) -> Int {
        max(1, count / 5)
    }
}
