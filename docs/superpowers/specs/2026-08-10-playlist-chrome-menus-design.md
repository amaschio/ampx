# Playlist Chrome Menus (ADD / REM / SEL / MISC / LIST)

**Date:** 2026-08-10  
**Status:** Approved for implementation  
**Branch:** `main` (depends on multi-select + `PlaylistManager` crop/sort helpers)  
**Related:** `2026-08-01-playlist-hotkeys-multiselect-design.md`

## Goal

Restore classic Winamp 2.x playlist bottom-bar behavior: **ADD**, **REM**, **SEL**, **MISC**, and **LIST** open native macOS menus with the core Winamp actions, instead of silent single-shot handlers (e.g. REM no-op when nothing is selected).

## Non-goals

- Bitmap pledit flyout sprites
- Add URL
- Remove Misc (dead / dupes / etc.)
- Generate HTML playlist
- Playlist Entry rename
- Media Library integration
- Confirm dialogs for Clear / New List (same as today’s Clear)
- Landing this work on `feature/enthea-visualizer` (cherry-pick later if needed)

## Decisions (locked)

| Topic | Choice |
|---|---|
| Fidelity | Classic Winamp 2.x **core** menus only |
| Presentation | Native SwiftUI `Menu` (same pattern as current LIST OPTS) |
| Architecture | Extend `PlaylistListInteractions` with chrome menu actions; menus only in `ClassicPlaylistView` |
| Landing branch | `main` |
| New List | `clearPlaylist()` + clear selection; no confirm |

## Menu inventory

| Button | Items | Behavior |
|---|---|---|
| **ADD** | Add File… · Add Directory… | `showFilePicker()` · `showFolderPicker()` |
| **REM** | Remove · Crop · Clear Playlist | Remove selected indices; crop to selected; clear all. Remove/Crop disabled when selection is empty |
| **SEL** | Select All · Select None · Invert Selection | Drive `PlaylistSelectionModel` |
| **MISC** | Sort by Title · Sort by Filename · Sort by Path · Reverse · Randomize · File Info | `sortTracks` / `reverseTracks` / `randomizeTracks`; File Info → `presentTrackInfo` for first selected index, else current track; disabled if neither |
| **LIST** | New List · Save List… · Load List… | Clear + clear selection; `saveM3UPlaylist()`; new `showLoadM3UPicker()` (open panel for `.m3u`, then import) |

## Architecture

```
ClassicPlaylistView bottom bar
        │  five SwiftUI Menus over pledit button slots
        ▼
PlaylistListInteractions  (+ chrome menu action methods)
        │
        ├── PlaylistManager
        └── PlaylistSelectionModel
```

### Responsibilities

- **`ClassicPlaylistView`:** Host five invisible `Menu`s (22×18 ADD/REM/SEL/MISC slots; existing LIST OPTS hit area). Skin sprites remain decorative (`allowsHitTesting(false)`). Keep `contentShape(Rectangle())` on clear labels so hits register.
- **`PlaylistListInteractions`:** Map each menu item to manager/selection calls; prune selection after remove/crop/clear; resolve File Info target index. Extract a dedicated type only if this file becomes unwieldy.
- **`PlaylistManager`:** Add `showLoadM3UPicker()` mirroring the save panel (allowed `.m3u`, then existing M3U load/import path). Reuse existing remove/crop/clear/sort/randomize/reverse/info/pickers.

### Hit testing

Invisible menu labels must use `.contentShape(Rectangle())`. Decorative side rails and bottom-bar sprites use `.allowsHitTesting(false)` so fallthrough cannot swallow clicks.

## Testing

| Case | Kind |
|---|---|
| Remove with empty selection is a no-op; with IDs removes and prunes selection | Unit on `PlaylistListInteractions` |
| Crop keeps only selected; Clear empties tracks and selection | Unit |
| Select All / None / Invert via chrome helper match selection model | Unit |
| Load List imports fixture `.m3u` through manager | Unit / manager test |
| Manual: all five menus open; REM shows items; ADD/LIST pickers work | Interactive on `main` |

## Docs

Update `USAGE.md` playlist section to describe the five chrome menus and their items.

## Risks

- SwiftUI `Menu` placement may sit slightly differently than Winamp’s upward flyouts — accepted for this pass.
- File Info with multi-select: only the first selected track (by playlist order) gets info — document in USAGE if non-obvious.
- Depends on multi-select landing on `main`; if that work is incomplete, finish selection model before chrome menus.
