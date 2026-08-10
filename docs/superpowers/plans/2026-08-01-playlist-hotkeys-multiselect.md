# Playlist Hotkeys + Multi-Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Classic playlist multi-select (click / Shift / ⌘) plus Pass-B Winamp hotkeys (playlist ops + missing global playback), with Winamp Ctrl → ⌘.

**Architecture:** Pure `PlaylistSelectionModel` for selection math; `PlaylistManager` gains batch remove/crop/sort/reverse/randomize/move-selected; `WinampHotkeys` NSEvent router replaces the thin playlist-only monitor; `ClassicPlaylistView` owns selection state and wires clicks.

**Tech Stack:** Swift 6, AppKit `NSEvent` monitor, XCTest

**Spec:** `docs/superpowers/specs/2026-08-01-playlist-hotkeys-multiselect-design.md`

## Global Constraints

- No commits unless the user explicitly asks
- Classic Winamp UX; ⌘ maps former Ctrl
- Ignore hotkeys when first responder is `NSTextView` / `NSTextField`
- Prefer protocol seam on `PlaylistManager` mutations; keep selection pure where possible

## File map

| File | Role |
|---|---|
| `Sources/Playlist/PlaylistSelectionModel.swift` | Pure selection + page-step helpers |
| `Sources/Utilities/WinampHotkeys.swift` | Key→action router |
| `Sources/Utilities/WinampPlaylistKeyboard.swift` | Expand / façade for playlist handler |
| `Sources/Views/Classic/PlaylistListInteractions.swift` | Selection bridge + keyboard handling |
| `Sources/Views/Classic/ClassicPlaylistView.swift` | Multi-select clicks + blue bar from set |
| `Sources/PlaylistManager.swift` | Batch ops |
| `Sources/WinampApp.swift` | Install `WinampHotkeys` monitor |
| `Tests/WinampTests/PlaylistSelectionModelTests.swift` | Selection unit tests |
| `Tests/WinampTests/PlaylistManagerTests.swift` | Batch ops tests |
| `USAGE.md` | Document shortcuts briefly |

---

### Task 1: Selection model (pure)

**Files:**
- Create: `Sources/Playlist/PlaylistSelectionModel.swift`
- Test: `Tests/WinampTests/PlaylistSelectionModelTests.swift`

**Produces:** `struct PlaylistSelectionModel` with `selectedIDs`, `anchorID`, `cursorID`; methods `selectOnly`, `toggle`, `selectRange`, `moveCursor(by:extend:orderedIDs:)`, `selectAll`, `invert`, `pageStep(count:)`.

- [ ] Failing tests for click / shift-range / ⌘-toggle / page step
- [ ] Implement model
- [ ] Tests pass

### Task 2: PlaylistManager batch ops

**Files:**
- Modify: `Sources/PlaylistManager.swift`
- Test: `Tests/WinampTests/PlaylistManagerTests.swift`

**Produces:** `removeTracks(at:)`, `cropToTracks(at:)`, `moveSelectedTracks(indices:direction:)`, `sortTracks(by:)`, `reverseTracks()`, `randomizeTracks()` — all remap `currentIndex` / shuffle sanely.

- [ ] Failing tests
- [ ] Implement
- [ ] Tests pass

### Task 3: Wire multi-select UI

**Files:**
- Modify: `ClassicPlaylistView.swift`, `PlaylistListInteractions.swift`

- [ ] Replace single `selectedTrack` with `PlaylistSelectionModel` `@State`
- [ ] Button click reads `NSEvent.modifierFlags` for Shift/⌘
- [ ] Row `isSelected` from set
- [ ] Keyboard nav updates model (extend with Shift)

### Task 4: Hotkey router + AppDelegate

**Files:**
- Create: `Sources/Utilities/WinampHotkeys.swift`
- Modify: `WinampApp.swift`, `WinampPlaylistKeyboard.swift`

- [ ] Router handles global C/R/S/seek/volume and playlist branch
- [ ] AppDelegate uses router
- [ ] Playlist handler implements delete/crop/clear/move/sort/etc.

### Task 5: Docs + verify

- [ ] Short USAGE.md shortcut section
- [ ] `./scripts/run-tests.sh`
- [ ] Manual smoke: multi-select + Delete + arrows + C/R/S
