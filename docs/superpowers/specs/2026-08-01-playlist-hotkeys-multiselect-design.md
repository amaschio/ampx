# Playlist Hotkeys + Multi-Select (Pass B)

**Date:** 2026-08-01  
**Status:** Approved for implementation  
**Closes:** WEBAMP_REFERENCE §2 (partial) — playlist-focused hotkeys + missing global playback keys

## Goal

Make the Classic playlist feel like Winamp for selection and keyboard use: instant multi-select with click / Shift-click / ⌘-click, and the Winamp playlist + missing global playback shortcuts — with Winamp `Ctrl` mapped to Mac `⌘`.

## Non-goals

- Jump-to-file (`J`), always-on-top, doublesize, EQ band keys
- Media library / video window shortcuts
- NULLSOFT easter egg
- Literal Control-key Winamp bindings (⌘ only for former Ctrl)
- Full main-window-only key map beyond the globals listed below

## Decisions (locked)

| Topic | Choice |
|---|---|
| Scope | Pass B — playlist-focused + missing global playback |
| Multi-select | Real: click / Shift-range / ⌘-toggle |
| Winamp Ctrl | Map to **⌘** |
| Architecture | Central `WinampHotkeys` router + playlist selection model |
| Arrow keys | Playlist key window → selection; otherwise ↑/↓ volume, ←/→ seek |

## Selection model

`PlaylistSelectionState` (or equivalent owned by `ClassicPlaylistView` / keyboard bridge):

| Field | Role |
|---|---|
| `selectedIDs: Set<Track.ID>` | Rows with blue bar |
| `anchorID: Track.ID?` | Shift-click / Shift-arrow range origin |
| `cursorID: Track.ID?` | Keyboard cursor (last moved-to row) |

**Click semantics**

- Plain click → `{id}` only; cursor = anchor = id  
- Shift-click → select inclusive range from `anchorID` (or cursor) to id; keep anchor  
- ⌘-click → toggle id in set; cursor = id; if adding, may set anchor if nil  

**Visuals (unchanged policy)**

- Blue background = selected only  
- White text = selected **or** currently playing  

## Global hotkeys (any Winamp key window; ignore when typing in a text field)

| Key | Action |
|---|---|
| `C` | Pause / unpause (`togglePlayPause` or pause-only if already distinct) |
| `R` | Toggle repeat |
| `S` | Toggle shuffle |
| `←` / `→` | Seek −/+ 5 seconds (when playlist is **not** key) |
| `↑` / `↓` | Volume +/− (when playlist is **not** key) |
| `X` / `V` / `Z` / `B` / Space | Keep existing |

When the **playlist** is the key window, `↑`/`↓` move the selection cursor (Shift extends); do not adjust volume.

## Playlist-focused hotkeys (playlist key window)

| Key | Action |
|---|---|
| `↑` / `↓` | Move cursor; Shift extends selection |
| `Home` / `End` | Jump start / end |
| `PageUp` / `PageDown` | Move by ~⅕ of visible list length (min 1) |
| `Return` | Play cursor (or first selected) |
| `Delete` | Remove selected from playlist |
| `⌘⌫` | Crop (keep selected only) |
| `⌘⇧⌫` | Clear playlist |
| `⌥↑` / `⌥↓` | Move selected block up / down |
| `⌘A` | Select all |
| `⌘I` | Invert selection |
| `⌘⇧1` | Sort by title |
| `⌘⇧2` | Sort by file name |
| `⌘⇧3` | Sort by path |
| `⌘R` | Reverse playlist |
| `⌘⇧R` | Randomize playlist |
| `L` / `⇧L` | Add file / add folder (align with existing pickers) |
| `⌘L` / `⌘⇧L` | Keep existing File menu add bindings |

## Architecture

```
NSEvent keyDown monitor (AppDelegate)
        │
        ▼
  WinampHotkeys.handle(event, context)
        │
        ├── global playback / seek / volume / R·S
        └── if playlist focused → PlaylistHotkeyHandling
                    │
                    └── PlaylistSelectionState + PlaylistManager mutations
```

- Pure helpers for selection math and sort/reverse/randomize stay unit-testable.
- `WinampPlaylistKeyboard` either expands into the new handler or becomes a thin façade.

## Testing

| Case | Kind |
|---|---|
| Click / Shift-range / ⌘-toggle selection sets | Unit |
| Page step = max(1, count/5) | Unit |
| Crop keeps only selected indices; clear empties | Unit on PlaylistManager |
| Sort/reverse/randomize preserve or remaps `currentIndex` sanely | Unit |
| Hotkey router: playlist vs non-playlist arrow dispatch | Unit on pure key→action map if extracted |
| Manual: multi-select + Delete / ⌘A / arrows / C·R·S | Interactive |

## Risks

- **⌘A / ⌘I** may conflict with system menu responders — consume in the local monitor when playlist is key.
- **Reorder drag** must not fight multi-select clicks (already on threshold drag).
- **Moving a multi-selection** must keep relative order and update `currentIndex`.
