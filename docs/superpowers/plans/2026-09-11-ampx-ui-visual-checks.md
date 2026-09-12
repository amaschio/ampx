# AmpX UI Visual Checks — ReferenceMeasurementsV1

**Date:** 2026-09-11  
**Source:** `screenshots/AmpX.png` (998×1576 px, 2× retina; logical canvas 499×788 pt, composition 490 pt wide)  
**Tooling:** `cd scripts && uv run python measure_reference.py ../screenshots/AmpX.png`

All content rectangles are in module-local coordinates (origin below the 22 pt header, excluding outer canvas padding). Source-pixel columns are PNG-space (2×) before logical conversion.

## Stack geometry

| Key | Source px (x, y, w, h) | Logical value | Notes |
|---|---|---|---|
| `compositionWidth` | — | 490 | Module column width at scale 1.0 |
| `canvasPadding.left` | x=9 | 4.5 | `(499 − 490) / 2` |
| `canvasPadding.top` | y=22 | 11 | `(788 − 766) / 2` |
| `headerHeight` | 44 | 22 | Gold accent line at ~10.5 pt from module top |
| `moduleGap` | 12 | 6 | Between Player, Equalizer, Playlist |
| `playerHeight` | 447 | 223.5 | Module outer height |
| `equalizerHeight` | 451 | 225.5 | Module outer height |
| `playlistHeight` | 610 | 305 | Module outer height |
| `playlistNonRowChrome` | — | 103 | Header offset + footer; viewport = 180 pt |

## Player (`player.*`)

| Key | Source px (x, y, w, h) | Content rect (x, y, w, h) | Notes |
|---|---|---|---|
| `player.displayWell` | (39, 87, 331, 184) | (15.0, 10.5, 165.5, 92.0) | Timer + spectrum column |
| `player.timer` | (81, 102, 258, 47) | (36.0, 18.0, 129.0, 23.5) | 7-segment timer within display well |
| `player.playGlyph` | (81, 107, 25, 33) | (21.0, 20.5, 12.5, 16.5) | Green play triangle left of timer |
| `player.trackWell` | (388, 88, 571, 56) | (189.5, 11.0, 285.5, 28.0) | Title marquee well |
| `player.metadata` | (388, 159, 233, 43) | (189.5, 46.5, 116.5, 21.5) | kbps / kHz / mono / stereo — see crop below |
| `player.metadata.digitStyle` | — | **mono** | Continuous Roboto Mono glyphs (see justification) |
| `player.volume` | (387, 229, 201, 41) | (189.0, 81.5, 100.5, 20.5) | Volume slider track |
| `player.balance` | (619, 229, 122, 41) | (305.0, 81.5, 61.0, 20.5) | Balance slider track |
| `player.position` | (40, 289, 917, 8) | (15.5, 111.5, 458.5, 4.0) | Full-width seek bar |
| `player.transport[0…8]` | See script output | See `AmpXMetrics.playerTransport` | prev, play, pause, stop, next, eject, shuffle, repeat, menu — 44×38 pt |

### Metadata reference crop

![Player metadata crop](reference-crops/player-metadata.png)

**Digit style justification (`mono` vs `segments`):** The crop shows kbps/kHz/mono labels drawn with continuous monospace font strokes (curved `9`, open `4`, diagonal `k`). The timer in `player.displayWell` uses discrete 7-segment LED bars (horizontal/vertical chunks with dark gutters). Metadata therefore uses `metadataDigitStyle = .mono`; only the timer and spectrum bars stay segment-drawn.

## Equalizer (`eq.*`)

| Key | Source px (x, y, w, h) | Content rect (x, y, w, h) | Notes |
|---|---|---|---|
| `eq.curve` | — | (68.0, 18.0, 314.0, 24.0) | Black well + dotted midline + gradient spline |
| `eq.onToggle` | — | (15.0, 14.0, 26.0, 18.0) | Green indicator active |
| `eq.autoToggle` | — | (43.0, 14.0, 32.0, 18.0) | Gray indicator inactive |
| `eq.presets` | — | (418.0, 14.0, 54.0, 18.0) | Static silhouette |
| `eq.preamp` | — | (15.0, 56.0, 18.0, 120.0) | Vertical track + thumb at 0 dB |
| `eq.bandRow` | — | (34.0, 56.0, 440.0, 120.0) | Ten evenly spaced band tracks |

### EQ reference crop

![Equalizer module crop](reference-crops/eq-module.png)

**Mock band values (`mockBands`, normalized −1…1):** `[0.333, 0.583, 0.167, -0.167, -0.5, -0.583, -0.083, 0.417, 0.667, 0.75]` — derived from reference PNG thumb positions; display-only, not audio settings. Preamp mock = `0.0`. Curve drawn via `AmpXEQBands.responseCurvePoints` + `CatmullRomSpline.path(…).cgPath` translated into `eq.curve` origin.

## Playlist (`playlist.*`)

| Key | Source px (x, y, w, h) | Content rect (x, y, w, h) | Notes |
|---|---|---|---|
| `playlist.rows` | — | (15.5, 9.5, 424.0, 180.0) | Black row viewport |
| `playlist.scrollbar` | — | (440.5, 9.5, 16.0, 180.0) | Amber arrows + gold thumb |
| `playlist.footer` | — | (15.5, 193.5, 441.0, 89.5) | ADD/REM/SEL/MISC + mini transport |
| `playlist.rowHeight` | — | 22 | Fixed row pitch |
| `playlist.durationColumnWidth` | — | 42 | Right-aligned durations |

### Playlist reference crops

![Playlist rows crop](reference-crops/playlist-rows.png)

![Playlist footer crop](reference-crops/playlist-footer.png)

**Mock tracks (display-only):** seven reference rows; index 4 (`Crusher-P - Echo`) selected with flat `selection` fill and `text` color. Row origins use `playlistRows.minY + 22 * index` (never distributed). Durations sit in the 42 pt right column.

**Footer rects (footer-local):** ADD `(0,25,35×40.5)`, REM `(41,25,40.5×40.5)`, SEL `(87,24.5,41×41)`, MISC `(133,25,43×40.5)`, time well `(186,22,203×18.5)` → `0:00/27:45`, mini transport five 23–24 pt buttons at y≈45, remaining `(341,49,48×18)` → `-02:12`, LIST OPTS `(399.5,21,41.5×47.5)`.

**Scrollbar:** 8 pt amber arrow caps; gold thumb `(2,18,12×12)` within `playlistScrollbar`.

## Palette & spectrum

| Key | Value | Source sample | Notes |
|---|---|---|---|
| `gold` | `srgb(0.749, 0.627, 0.322)` | Playlist scrollbar thumb | |
| `goldLight` | `srgb(1.0, 0.953, 0.286)` | Thumb highlight | |
| `spectrum.segmentHeight` | 3.0 pt | L/R analyzer columns | **Frozen override** — PNG median lit run ≈ 2.2 pt (anti-aliased mock peaks); keep Winamp-canonical 3.0 pt |
| `spectrum.segmentGap` | 1.0 pt | L/R analyzer columns below timer | Measured from left analyzer columns (median 2 src px = 1.0 pt) |

### Measurement reconciliation

| Key | Script (raw) | Frozen (`AmpXMetrics`) | Resolution |
|---|---|---|---|
| `player.metadata` | (189.5, 46.5, 116.5, 21.5) | same | Fixed: union bbox of kbps/kHz/mono black wells (`blacks[2]` ∪ `blacks[3]`) |
| `spectrum.segmentGap` | 1.0 pt | 1.0 pt | Fixed: scan L/R columns below timer, not center timer digits |
| `spectrum.segmentHeight` | ~2.2 pt | 3.0 pt | Intentional override — see table above; script prints override to stderr |

## Composition checkpoints (Tasks 6A–6C)

- [x] Task 6A: Player crop — wells, timer segments, mono metadata, transport silhouettes
- [x] Task 6B: Equalizer crop — curve well, preamp, ten band tracks, mock curve
- [x] Task 6C: Full three-module stack at scale 1.0 and scale bounds

Capture: `./scripts/shoot.sh` (default stack width 490 pt; resize stack to 416.5 pt / 661.5 pt content width → scale 0.85 / 1.35). Detached/collapsed states restored via `defaults import com.ampx.macos` with `AmpXModuleLayoutV1` JSON before relaunch.

**Remaining deltas vs PNG (honest):** scrollbar gold is subtle in `AmpX.png` (mock uses sampled palette); row selection blue differs slightly from PNG anti-alias; footer bevel depth is approximate; module header gold accent sits on the bevel seam rather than the PNG's inset line.

---

## Task 20 — AppKit acceptance verification (2026-09-12)

**Build:** `a290baf53520f94b489f5c3a506ca55e784411c0`  
**Toolchain:** Xcode 26.4 (17E192) · macOS 26.6.2 (25G83) · arm64  
**Physical display:** `NSScreen.main` backing scale **2.0** (2056×1329 pt). No 3× display available in this environment.

### Full regression suite (final tree)

```text
./scripts/run-tests.sh
→ ** TEST SUCCEEDED **
→ 468 tests passed, 0 failed (73 suites)
→ xcresult: ~/Library/Developer/Xcode/DerivedData/AmpX-deeoonschstsamebrcjyfpxsbbix/Logs/Test/Test-AmpX-2026.09.12_01-38-47--0300.xcresult
```

Key UI suites exercised: `AmpXLayoutTests`, `AmpXStackViewportTests`, `AmpXHostCoordinatorTests`, `AmpXLayoutStoreTests`, `AmpXTheaterTests`, `AmpXAccessibilityTests`, `AmpXKeyRouterTests`, `AmpXEffectiveVisibilityTests`, `AmpXPlayerBindingTests`, `AmpXEQBindingTests`, `PlaylistKeyboardAdapterTests`, `EntheaHostLifecycleTests`, `AmpXPixelGridTests`, `AmpXFontsTests`.

### Backing-scale coverage

| Scale | Evidence | Limitation |
|---|---|---|
| 1× | Live stack screenshots at logical widths below | Rendered on 2× display; geometry uses `AmpXPixelGrid` 1× rules |
| 2× | Primary capture environment (backing 2.0) | — |
| 3× | `AmpXPixelGridTests.testStrokeRectEdgesAt3x`, `testAlignAt1xAnd3x` | **Offscreen only** — no 3× monitor attached |

### Window sizes exercised

| Scenario | Stack frame (w×h) | Derived scale | Screenshot |
|---|---|---|---|
| Scale 0.85 expanded | 417×900 | 0.85 | [scale-0.85-expanded](acceptance-shots/scale-0.85-expanded.png) |
| Scale 1.0 expanded | 490×600 (default) / 490×900 | 1.0 | [scale-1.0-expanded](acceptance-shots/scale-1.0-expanded.png) |
| Scale 1.35 expanded | 662×900 | 1.35 | [scale-1.35-expanded](acceptance-shots/scale-1.35-expanded.png) |
| Collapsed EQ | 490×700, `collapsed: [equalizer]` | 1.0 | [scale-1.0-collapsed-eq](acceptance-shots/scale-1.0-collapsed-eq.png) |
| Detached Playlist | stack 490×520 + detached 490×380 | 1.0 / inherited | [stack](acceptance-shots/detached-playlist-stack.png) · [window](acceptance-shots/detached-playlist-window.png) |
| Detached EQ | stack 490×420 + detached 490×280 | 1.0 / inherited | [stack](acceptance-shots/detached-eq-stack.png) · [window](acceptance-shots/detached-eq-window.png) |
| All-four overflow | 662×480, all modules open | 1.35 | [all-four-overflow-1.35](acceptance-shots/all-four-overflow-1.35.png) |

Hit-area alignment after resize: stack width maps to `AmpXLayout.scale(width:)` (clamped 0.85–1.35); module frames and control rects scale with layout (`AmpXLayoutTests`, live resize via System Events).

### PNG comparison — accepted deltas

Compared panel bounds to `screenshots/AmpX.png` / reference crops above:

- **Header/padding:** 4.5 pt canvas side inset and 11 pt top inset preserved; gold accent on header bevel (not PNG's inner well line).
- **Typography:** `AmpXFonts.register()` loads Roboto Mono (Regular/Medium/SemiBold). Missing-glyph path falls back to `NSFont.monospacedSystemFont` (`AmpXFontsTests`).
- **Timer vs metadata:** 7-segment timer + 3 pt spectrum segments; metadata uses continuous mono glyphs (per crop justification).
- **Spectrum:** 3.0 pt segment height override (intentional).
- **Selection/footer:** playlist selection blue and footer bevel depth differ slightly from PNG anti-alias.

### Spec acceptance table

| Area | Result | Evidence |
|---|---|---|
| Visual fidelity | **Pass** | Scale shots above; `AmpXPixelGridTests` (1×/2×/3× offscreen); `AmpXFontsTests` |
| Layout and scale | **Pass** | `AmpXLayoutTests`, `AmpXStackViewportTests`, screenshots at bounds |
| Module state and persistence | **Pass** | `AmpXModuleOrderTests`, `AmpXLayoutStoreTests`, `AmpXHostCoordinatorTests`; layout import round-trip |
| Overflow | **Pass** | `AmpXStackViewportTests.testMaximumScaleShortScreenOverflowLayout`; overflow screenshot (playlist shrinks, stack scrolls) |
| Drawing models | **Pass** | `AmpXSpectrumColumnModelTests`, `PlaylistRowLayoutTests`, `AmpXControlsTests` |
| Input and accessibility | **Pass** (automated) | `AmpXAccessibilityTests`, `AmpXKeyRouterTests`, `PlaylistKeyboardAdapterTests` |
| Visibility and lifecycle | **Pass** | `AmpXEffectiveVisibilityTests` (display-link start/stop counters); `EntheaHostLifecycleTests` |
| Theater | **Pass** | `AmpXTheaterTests` (view identity, frame/presentation restore) |
| Regression and cutover | **Pass** | Full suite green; `PlaylistChromeActionsTests` unchanged; Classic removed |

### Exercise sequence (manual + automated)

| Step | Observation | Automated backing |
|---|---|---|
| Play fixture (`startup.mp3`) | Startup sound loads and plays on launch | `AmpXApplicationControllerTests`, `AmpXPlayerBindingTests` |
| EQ + volume | Sliders reach `AudioPlayer` / EQ store | `AmpXEQBindingTests`, `AmpXPlayerBindingTests` |
| Playlist add/reorder/select/crop | Selection + manager ops | `PlaylistKeyboardAdapterTests`, `PlaylistManagerTests` |
| Detach Playlist / EQ | Second host window at saved frame; stack omits module | Layout import screenshots; `AmpXTheaterTests` (detach path) |
| Resize hosts differently | Tear-off keeps source scale; stack reclamps playlist viewport on grow | `AmpXLayoutTests`, `AmpXStackViewportTests` |
| Re-dock | `redock` restores stack order | `AmpXModuleOrderTests` |
| Close / reopen stack | Window hidden; state retained; dock icon restores | `AmpXHostCoordinatorTests`, `AmpXApplicationControllerTests` |
| Theater enter/exit | Same `EntheaModuleContent` instance; presentation options restored | `AmpXTheaterTests` |
| Close ENTHEA | WebView teardown, host released | `EntheaHostLifecycleTests` |
| Relaunch persistence | JSON layout round-trip | `AmpXLayoutStoreTests` |

**Environmental note:** Interactive detach/collapse via System Events menu clicks was unreliable in the agent session (focus not always reaching module headers). Behavior verified via layout-import screenshots plus coordinator/theater unit tests.

### Keyboard, VoiceOver, shortcuts

- **Keyboard-only (automated):** `AmpXAccessibilityTests` — button press, slider increment/decrement, module-header custom actions (Collapse/Close/Detach), tab traversal, collapse focus fallback, stack scroll-on-focus.
- **Playlist keys:** arrow/Page Up/Down, Return, Delete, ⌘A/I/R, crop — `AmpXKeyRouterTests`, `PlaylistKeyboardAdapterTests`.
- **Module commands:** ⌘⌥↑/↓ (reorder), ⌘⌥D (detach), ⌘⌥C (collapse) — `AmpXKeyRouterTests`; mirrored in **Window** menu (`AmpXMenuBuilder`).
- **OS-reserved conflicts:** ⌘W → **Close Stack** (not Stop); ⌘Q → Quit (native). Global playback keys (Space, Z/B, arrows when no control focused) route through `AmpXKeyRouter` without overriding menu equivalents.
- **VoiceOver:** Custom actions and value ranges wired on `AmpXButton`/`AmpXSlider`/headers; full VO walk not recorded in CI — manual spot-check deferred.

### Visibility counters

`AmpXEffectiveVisibilityTests` uses test doubles tracking `displayLinkStartCount` / `displayLinkStopCount` on `AmpXContinuousView`:

- Collapse, viewport clip, hide, and close each stop the display link once (idempotent repeats).
- ENTHEA audio bridge follows `EntheaHostLifecycle.setVisible` / `close()` (`EntheaHostLifecycleTests`).

### Task 20 checklist

- [x] Environment, scales, window sizes, commit recorded; full suite with paths/counts
- [x] Screenshots: 0.85 / 1.0 / 1.35, collapsed EQ, detached Playlist/EQ, all-four overflow
- [x] Exercise sequence traced to tests + manual launch observations
- [x] Keyboard/a11y/visibility documented; 3× labeled offscreen-only
- [x] No acceptance defects found — no implementation changes required
