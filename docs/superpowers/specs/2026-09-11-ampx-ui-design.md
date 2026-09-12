# AmpX UI: AppKit / Core Graphics Module Architecture

**Date:** 2026-09-11

**Status:** Revision 5 — visual fidelity and acceptance amended 2026-09-12

**Review history:** [Design review](./2026-09-11-ampx-ui-design-review.md)

## Goal and scope

Replace the Classic UI with an original, high-DPI evolution of the Winamp instrument panel: dark navy panels, steel-blue borders, micro-bevels, black display wells, monospace text, and green/yellow/orange accents. Visual fidelity and reliable module ordering, collapse, detach, and re-dock are equally important.

The primary interface uses **AppKit and Core Graphics**, with custom controls and chrome. It contains no SwiftUI, `NSButton`, `NSSlider`, `NSTextField`, `NSTableView`, `NSScrollView`, native scrollbars, or SF Symbols. Open panels, alerts, and About remain native system UI.

This replaces the UI layer only. Audio, playlist persistence, visualization, ENTHEA internals, shaders, and models remain unchanged, except for moving the existing playlist actions into `Sources/Playlist/`. The UI hotkey router is replaced as described below. Library, DJ mode, new audio features, magnetic window snapping, legacy layout migration, additional skins, a skin picker, and `.wsz` loading are out of scope. The Classic sprite skin and 275 px geometry are retired at cutover.

### References

- [AmpX.png](../../../screenshots/AmpX.png) is the visual acceptance target, not a mood board. It governs appearance and measured geometry, except for the explicit choices below. Existing implementation screenshots and measurement tables do not override it.
- This spec governs behavior and architecture.
- [AmpX UI.pdf](./AmpX%20UI.pdf) supplies rationale and illustrative guidance; its code and dimensions are not implementation contracts.
- Related: [app identity](./2026-09-11-app-identity-design.md), [windowing review](../../WINDOWING_REVIEW.md), [magnetism options](../../DOCKING_MAGNETISM_OPTIONS.md).

## Visual contract

Modules fill a **490 pt-wide** window at scale 1.0. The PNG's 499 × 788 pt canvas includes background padding that is excluded from the window; macOS supplies its shadow.

| Metric | Starting value at scale 1.0 |
|---|---|
| Player height | 223.5 pt |
| Equalizer height | 225.5 pt |
| Playlist height | 305 pt |
| ENTHEA height when shown | 290 pt |
| Module gap | 6 pt |
| Button classes | Primary 44 × 40; secondary 64 × 32; utility 28 × 28 pt |

The panel measurements and button classes are starting values, not permission to standardize differently shaped reference controls. Phase 1 records annotated reference crops and source-pixel measurements, converts them to logical coordinates with explicit header/content origins, and records final geometry in the shared layout/metrics. Measure visible tracks, thumbs, and interaction bounds separately, including thumb travel endpoints; enlarging a hit area must not enlarge its artwork. Label estimates as estimates and validate them visually before freezing them. There is no invariant requiring the composition to total 788 pt.

**Required visual characteristics:**

- Preserve centered Player branding, uppercase EQ/Playlist titles, the reference's left glyph treatment, paired decorative lines, and header-button order. The grip interaction uses the existing left decoration; it does not introduce a generic menu icon.
- Match layered steel-blue frame edges, raised button faces, recessed black wells, and metallic slider thumbs. A single outline or flat fill is not an equivalent bevel treatment.
- Preserve slender colored slider tracks within their control areas, individual transport widths and spacing, indicator placement, and the separation of the EQ curve, toggles, preamp, and bands.
- Match text size, weight, baseline, and alignment. Keep metadata labels on one line without collisions or clipping. Timer digits retain consistent reference proportions and spacing as values change; shorter times must not stretch digits to fill the well.

**Theme.** Keep `AmpXSkin` small: palette, metrics, font family, and drawing primitives (`bevel`, `inset`, `accentLine`, `displayWell`). `ClassicModernSkin` is its only implementation. Components resolve colors and dimensions through it; this scope does not include a general skin engine.

| Token | Value |
|---|---|
| `background` | `rgb(0.043, 0.059, 0.094)` |
| `panel` | `rgb(0.082, 0.106, 0.161)` |
| `panelLight` | `rgb(0.125, 0.157, 0.227)` |
| `border` | `rgb(0.231, 0.275, 0.361)` |
| `borderHighlight` | `rgb(0.396, 0.443, 0.529)` |
| `borderDark` | `rgb(0.035, 0.047, 0.078)` |
| `text` | `rgb(0.902, 0.929, 0.969)` |
| `textDim` | `rgb(0.545, 0.588, 0.667)` |
| `selection` | `rgb(0.13, 0.18, 0.29)` |
| `green` / `yellow` / `orange` | `#00FF32` / `#FFD21A` / `#FF9D00` |
| `display` | `#000000` |
| `gold` / `goldLight` | Sample from PNG in Phase 1 |

**Typography.** Bundle Roboto Mono Regular, Medium, and SemiBold (Apache 2.0); register with `CTFontManagerRegisterFontsForURL` at process scope. Registration failure falls back to `NSFont.monospacedSystemFont`, logs once, and never prevents launch. Sizes resolve through the skin.

**Reference choices and exceptions:**

- Draw the seven-segment timer with custom segments; it is exempt from the Roboto Mono requirement. Phase 1 determines from the reference whether numeric kbps/kHz readouts need the same treatment.
- Use the PNG's gold bevelled scrollbar thumb rather than the PDF's steel-blue suggestion.
- Player has three header buttons; other modules have two, with semantics defined below.
- Exclude the reference's outer canvas padding.

The behavior-defined collapsed, detached, overflow, theater, and interactive states extend beyond the static PNG and use the same visual treatment. Live track text, time, spectrum, EQ values, and selection may differ during normal use; comparison captures use deterministic reference-matching data. Backing-scale rasterization may differ at individual antialiased edges, but not in geometry, spacing, hierarchy, or material treatment. Any further appearance deviation requires a specific reference/result crop, rationale, and user approval; do not self-accept it as a minor delta.

Every border, bevel, and hairline uses `AmpXPixelGrid`, including `pixelAlign(value, backingScale) = round(value * backingScale) / backingScale` and stroke-rectangle snapping. Re-snap and redraw on backing-scale changes without changing module order.

## Architecture and boundaries

The app delegate owns the models, registers fonts, constructs `NSMenu` menus from `AmpXMenuCatalog`, and creates the stack host. The stack and detached window controllers host the same module views.

| Responsibility | Contract |
|---|---|
| `AmpXDrawingView` | Layer-backed, flipped `NSView`; skin access, backing-scale observation, hover tracking, accessibility defaults |
| `AmpXModuleContent` | Draws within its bounds; does not reference `self.window`, draw host chrome, or know neighboring modules |
| `AmpXModuleView` / header | Shared frame, bevels, grip, yellow accent lines, brand/module label, and header buttons |
| `AmpXModuleOrder` | Pure state: `order`, `collapsed`, `detached`, `closed`; operations move, collapse, detach, re-dock, close, reopen; no geometry |
| Stack/layout/drag | Top-down layout, insertion target calculation, reorder and transfer gestures |
| Window hosts | Window behavior, scale, viewport, presentation, ownership, and effective visibility |

Use `Sources/Theme/`, `Components/`, `Modules/{Player,Equalizer,Playlist,Enthea}/`, and `Windows/` as the proposed organization, with fonts in `Resources/Fonts/`. Helper names and file splits may be refined in the implementation plan; the boundaries and behavior contracts are binding.

Reuse `AudioPlayer`, `PlaylistManager`, `Track`, `AudioFeatureBus`, parsers, DSP/EQ, `AmpXEQBands` (band count, labels, and curve geometry), `RemoteCommandController`, `NowPlayingInfo`, `PlaylistSelectionModel`, `AmpXPlaylistKeyboard`, `AmpXMenuCatalog`, `CatmullRomSpline`, `AmpXTimeFormatting`, and `TrackInfoFormatter`. Replace `AmpXHotkeys` with focus-based routing; it must no longer depend on the deleted panel manager.

## Modules and window behavior

Player is the anchor: it always remains in the stack's `order`, cannot detach, and never enters the module `closed` set. Equalizer, Playlist, and ENTHEA may collapse, close, detach, and re-dock. Every module may reorder.

| Header button | Player | Other modules |
|---|---|---|
| `—` | Miniaturize stack window | Not shown |
| `▢` | Collapse/expand Player content only | Collapse/expand that module's content |
| `✕` | Close stack window | Close that module |

Collapsed modules retain their headers. Closing the stack window hides it without quitting: playback, media keys, menus, and Now Playing continue; detached windows stay usable. Reopen through the Dock icon, `Window ▸ AmpX`, or re-docking a detached module. Restore the stored frame, order, collapsed state, and playlist viewport. If all non-anchor modules close, the stack shrinks to Player.

`order` retains closed modules. Reopening restores a module's position, prior detached state, and detached frame where applicable. Restored frames must be on-screen; a detached frame whose display is gone is clamped to the main screen's visible frame.

### Dragging and persistence

The left grip reorders or tears off a module; the rest of the header moves its host window. Detach/re-dock also has per-module Window menu commands and keyboard equivalents, but no header button.

Reorder and re-dock share the pure `dropIndex(stackGeometry:point:) -> Int?` calculation and a yellow 2 pt insertion marker. Dragging a detachable module more than 40 pt outside the stack tears it off, keeping it under the cursor. Dropping a detached module outside the stack leaves it detached at the release position. Collapsing a module during its content drag cancels the drag without changing order.

`AmpXLayoutStore` persists module state, stack/detached frames, and playlist viewport height as versioned JSON in UserDefaults. Missing, corrupt, or unknown-version payloads use defaults without throwing. Unknown module IDs are ignored while retaining recognized entries.

### Sizing and overflow

Normal hosts use hidden titles, transparent title bars, full-size content views, and titled/closable/miniaturizable/resizable window configuration. AmpX draws the chrome. Detached windows have no snapping or attraction.

```
scale = clamp(width / 490, 0.85, 1.35)
hostHeight = (sum(moduleHeight) + moduleGap * (visibleCount - 1)) * scale
```

Here the composition contains open modules in that host; collapsed modules contribute header height. All modules within a stack share scale.

- Horizontal resize changes scale and recomputes content height. Minimum width is `490 * 0.85`; beyond `490 * 1.35`, the window grows while the composition remains centered at scale 1.35.
- Vertical resize adjusts the expanded Playlist's viewport, changing visible row count rather than zoom. Otherwise height follows the composition. Persist viewport height independently of scale; respect scaled header-height minimums.
- Collapse, expansion, close, and reopen change height, not scale. Detached Playlist also supports viewport resizing; other detached modules use their scaled height.
- When content exceeds screen height, first shrink Playlist to a three-row viewport. If still too tall, scroll the stack inside a viewport clamped to the visible frame, using the custom scrollbar. Dragging near its edges auto-scrolls to expose all drop targets. Never automatically collapse, close, or detach modules.
- Tear-off inherits source scale. Re-dock adopts destination stack scale; transfer frames adjust accordingly. Hosts can otherwise be resized independently.

### Theater

Theater is a distinct ENTHEA presentation mode. The window fills `screen.frame`; the visualization fills the window, bypassing ordinary scale and height rules. Hide module chrome and insets, use a black background, and add `.autoHideMenuBar` and `.autoHideDock` to `NSApp.presentationOptions` after capturing its prior value.

Entering and exiting reparent the same mounted ENTHEA view; never recreate its WebView. Exit restores the previous host (stack or detached), scale, frame, and presentation options. Visibility rules below continue to apply.

## State and rendering lifecycle

| State | Source and update path |
|---|---|
| Discrete: track, playlist, EQ, toggles, metadata | One Combine subscription set per module to model `@Published` values; invalidate only the smallest affected subview |
| Continuous: spectrum, time, position | Pull `AudioFeatureBus.spectrumSnapshot(at:)` and `PlaybackClock` through `NSView.displayLink(target:selector:)`; redraw only that view's bounds |

Continuous UI updates do not use Combine or invalidate the whole window. All continuous views and ENTHEA share an effective-visibility predicate:

```
isEffectivelyVisible = !module.isCollapsed && !module.isClosed
    && hostWindow.isVisible && !hostWindow.isMiniaturized
    && hostWindow.occlusionState.contains(.visible)
    && intersectsHostViewport
```

For a stack, viewport intersection accounts for scrolling in a common coordinate space. Detached and theater hosts pass that viewport gate while retaining the other checks. Terms combine; scrolling into view cannot reactivate a collapsed or hidden module. Apply transitions only when the result changes.

| Transition | Display links and ENTHEA behavior |
|---|---|
| Visibility becomes false | Invalidate display links. Suspend ENTHEA rendering, deactivate audio/track bridges, stop its push timer; retain the host |
| Visibility becomes true | Resume display links and ENTHEA bridges/timer/render state |
| ENTHEA module closes | Call `teardown()` and release the host/WebView to release its WebContent resources |
| Detach, re-dock, enter/exit theater | Transfer ownership of the same view; work follows effective visibility in the destination host |

These rules apply to collapse, window hide/miniaturize/occlusion, and scrolling completely out of the stack viewport, including while the stack window itself remains visible.

## Module composition and controls

**Player:** Left approximately 37% holds a dotted black display well, play-state glyph, segment timer, and L/R spectrum. Right approximately 63% holds track text, bitrate/sample-rate/channel metadata (inactive channel label in `textDim`), two horizontal sliders, and EQ/PL toggles with green indicators. A full-width position bar sits above transport: previous, play, pause, stop, next, eject, shuffle, repeat, and orange menu button.

**Spectrum:** Discrete segmented columns; level determines lit-segment count, while vertical segment position determines color from green through yellow-green/yellow to orange. Floating peak-hold marks decay. Keep segment geometry, color-band mapping, and peak behavior testable independently of drawing; sample segment metrics/boundaries from the PNG in Phase 1.

**Equalizer:** ON/AUTO indicators, curve using `CatmullRomSpline`, PRESETS menu, preamp, and ten bands at 60 / 170 / 310 / 600 / 1K / 3K / 6K / 12K / 14K / 16K. Vertical tracks use rectangular metallic thumbs and a +12 / 0 / −12 dB scale. Bind existing EQ values, preamp, enabled, and auto-enabled state.

**Playlist:** Custom rows, 22 pt high; index and Artist – Title left, duration right in a 42 pt column. Green text on black, flat selection fill with selected text in `text`, amber scrollbar arrows, gold thumb. Footer contains ADD/REM/SEL/MISC, mini transport, combined time counter, remaining-time readout, and LIST OPTS.

**ENTHEA:** Host the existing visualization surface inside standard module chrome, under the lifecycle and theater contracts above; internals remain unchanged.

Buttons distinguish normal, hover, pressed, active, and disabled states; active includes a green indicator. Sliders update immediately on click-to-position and drag. Permitted UI transitions are module settling (150–200 ms), button press (60–80 ms), and EQ curve follow (50–100 ms); other UI transitions do not animate.

## Keyboard and accessibility

`AmpXKeyRouter` uses focus context, with this precedence in both hosts:

| Priority | Context | Behavior |
|---|---|---|
| 1 | Focused control | Space activates a button; arrows adjust a slider/EQ band; Escape moves focus out. Consumed keys do not reach playback |
| 2 | Focused Playlist module | Existing navigation, selection, removal, cropping, playback, and reorder bindings |
| 3 | Focused ENTHEA module | F toggles theater; Escape exits theater |
| 4 | Global, when no control has focus | Existing playback, next/previous, volume, and seek bindings |

Module commands appear in the Window menu: `⌘⌥↑/↓` reorder the focused module, `⌘⌥D` detaches/re-docks, and `⌘⌥C` collapses/expands. All module operations must be reachable without dragging.

Every interactive component supplies an accessibility role, label, value, and change notifications. Buttons implement press; sliders expose min/max/current values in real units and increment/decrement actions (1 dB for EQ). Playlist exposes a selectable row hierarchy with settable selected rows and selection-change notifications. Modules expose applicable collapse/expand/close/detach/re-dock actions; scrollbars expose scroll position semantics.

Preserve focus across collapse/expand and reparenting; restore the previously focused element when its module becomes visible. Closing a module transfers focus to the next module in order. Validate all controls and module operations using keyboard only and VoiceOver.

## Migration

**Post-implementation correction:** The migration sequence below records the original replacement of Classic. Visual correction preserves working architecture, model bindings, persistence, and interaction infrastructure; it does not repeat completed extraction/cutover work or restore the retired UI. Revisit drawing, geometry, and affected controls under the visual gates below.

Keep the existing models and non-UI regression suites intact. Before deleting Classic:

- Move `PlaylistChromeActions` verbatim from `Views/Classic/PlaylistListInteractions.swift` to `Sources/Playlist/PlaylistChromeActions.swift`; retain `PlaylistChromeActionsTests` unmodified.
- Replace the SwiftUI-binding-based `PlaylistKeyboardNavigation` with an AppKit `AmpXPlaylistKeyboard.Handling` adapter preserving selection, navigation, playback, removal, cropping, and reorder. Reimplement `PlaylistTrackReorderModifier` with AppKit mouse tracking.
- Rename legacy `Sources/Utilities/AmpXMetrics.swift` to `LegacyPanelMetrics` so the new theme can own `AmpXMetrics`.

| Phase | Deliverable |
|---|---|
| 0 — Preparation | Extract playlist actions and rename legacy metrics; behavior unchanged |
| 1 — Static composition | Measure internal geometry/colors; theme, fonts, pixel grid, drawing base, module frames/headers, stack; mock data |
| 2 — Controls | Custom buttons, sliders, icons, segment digits, scrollbar, labels |
| 3 — Interaction | Module gestures, overflow viewport/auto-scroll, key router, keyboard operation and accessibility |
| 4 — Real state | Model wiring, playlist adapter, ENTHEA lifecycle and theater |
| 5 — Cutover | Port menus to NSMenu, remove old UI and feature flag, update project documentation |

Phases 1–4 use the `AmpXNewUI` UserDefaults flag, default NO, enabled with `-AmpXNewUI YES`. Phase 5 makes the new UI unconditional and deletes the flag. Every phase must build and pass `./scripts/run-tests.sh`; visual phases also iterate with `./scripts/shoot.sh` against the PNG.

At cutover delete:

- `Views/Classic/*`, `AmpXSkinSprites`, `ContentView`, `AmpXApp`, `AmpXCommands`, and the 14 `AmpXSkin*` imagesets.
- The panel/dock family: `AmpXPanelWindowManager`, `AmpXDockGraph`, `AmpXPanelColumnPack`, `AmpXPanelDescriptor`, `AmpXPanelLayoutState`, `AmpXPanelPlacement`, `AmpXPanelPositionStore`, and `Utilities/AmpXWindowSnap`.
- Superseded utilities: `AmpXUIScale`, `AmpXTypography`, `ClassicMarqueeTypography`, `PanelTitleBarDrag`, `AmpXWindowConfigurator`, and `LegacyPanelMetrics`.
- Tests tied to deleted implementations: `AmpXDockGraphTests`, `AmpXPanelColumnPackTests`, `AmpXWindowSnapTests`, and `ClassicUITests`.

Add the app delegate and proposed UI families, bundle/register fonts, update `Resources/Info.plist` as needed, update the module map in `AGENTS.md`, and mark `docs/WINDOWING_REVIEW.md` superseded.

## Acceptance and verification

The behavior contracts above are acceptance requirements. Verify them with:

**Visual gates:** First render the complete static Player, including its header and controls, with reference-matching content at scale 1.0. Capture at 2× backing scale to match the source PNG, crop to the same panel bounds, and inspect side-by-side and overlaid comparisons. Correct geometry, typography, materials, and glyphs before requesting user approval of that concrete screenshot. Do not extend the visual treatment to EQ/Playlist until this Player checkpoint is approved.

Then compare EQ and Playlist individually and as a complete expanded stack with matching mock data. Repeat comparisons after replacing static drawings with interactive controls and after model wiring, using a deterministic presentation of the same production drawing path. Record reference/result crops, build revision, UI/backing scales, remaining differences, and approval of any deviations. Overlaps, missing labels, stretched digits, changed header composition, or substituted control shapes fail acceptance. Unit tests and screenshot generation alone cannot establish visual fidelity; unresolved differences keep that gate open.

| Area | Required evidence |
|---|---|
| Visual fidelity | Approved Player checkpoint and reference/result comparisons for all three panels through static, interactive, and wired states; only documented approved deviations. Check crisp geometry at 1×/2×/3× backing scales and UI scales 0.85–1.35; font registration and fallback. Identify offscreen checks separately from physical-display captures |
| Layout and scale | Full, collapsed, Player-only, ENTHEA-expanded, and detached layouts at scale bounds and 1.0; gaps, viewport row counts, and scale transfer |
| Module state and persistence | Reorder/collapse/detach/re-dock/close/reopen, anchor enforcement, idempotence, insertion targets; JSON round-trip and missing/corrupt/unknown-version/unknown-ID handling |
| Overflow | All four modules at scale 1.35 on a short screen; every module and drop target reachable, with playlist shrinking before stack scrolling |
| Drawing models | Pixel/stroke snapping, segment count/color boundaries/peak decay, playlist row geometry, duration column, and visible ranges |
| Input and accessibility | Playlist-adapter parity, focus-routing precedence, keyboard-only operation, and VoiceOver actions/values/focus in both hosts |
| Visibility and lifecycle | Each gate independently suspends work; scrolling in cannot override other gates; ENTHEA stops while collapsed or clipped inside a visible window; close releases its host |
| Theater | Display-filling content, restored host/scale/frame/presentation options, identical view instance across transitions, and continued window-visibility gating |
| Regression and cutover | Existing audio/playlist/ENTHEA/visualization/parsing suites stay green; playlist action tests unchanged; retired UI, assets, panel family, and flag removed |

Geometry refinement remains Phase 1 discovery work. Custom interaction, visibility, accessibility, and cutover risks are covered by these checks; review rationale and resolved alternatives remain in the linked review document.
