# MilkDrop as a Managed Panel (W8)

**Date:** 2026-08-01  
**Status:** Approved for planning  
**Closes:** WINDOWING_REVIEW W8 — visualizer as a registered panel

## Goal

Promote the MilkDrop visualizer from an inline main-window expansion to a first-class managed panel with the same windowing look and feel as the equalizer and playlist: borderless `NSWindow`, classic chrome, dock/float via geometry, child-window linking, persisted size and visibility.

## Non-goals

- New Metal presets or shader work
- Changing EQ/playlist docking semantics
- A dedicated “side stack” model beyond existing geometry docking
- Fullscreen multi-monitor fixes (separate RELEASE.md note)

## Decisions (locked)

| Topic | Choice |
|---|---|
| Chrome | Classic Winamp panel chrome (option A) |
| Default dock | Right of the main vertical stack (flush to main’s right edge, top-aligned) |
| Sizing | User-resizable like playlist; default 600×450; persist; scale with Zoom |
| Visibility | Persist `showVisualizer` in UserDefaults; first launch closed |

## Architecture

### Panel identity

- Add `WinampPanelID.visualizer` (`"visualizer"`).
- Append a `WinampPanelDescriptor` in `WinampPanelWindowManager.makeRegistry()`.
- No closed-enum switch growth beyond existing ID helpers that already key off `WinampPanelID`.

### Layout state (`WinampPanelLayoutState`)

| Property | Persistence | Default |
|---|---|---|
| `showVisualizer` | UserDefaults | `false` |
| `visualizerMinimized` | In-memory only (same as EQ/playlist shade) | `false` |
| `visualizerSize: CGSize` | UserDefaults width + height | `600×450` |

Zoom must scale `visualizerSize` the same way playlist dimensions scale (`scalePlaylistDimensions` pattern — either a shared helper or a twin `scaleVisualizerDimensions`).

### Visibility triggers (unchanged UX entry points)

- Double-click mini spectrum/oscilloscope → toggle `showVisualizer`.
- Title-bar options menu → “Show / Hide Visualizer”.
- Panel close button → `showVisualizer = false`.

Remove the inline `if showVisualization { MilkdropVisualizerView()… }` branch from `ContentView`. Local `@State showVisualization` moves onto `panelLayout.showVisualizer` (or a binding into it).

Main-window miniaturize should hide/show panels through the existing panel manager path (same as EQ/PL), not a one-off `showVisualization = false` in `ContentView`.

### Window manager

1. **Descriptor** — `isVisible` reads `showVisualizer`; `makeRoot` returns a `VisualizerPanelRoot` observing `layoutState`; `sizing: .explicit` from `visualizerSize` / minimized height.
2. **Initial placement** — When no saved offset exists in `WinampPanelPositionStore`, place flush to the **right of main**, top-aligned:
   - `origin.x = main.frame.maxX`
   - `origin.y = main.frame.maxY - window.frame.height`
3. **Vertical pack** — `packMainVerticalColumn` must continue to skip panels that are side-of-main (already implemented). Do **not** pass `.visualizer` as `forcing` into the vertical pack on toggle.
4. **Resize** — `resizeVisualizerPanel()` mirrors `resizePlaylistPanel()` (top-edge anchor when docked; size from layout state).
5. **Windowshade** — Title-bar double-click toggles `visualizerMinimized` like playlist/EQ.

### Chrome / UI

New classic panel view (suggested name: `ClassicMilkdropPanelView` — avoid clashing with existing mini `ClassicVisualizerView` in `SpectrumView.swift`).

Structure:

```
┌─ classic title bar (shade + close + drag) ─┐
│  ◀  MILKDROP • preset name              ▶  │  ← thin preset strip
│                                            │
│           Metal visualization              │
│                                            │
└─ classic border / resize grip (BR) ────────┘
```

- **Title bar:** Variable-width like playlist (tiled pledit-style strip, or a shared stretchable panel title bar). Fixed 275px EQ title sprite is not enough for a resizable panel.
- **Preset strip:** Replaces today’s blue gradient header; keep ◀ / name / ▶ and auto-advance timer behavior from `MilkdropVisualizerView`.
- **Body:** `MilkdropMetalVisualizationView` fills remaining space; black background.
- **Windowshade:** Title bar only (~14px × scale); hide preset strip + viz.
- **Resize:** Invisible BR grip like playlist; min size ≈ classic panel width × ~200pt (scaled).

Refactor: extract preset-cycling logic from `MilkdropVisualizerView` into the new panel (or thin the old view to a body-only component used by the panel). Delete or retire the standalone modern chrome once unused.

### Default spatial layout (first open)

```
┌──────────┐ ┌─────────────────────┐
│   main   │ │     MilkDrop        │
├──────────┤ │                     │
│    EQ    │ │                     │
├──────────┤ └─────────────────────┘
│ playlist │
└──────────┘
```

MilkDrop docks to **main** on the right (geometry parent). EQ/playlist remain in the vertical column under main. After the user moves it, `WinampPanelPositionStore` offsets win on subsequent opens.

## Testing

| Case | Kind |
|---|---|
| `showVisualizer` defaults false; round-trips via UserDefaults | Unit (`WinampPanelLayoutState`) |
| `visualizerSize` default 600×450; persist; Zoom scale | Unit |
| First placement geometry: right of main, top-aligned | Unit on a pure helper if extracted from `placePanelInitially` |
| Registry includes `.visualizer`; stack/dock tests still pass | Existing + small extension |
| Manual: open via double-click; dock/float; resize; shade; relaunch restores | `./scripts/shoot.sh` / interactive |

## Implementation outline (for the plan)

1. Layout state + persistence + panel ID.
2. Classic panel view + preset strip; wire Metal body.
3. Register descriptor; initial right-of-main placement; resize/shade hooks.
4. Retarget ContentView / ClassicMainPlayerView / ClassicShadeView bindings; remove inline viz.
5. Tests + build + shoot / open-and-verify.

## Risks

- **Title-bar art for variable width:** No historic MilkDrop BMP; reuse pledit tiling or a neutral classic bar — must still read as Winamp chrome.
- **Forcing into vertical pack:** Easy regression if toggle path calls `packMainVerticalColumn(forcing: .visualizer)`.
- **Naming clash:** Existing `ClassicVisualizerView` is the mini LCD viz — keep that name; use a distinct panel type name.
