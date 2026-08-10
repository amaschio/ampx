# Playlist Chrome Menus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ADD / REM / SEL / MISC / LIST on the Classic playlist bottom bar open native macOS menus with core Winamp 2.x actions, wired through `PlaylistListInteractions` + `PlaylistManager` on `main`.

**Architecture:** Extract testable `PlaylistChromeActions` helpers in `PlaylistListInteractions.swift` (selection + manager mutations). Replace single-shot `ClassicPlaylistHitTarget` buttons with SwiftUI `Menu`s over the pledit slots. Add `showLoadM3UPicker()` that **replaces** the playlist (Winamp Load List). Keep skin sprites decorative and clear labels hit-testable.

**Tech Stack:** Swift 6, SwiftUI `Menu`, AppKit `NSOpenPanel` / `NSSavePanel`, XCTest

**Spec:** `docs/superpowers/specs/2026-08-10-playlist-chrome-menus-design.md`

## Global Constraints

- Landing branch: `main` (multi-select + crop/sort already present)
- No commits unless the user explicitly asks
- Native SwiftUI `Menu` only — no bitmap flyouts
- Core menus only — no Add URL, Remove Misc, HTML playlist, rename, Media Library
- New List / Clear: no confirm dialog
- Load List **replaces** the current playlist (classic Winamp), then clears selection
- Invisible menu labels must use `.contentShape(Rectangle())`
- Decorative chrome: `.allowsHitTesting(false)`

## File map

| File | Role |
|---|---|
| `Sources/Views/Classic/PlaylistListInteractions.swift` | Add `PlaylistChromeActions` (testable chrome command helpers) |
| `Sources/PlaylistManager.swift` | Add `replacePlaylist(fromM3U:)` + `showLoadM3UPicker()` |
| `Sources/Views/Classic/ClassicPlaylistView.swift` | Five `Menu`s; retire single-action hit targets for ADD/REM/SEL/MISC; fix LIST menu items |
| `Tests/WinampTests/PlaylistChromeActionsTests.swift` | Unit tests for chrome helpers |
| `Tests/WinampTests/PlaylistManagerTests.swift` | Load/replace M3U tests |
| `USAGE.md` | Document the five chrome menus |

---

### Task 1: `PlaylistChromeActions` helpers + tests

**Files:**
- Modify: `Sources/Views/Classic/PlaylistListInteractions.swift`
- Create: `Tests/WinampTests/PlaylistChromeActionsTests.swift`

**Interfaces:**
- Consumes: `PlaylistManager.removeTracks(at:)`, `cropToTracks(at:)`, `clearPlaylist()`, `presentTrackInfo(at:)`; `PlaylistSelectionModel.prune` / `selectAll` / `invert`
- Produces:
  - `enum PlaylistChromeActions` with `@MainActor` static methods:
    - `selectedIndices(tracks:selection:) -> IndexSet`
    - `removeSelected(manager:selection:)`
    - `cropToSelected(manager:selection:)`
    - `clearList(manager:selection:)` — clear playlist + reset selection
    - `selectAll(tracks:selection:)`
    - `selectNone(selection:)`
    - `invertSelection(tracks:selection:)`
    - `fileInfoIndex(tracks:selection:currentIndex:) -> Int?` — first selected by playlist order, else `currentIndex` if in range
    - `presentFileInfo(manager:selection:)` — calls `presentTrackInfo` when index exists

- [ ] **Step 1: Write the failing tests**

Create `Tests/WinampTests/PlaylistChromeActionsTests.swift`:

```swift
import XCTest
@testable import Winamp

@MainActor
final class PlaylistChromeActionsTests: XCTestCase {
    private var manager: PlaylistManager!
    private var player: MockAudioPlayer!

    override func setUp() {
        super.setUp()
        self.player = MockAudioPlayer()
        self.manager = PlaylistManager(audioPlayer: self.player)
    }

    private func track(_ name: String) -> Track {
        Track(title: name, artist: "A", duration: 1, url: URL(fileURLWithPath: "/tmp/\(name).wav"))
    }

    func testRemoveSelectedIsNoOpWhenEmpty() {
        self.manager.addTracks([self.track("a"), self.track("b")])
        var selection = PlaylistSelectionModel()
        PlaylistChromeActions.removeSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.count, 2)
    }

    func testRemoveSelectedRemovesAndPrunes() {
        let a = self.track("a")
        let b = self.track("b")
        let c = self.track("c")
        self.manager.addTracks([a, b, c])
        var selection = PlaylistSelectionModel()
        selection.selectOnly(b.id)
        PlaylistChromeActions.removeSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.map(\.title), ["a", "c"])
        XCTAssertFalse(selection.selectedIDs.contains(b.id))
    }

    func testCropKeepsOnlySelected() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        var selection = PlaylistSelectionModel()
        selection.selectedIDs = [tracks[0].id, tracks[2].id]
        PlaylistChromeActions.cropToSelected(manager: self.manager, selection: &selection)
        XCTAssertEqual(self.manager.tracks.map(\.title), ["a", "c"])
    }

    func testClearListEmptiesTracksAndSelection() {
        self.manager.addTracks([self.track("a")])
        var selection = PlaylistSelectionModel()
        selection.selectOnly(self.manager.tracks[0].id)
        PlaylistChromeActions.clearList(manager: self.manager, selection: &selection)
        XCTAssertTrue(self.manager.tracks.isEmpty)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
    }

    func testSelectAllNoneInvert() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        var selection = PlaylistSelectionModel()
        PlaylistChromeActions.selectAll(tracks: self.manager.tracks, selection: &selection)
        XCTAssertEqual(selection.selectedIDs.count, 3)
        PlaylistChromeActions.selectNone(selection: &selection)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
        selection.selectOnly(tracks[1].id)
        PlaylistChromeActions.invertSelection(tracks: self.manager.tracks, selection: &selection)
        XCTAssertEqual(selection.selectedIDs, [tracks[0].id, tracks[2].id])
    }

    func testFileInfoIndexPrefersFirstSelectedInOrder() {
        let tracks = [self.track("a"), self.track("b"), self.track("c")]
        self.manager.addTracks(tracks)
        self.manager.playTrack(at: 2)
        var selection = PlaylistSelectionModel()
        selection.selectedIDs = [tracks[2].id, tracks[0].id]
        let index = PlaylistChromeActions.fileInfoIndex(
            tracks: self.manager.tracks,
            selection: selection,
            currentIndex: self.manager.currentIndex
        )
        XCTAssertEqual(index, 0)
    }

    func testFileInfoIndexFallsBackToCurrent() {
        let tracks = [self.track("a"), self.track("b")]
        self.manager.addTracks(tracks)
        self.manager.playTrack(at: 1)
        let index = PlaylistChromeActions.fileInfoIndex(
            tracks: self.manager.tracks,
            selection: PlaylistSelectionModel(),
            currentIndex: 1
        )
        XCTAssertEqual(index, 1)
    }
}
```

If `MockAudioPlayer` / `Track` init differ in this repo, match existing `PlaylistManagerTests` / `PlaylistSelectionModelTests` helpers exactly — do not invent a second fixture style.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
./scripts/run-tests.sh -only-testing:WinampTests/PlaylistChromeActionsTests
```

Expected: FAIL — `PlaylistChromeActions` not found (or similar compile error).

- [ ] **Step 3: Implement `PlaylistChromeActions`**

Append to `Sources/Views/Classic/PlaylistListInteractions.swift`:

```swift
/// Classic pledit chrome menu commands (ADD/REM/SEL/MISC/LIST) shared by the UI.
@MainActor
enum PlaylistChromeActions {
    static func selectedIndices(tracks: [Track], selection: PlaylistSelectionModel) -> IndexSet {
        var indices = IndexSet()
        for (index, track) in tracks.enumerated() where selection.selectedIDs.contains(track.id) {
            indices.insert(index)
        }
        return indices
    }

    static func removeSelected(manager: PlaylistManager, selection: inout PlaylistSelectionModel) {
        let indices = self.selectedIndices(tracks: manager.tracks, selection: selection)
        guard !indices.isEmpty else { return }
        manager.removeTracks(at: indices)
        selection.prune(toValidIDs: Set(manager.tracks.map(\.id)))
    }

    static func cropToSelected(manager: PlaylistManager, selection: inout PlaylistSelectionModel) {
        let indices = self.selectedIndices(tracks: manager.tracks, selection: selection)
        guard !indices.isEmpty else { return }
        manager.cropToTracks(at: indices)
        selection.prune(toValidIDs: Set(manager.tracks.map(\.id)))
    }

    static func clearList(manager: PlaylistManager, selection: inout PlaylistSelectionModel) {
        manager.clearPlaylist()
        selection = PlaylistSelectionModel()
    }

    static func selectAll(tracks: [Track], selection: inout PlaylistSelectionModel) {
        selection.selectAll(orderedIDs: tracks.map(\.id))
    }

    static func selectNone(selection: inout PlaylistSelectionModel) {
        selection = PlaylistSelectionModel()
    }

    static func invertSelection(tracks: [Track], selection: inout PlaylistSelectionModel) {
        selection.invert(orderedIDs: tracks.map(\.id))
    }

    static func fileInfoIndex(
        tracks: [Track],
        selection: PlaylistSelectionModel,
        currentIndex: Int
    ) -> Int? {
        if let index = tracks.indices.first(where: { selection.selectedIDs.contains(tracks[$0].id) }) {
            return index
        }
        guard currentIndex >= 0, currentIndex < tracks.count else { return nil }
        return currentIndex
    }

    static func presentFileInfo(manager: PlaylistManager, selection: PlaylistSelectionModel) {
        guard let index = self.fileInfoIndex(
            tracks: manager.tracks,
            selection: selection,
            currentIndex: manager.currentIndex
        ) else { return }
        manager.presentTrackInfo(at: index)
    }
}
```

Optionally refactor `PlaylistKeyboardNavigation.removeSelectedTracks` / `cropToSelection` / `selectAll` / `invertSelection` / `clearSelection` to call these helpers (DRY). Not required for green tests if behavior already matches.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
./scripts/run-tests.sh -only-testing:WinampTests/PlaylistChromeActionsTests
```

Expected: PASS

- [ ] **Step 5: Commit** (only if the user asked)

```bash
git add Sources/Views/Classic/PlaylistListInteractions.swift \
  Tests/WinampTests/PlaylistChromeActionsTests.swift
git commit -m "$(cat <<'EOF'
feat: add PlaylistChromeActions for pledit menu commands

EOF
)"
```

---

### Task 2: Load List — replace playlist from M3U

**Files:**
- Modify: `Sources/PlaylistManager.swift`
- Modify: `Tests/WinampTests/PlaylistManagerTests.swift`

**Interfaces:**
- Consumes: existing `fileService.loadM3UPlaylist(from:)`, `clearPlaylist()`, `addTracks(_:)`, bookmark helpers used by `importPickedURLs`
- Produces:
  - `func replacePlaylist(fromM3U url: URL) async` — bookmarks, loads tracks, clears, then `addTracks` (empty M3U → clear only)
  - `func showLoadM3UPicker()` — `NSOpenPanel` for `.m3u` only, then `Task { await replacePlaylist(fromM3U:) }`

- [ ] **Step 1: Write the failing test**

Add to `Tests/WinampTests/PlaylistManagerTests.swift` (reuse that file’s temp-dir / fixture patterns):

```swift
func testReplacePlaylistFromM3UReplacesTracks() async throws {
    // Arrange: existing tracks, then an M3U pointing at a known audio fixture (e.g. short.wav).
    // Act: await manager.replacePlaylist(fromM3U: playlistURL)
    // Assert: previous titles gone; new tracks match M3U entries; selection not asserted here.
}
```

Use the same fixture generation path as other M3U tests (`Tests/Fixtures` via `./scripts/generate-fixtures.sh` / `run-tests.sh`). If an existing test already loads M3U into an empty manager, clone it and start with non-empty `tracks` so replacement is proven.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
./scripts/run-tests.sh -only-testing:WinampTests/PlaylistManagerTests/testReplacePlaylistFromM3UReplacesTracks
```

Expected: FAIL — `replacePlaylist(fromM3U:)` missing.

- [ ] **Step 3: Implement replace + picker**

In `Sources/PlaylistManager.swift`, near `saveM3UPlaylist()` / `showFolderPicker()`:

```swift
func showLoadM3UPicker() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.init(filenameExtension: "m3u")].compactMap { $0 }
    panel.title = "Load Playlist"
    panel.message = "Choose an M3U playlist to load"

    panel.begin { [weak self] response in
        guard let self, response == .OK, let url = panel.url else { return }
        Task { @MainActor in
            await self.replacePlaylist(fromM3U: url)
        }
    }
}

func replacePlaylist(fromM3U url: URL) async {
    self.fileService.bookmarkM3UResources(for: url)
    let loaded = await self.fileService.loadM3UPlaylist(from: url) ?? []
    self.clearPlaylist()
    if !loaded.isEmpty {
        self.addTracks(loaded)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
./scripts/run-tests.sh -only-testing:WinampTests/PlaylistManagerTests/testReplacePlaylistFromM3UReplacesTracks
```

Expected: PASS

- [ ] **Step 5: Commit** (only if the user asked)

```bash
git add Sources/PlaylistManager.swift Tests/WinampTests/PlaylistManagerTests.swift
git commit -m "$(cat <<'EOF'
feat: load M3U replaces playlist via showLoadM3UPicker

EOF
)"
```

---

### Task 3: Wire five chrome `Menu`s in `ClassicPlaylistView`

**Files:**
- Modify: `Sources/Views/Classic/ClassicPlaylistView.swift`

**Interfaces:**
- Consumes: `PlaylistChromeActions.*`, `playlistManager.showFilePicker()`, `showFolderPicker()`, `saveM3UPlaylist()`, `showLoadM3UPicker()`, `sortTracks(by:)`, `reverseTracks()`, `randomizeTracks()`, `@State selection`
- Produces: ADD/REM/SEL/MISC/LIST menus; no remaining single-shot ADD/REM/SEL/MISC hit targets

- [ ] **Step 1: Replace `ClassicPlaylistHitTarget` with a menu slot view**

Replace the private hit-target struct with:

```swift
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
```

- [ ] **Step 2: Wire ADD / REM / SEL / MISC in `bottomBar`**

Replace the four `ClassicPlaylistHitTarget` calls with:

```swift
ClassicPlaylistMenuSlot(scale: self.s) {
    Button("Add File…") { self.playlistManager.showFilePicker() }
    Button("Add Directory…") { self.playlistManager.showFolderPicker() }
}
ClassicPlaylistMenuSlot(scale: self.s) {
    Button("Remove") {
        PlaylistChromeActions.removeSelected(
            manager: self.playlistManager,
            selection: self.$selection.wrappedValue // use Binding mutation below
        )
    }
    .disabled(self.selection.isEmpty)
    Button("Crop") { /* cropToSelected */ }
        .disabled(self.selection.isEmpty)
    Button("Clear Playlist") {
        PlaylistChromeActions.clearList(manager: self.playlistManager, selection: &/* selection */)
    }
}
// SEL + MISC similarly
```

Because `@State private var selection` cannot be passed as `inout` directly in a `Button` closure cleanly, use a local pattern already common in the view:

```swift
Button("Remove") {
    var model = self.selection
    PlaylistChromeActions.removeSelected(manager: self.playlistManager, selection: &model)
    self.selection = model
}
```

Apply the same `var model = self.selection; …; self.selection = model` pattern for every mutating chrome action.

**REM menu**

- Remove → `removeSelected`
- Crop → `cropToSelected`
- Clear Playlist → `clearList`
- Disable Remove and Crop when `selection.isEmpty`

**SEL menu**

- Select All → `selectAll(tracks:selection:)`
- Select None → `selectNone`
- Invert Selection → `invertSelection`

**MISC menu**

- Sort by Title → `playlistManager.sortTracks(by: .title)`
- Sort by Filename → `.fileName`
- Sort by Path → `.path`
- Reverse → `reverseTracks()`
- Randomize → `randomizeTracks()`
- File Info → `presentFileInfo(manager:selection:)` with `.disabled` when `fileInfoIndex(...) == nil`

- [ ] **Step 3: Fix LIST (LIST OPTS) menu**

Replace the existing Save / Clear-only menu with:

```swift
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
```

Keep hit-testing: bottom-left/right inset sprites and side rails stay `.allowsHitTesting(false)`.

- [ ] **Step 4: Build**

Run:

```bash
./build.sh
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 5: Manual smoke (interactive)**

Run `./build.sh --run` on `main`, open playlist:

1. **ADD** → menu → Add File… opens open panel  
2. **REM** with no selection → Remove/Crop disabled; Clear still enabled  
3. Select a row → **REM → Remove** deletes it  
4. **SEL → Select All / None / Invert** update blue selection  
5. **MISC → Sort by Title** reorders; **File Info** opens info for selection/current  
6. **LIST → Load List…** replaces playlist from an `.m3u`; **New List** clears  

- [ ] **Step 6: Commit** (only if the user asked)

```bash
git add Sources/Views/Classic/ClassicPlaylistView.swift
git commit -m "$(cat <<'EOF'
feat: wire classic playlist ADD/REM/SEL/MISC/LIST menus

EOF
)"
```

---

### Task 4: USAGE docs

**Files:**
- Modify: `USAGE.md`

- [ ] **Step 1: Update the Playlist section**

Replace the vague “playlist actions (add, clear, M3U, etc.)” bullet with something like:

```markdown
- Bottom chrome menus (classic Winamp):
  - **ADD** — Add File…, Add Directory…
  - **REM** — Remove, Crop, Clear Playlist
  - **SEL** — Select All, Select None, Invert Selection
  - **MISC** — Sort (title / filename / path), Reverse, Randomize, File Info
  - **LIST** — New List, Save List…, Load List… (Load replaces the current playlist)
- Multi-select: click / Shift-click / ⌘-click (see hotkeys)
```

Adjust wording to match whatever multi-select paragraph already exists; do not duplicate conflicting shortcut docs.

- [ ] **Step 2: Commit** (only if the user asked)

```bash
git add USAGE.md
git commit -m "$(cat <<'EOF'
docs: describe playlist chrome menus in USAGE

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| ADD File / Directory menus | 3 |
| REM Remove / Crop / Clear (+ disable when empty) | 1, 3 |
| SEL All / None / Invert | 1, 3 |
| MISC sort / reverse / randomize / File Info | 1, 3 |
| LIST New / Save / Load | 2, 3 |
| `showLoadM3UPicker` + replace | 2 |
| `contentShape` + decorative `allowsHitTesting(false)` | 3 |
| Unit tests for chrome actions | 1 |
| Load M3U test | 2 |
| USAGE update | 4 |
| Non-goals excluded | — |

## Self-review notes

- No TBD/placeholder steps.
- `PlaylistChromeActions` method names are consistent across Tasks 1 and 3.
- Load List explicitly **replaces** (not appends), matching Winamp and avoiding ambiguity in the spec’s “import” wording.
