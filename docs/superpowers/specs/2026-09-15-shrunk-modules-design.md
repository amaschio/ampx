# AmpX UI: Functional Collapsed Modules

**Date:** 2026-09-15

**Status:** Draft for user review. Volume/balance mapping and two-button EQ/Playlist chrome confirmed by user; implementation has not started.

**Foundation:** [AmpX UI design, Revision 7](./2026-09-11-ampx-ui-design.md).

## Goal and scope

Give the collapsed Player, Equalizer, and Playlist complete, usable compact presentations matching [shrinked_modules.png](../../../screenshots/shrinked_modules.png). Preserve the expanded UI shown in [ampX_UI_v1.1.png](../../../screenshots/ampX_UI_v1.1.png), including its materials, controls, fixed width, and working interactions.

“Shrunk,” “compact,” and “collapsed” describe the same module state. Continue using the existing `collapsed` state; this is not a second mode or a new window type. Collapsing switches the module's presentation, with useful controls remaining visible.

This is an addendum to the original UI spec, using its AppKit/Core Graphics architecture, measurement process, deterministic captures, and visual approval gates. It does not repeat the Classic migration. ENTHEA retains its existing header-only collapsed presentation and rendering lifecycle. Library, DJ mode, new DSP, window magnetism, adjustable UI scale, and expanded-panel redesign are outside this scope.

### Reference precedence

- The collapsed reference governs compact composition, control order, proportions, branding placement, and material treatment.
- **User-confirmed screenshot correction:** the minimize buttons drawn on compact EQ and Playlist are mockup errors. Follow `ampX_UI_v1.1.png`: these modules have only Expand/Collapse and Close, in both docked and detached presentations. Only Player has a minimize button.
- The actual-player screenshot governs compatibility with the successful expanded appearance. Its variable Playlist height and live data are examples, not replacement default dimensions.
- This addendum governs compact behavior and the explicit extensions below. All other behavior comes from the original spec.
- Exclude white canvas, explanatory headings, generous example spacing, and baked-in shadows from the compact reference. macOS supplies the window shadow; docked modules have no individual window shadow.
- Use the original custom-control primitives and fonts. Raster reference imagery must not become an image stretched behind interactive controls.

### Explicit changes to the original contract

1. Player, EQ, and Playlist collapse into functional compact strips rather than retaining only their expanded headers.
2. Their collapsed heights come from per-module compact metrics rather than `headerHeight`.
3. Collapsed Player metering and time remain live when visible. Expanded content still suspends while collapsed.
4. Compact bars use the reference's left-aligned AmpX wordmark and separators rather than the expanded centered titles and long decorative rules. The original Player three-button and EQ/Playlist two-button contracts remain unchanged.

## Approach and boundaries

**Chosen approach:** introduce dedicated compact presentations inside the existing `AmpXModuleView`. The module owns its expanded header/content and compact presentation, showing only the applicable presentation. Hosts continue to own windows and module operations.

Enriching the existing header with all module controls would couple expanded title layout to compact functionality. Separate mini-player windows would duplicate ownership and complicate docking. Dedicated presentations retain the same module identity, host, and state while isolating geometry.

The inspected modern implementation is on `feature/ampx-ui` in `.worktrees/ampx-ui`, at `4f53706` during design. The root `develop` checkout still contains Classic views. Implementation must begin from the modern UI code or its merged successor; do not implement this spec in `ClassicShadeView` or rebuild the retired panel system. File names below refer to that modern implementation and must be rechecked against the implementation revision.

## Visual contract

### Size and measurement

Normal module width remains **490 logical points**. Adjacent docked modules retain the **6 pt gap**. Collapsing never changes column width or scales the expanded interface. Docked ENTHEA remains at x = 496 pt.

The compact image is 1415 × 1111 source pixels. Approximate outer-frame crops, expressed as `(x, y, width, height)` from the image's top-left, are:

- Player: `(28, 276, 1361, 84)`.
- Equalizer: `(28, 557, 1361, 84)`.
- Playlist: `(28, 832, 1361, 76)`.

These are **visual estimates**, excluding the outer shadow, not finalized pixel measurements. Normalize each crop by `490 / cropWidth` on both axes; do not assume this mockup has the actual-player screenshot's backing scale. This gives starting heights of approximately **30.25 pt for Player/EQ** and **27.5 pt for Playlist**. Preserve the apparent height difference during the first comparison; do not silently standardize the strips to one height.

Before freezing geometry, record precise outer edges, bevel thicknesses, separators, black wells, text ink boxes/baselines, glyphs, button faces, slider tracks, thumbs, and thumb-center endpoints. Store logical geometry in shared compact metrics, with the crop origin and conversion factor recorded alongside measurement evidence. Snap to the current backing grid without allowing accumulated rounding to change the 490 pt width.

The reference suggests these horizontal allocations as starting estimates:

- Player: branding/grip in the first 18%; shared spectrum/time well from about 18–56%; five transport buttons from about 58–83%; window controls from about 86–99%.
- EQ: branding/grip in the first 18%; volume from about 19–50%; a narrow separator; balance starts at about 54%. Keep Expand/Close right-aligned at their reference positions; extend the balance track into the space recovered by removing the erroneous minimize button, preserving the separator and clearance before Expand.
- Playlist: branding/grip in the first 17%; track/duration well starts at about 17%. Keep Expand/Close right-aligned at their reference positions; move List Options and its separator right into the recovered space and extend the summary well accordingly.

These proportions guide measurement, not final hit rectangles. Measure individual button widths and gaps. Keep interactive targets within their module, disjoint from adjacent targets and drag regions. Enlarging a hit target must not enlarge the artwork. Any width/height or composition departure needed for legibility requires a reference/result comparison and approval.

### Shared appearance

- Dark navy panel, layered steel-blue outer edges, bright top/left highlights, dark bottom/right bevels, recessed black wells, metallic slider thumbs, and yellow waveform grip glyph.
- Left-aligned AmpX branding with the compact reference's slanted wordmark treatment. Reuse the brand drawing where possible; obtain the slant through drawing, without adding an unrelated font. Measure the result rather than substituting the expanded centered title.
- Thin vertical metallic separators divide branding, instruments, and trailing chrome. Do not carry over the expanded header's long paired yellow rules.
- Text uses the existing Roboto Mono family and fallback; timer uses existing custom segment drawing. Compact Playlist text follows the project's text system, with reference-matched size and spacing rather than introducing a bitmap font.
- Active play glyph and readouts are green; minimize and close glyphs are yellow/orange; inactive transport glyphs are pale. Maintain raised faces and recessed pressed states.
- Every control supports hover, pressed, disabled, keyboard focus, and appropriate active state, using the existing skin. No SF Symbols or standard native control chrome.

## Compact module composition

### Player

Left to right: waveform grip, AmpX wordmark, separator, black spectrum/time well, separator, **Previous / Play / Pause / Stop / Next**, separator, **Minimize / Expand / Close**.

Use the same transport actions and enablement as the expanded Player. These are real controls, not decorative copies. Omit track metadata, seek, volume, balance, EQ/PL toggles, eject, shuffle, repeat, and options from this compact presentation; existing menu/keyboard access remains available.

The well contains one compact spectrum on the left and elapsed time on the right. Reuse `AudioFeatureBus` and the existing segment/color/peak rendering model. Adapt column geometry to the measured well without running a second audio analysis pipeline. Do not add L/R labels or a second spectrum row absent from the reference.

Time uses a minimum two-digit minute field, matching `01:51`. It reads the same playback clock as the expanded timer. Reserve geometry for long elapsed times; use an hours format for hour-long playback and fit it through a defined smaller digit style, never by stretching glyphs or overlapping the spectrum. Include `00:00`, `59:59`, `1:00:00`, and `100:00:00` in geometry verification. Empty playback displays `00:00` and unlit spectrum; paused/stopped behavior follows the existing clock and spectrum semantics.

### Equalizer

Left to right: waveform grip, AmpX wordmark, separator, **master volume**, separator, **balance**, separator, **Expand / Close**.

The user confirmed that orange controls master volume and green controls balance. These are alternate access points to the expanded Player's controls; neither modifies preamp, EQ bands, EQ enabled, or AUTO state.

- Orange volume: continuous warm-colored fill in a recessed horizontal track and a metallic thumb. Bind normalized 0…1 to the existing `setVolume`; accessible value is 0…100%.
- Green balance: segmented green fill and a metallic thumb. Bind normalized 0…1 to existing balance −1…+1; center is 0. Left-to-thumb fill follows the mockup, so centered balance fills half the track. The segments indicate position, not audio level.
- Use the same click-to-position, dragging, keyboard increments, and model clamping as the existing sliders. Thumb-center endpoints must keep the full thumb inside its allowed track region.
- Tooltips and accessibility labels identify Volume and Balance without adding visible labels to the reference. Balance announces left/center/right position rather than an unexplained normalized number.
- Changes through either presentation, menus, or media-related controls update the other presentation through existing model observation. Showing or hiding this strip never changes playback settings.

EQ ON/AUTO, presets, curve, preamp, and bands remain in the expanded presentation. Collapsing does not bypass or disable equalization.

### Playlist

Left to right: waveform grip, AmpX wordmark, separator, black **track summary and duration** well, yellow three-line **List Options** button, separator, **Expand / Close**.

Show the loaded playback track, independently of selection: `index. Artist - Title`, with that track's total duration right-aligned. The reference fixture is `7. SLEAZE - GOD DAMN` and `3:46`. This is track duration, not elapsed time, remaining time, or total playlist duration.

Use the existing metadata fallback rules. Obtain the index from the current playlist order and omit it when the loaded track is no longer in the playlist. With no loaded track, show `NO TRACK` and `--:--`; an unknown duration also uses `--:--`. Pause and stop retain the loaded-track summary while that track remains loaded.

Reserve a separate duration area whose width accommodates the formatted value. Clip long track text to its own rectangle; no wrapping, collision, or new marquee animation. Preserve title casing from metadata; the uppercase fixture is not an uppercase transformation rule.

The three-line button opens the existing **LIST OPTS** menu, anchored to the button, with the same commands and validation. It is not a reorder grip or an expand action. Track summary is read-only; expanding uses the square button or module command. The expanded selection, scroll position, and preferred viewport survive collapse.

## Chrome, dragging, and windows

Player displays trailing **— / square / ×** controls. EQ and Playlist display only **square / ×**, matching the actual UI screenshot and the original spec. Do not reserve a blank button slot for the erroneous minimize control.

- **Minimize (Player only):** miniaturizes the stack NSWindow. Tooltip/accessibility label is `Minimize AmpX window`. This action does not alter `collapsed` or `closed`. EQ and Playlist expose no minimize button or associated button hit target/accessibility element, including when detached.
- **Expand:** clears that module's existing collapsed state and restores its expanded layout. The square is not fullscreen or maximize. Use the existing collapse keyboard command (`⌘⌥C`) to toggle either direction.
- **Close:** Player closes/hides the stack without quitting; EQ/Playlist close only that module. Existing reopening and detached-state restoration apply.

The left waveform remains the grip for reordering and tearing off eligible modules. Player can reorder within the left column and cannot detach. Noninteractive branding, separators, and panel background move the containing window. Wells, controls, and control hit areas must not initiate window or module dragging. Existing tear-off distance, insertion marker, screen-coordinate conversions, and re-docking rules continue to apply.

Keep the host's top-left anchor stable during collapse/expand; recompute all affected module frames and host height in the same update. Lower left-column modules move together. The right-column visualizer remains top-aligned, and host height is the larger column height. A compact left column beside expanded ENTHEA therefore does not force the host down to the left-column height.

Use the same compact heights in stack and detached hosts. A collapsed Playlist cannot resize its hidden viewport. Preserve its preferred expanded viewport and reapply existing short-screen fitting on expansion. Closed/detached modules contribute no stack space, and closed views must remain hidden after relayout.

Retain existing double-click behavior, if any; this scope introduces no new double-click shortcut. Cancel an active content drag on collapse, without changing order or partially applying a module operation.

## State, rendering, and lifecycle

Retain `AmpXModuleOrder.collapsed` as the source of truth. Add no duplicate mini-mode boolean, playback model, audio engine, EQ state, or persistent compact slider values. Existing layout JSON remains compatible; restored collapsed IDs now select compact presentations. Recompute compact frame heights from metrics instead of trusting saved expanded frame heights.

Separate host visibility from presentation visibility:

```text
hostVisible = !closed && windowVisible && !miniaturized
    && !occluded && intersectsViewport
expandedVisible = hostVisible && !collapsed
compactVisible = hostVisible && collapsed && hasCompactPresentation
```

The coordinator supplies both presentation states. Do not globally remove the collapsed gate from the existing content visibility calculation: that would resume hidden EQ animation, Player displays, Playlist clocks, and ENTHEA rendering.

- Expanded continuous views run only under `expandedVisible`.
- Compact Player time/spectrum run only under `compactVisible`, pulling the existing clock/feature bus through display links. Collapse switches active drawing paths; it does not freeze the visible compact timer.
- Compact EQ and Playlist use discrete model updates; no independent continuous redraw timer is needed for slider positions or total duration.
- Hide/minimize/occlusion stops all continuous work in the affected host. Detached visible modules continue independently.
- Collapse retains expanded views, controls, and transient UI state. Detach/re-dock reparents the same module container and does not duplicate subscriptions.
- ENTHEA remains header-only when collapsed, with content rendering and bridges suspended. Its close/teardown and theater behavior are unchanged.
- Set up model observation once per owning presentation/binding layer and tear it down with ownership. Repeated collapse/expand must not accumulate observers or display links. Invalidate only affected drawing regions.

## Implementation integration points

- `Components/AmpXModuleView.swift`: explicitly select expanded or compact presentation, draw the correct frame, lay out in full-module coordinates, and keep hidden presentation controls out of focus traversal.
- Shared compact chrome: owns frame, branding, separators, grip, and trailing buttons; emits module/window intents to the coordinator. Avoid three copies of window behavior.
- `Modules/Player`, `Modules/Equalizer`, `Modules/Playlist`: compact bodies reuse existing transport actions, slider bindings, metadata formatting, menus, clock, and spectrum drawing. They do not access neighboring views.
- `Theme/AmpXMetrics.swift` and skin drawing helpers: per-module compact heights and measured compact geometry. Do not modify expanded metrics to make compact artwork fit.
- `Modules/AmpXLayout.swift`: calculate collapsed height by module ID, retaining header height for ENTHEA. Stack and detached sizing consume the same source.
- `Windows/AmpXHostCoordinator.swift` and `Modules/AmpXEffectiveVisibility.swift`: route both presentation visibility states, minimize intents, and existing module actions.
- Stack/detached controllers: retain fixed width, anchor preservation, Playlist viewport restoration, and correct visibility after transfer.

Names and file splits may be refined in the implementation plan; these ownership boundaries and behavioral requirements are binding.

## Keyboard and accessibility

Collapsed controls participate in the existing focused-control-first key routing. Space activates focused buttons; arrows adjust focused sliders without also seeking or changing playback globally. Hidden expanded Playlist rows must not consume navigation/deletion keys while collapsed. List Options must open and operate with the keyboard.

On collapse, remember the expanded responder and move focus to the compact presentation's expand control when focus was inside the collapsing module. On expansion, restore the remembered valid responder, otherwise the normal module header. Do not steal focus from another module. Rebuild traversal from visible controls after presentation changes and preserve it across detach/re-dock.

Expose each compact strip as its actual module (`Player`, `Equalizer`, `Playlist`) even though all display AmpX branding. Give every button and slider a meaningful role, label, value, and action. Expose Playlist summary as static text. Announce collapse/expand and value changes through existing accessibility conventions, without announcing playback time every frame.

## Acceptance and verification

### Visual gates

1. Measure and render compact Player first using the production drawing path and deterministic spectrum/time (`01:51`). Capture at 2× backing scale, normal width 490 pt. Normalize the source crop to matching output bounds with a recorded transform; retain an aspect-ratio-preserving comparison so resizing cannot conceal a height mismatch.
2. Compare reference/result side by side and with an overlay. Correct border layers, brand placement/slant, well geometry, timer proportions, spectrum, glyphs, individual control widths, and spacing. Obtain approval of the concrete Player capture before extending the treatment to compact EQ/Playlist.
3. Repeat for EQ with deterministic volume/balance positions matching the reference and Playlist with the specified track fixture. Repeat after controls and live models are wired.
4. Capture each compact module, all three compact in a stack, mixed expanded/compact states, reordered states, detached EQ/Playlist, and a compact stack beside expanded ENTHEA. Capture the original expanded panels with deterministic content to detect regressions; keep Playlist viewport sizes equal for comparisons.
5. Check 1×/2×/3× rasterization at the same logical width; identify offscreen raster checks separately from physical-display screenshots. Use `./scripts/shoot.sh` for rendered app evidence and document any deterministic capture support added.

Record build revision, crop measurements, logical dimensions, backing scale, reference/result images, unresolved differences, and approvals. Screenshot generation or passing tests alone cannot establish fidelity. Overlaps, clipped controls, flat substitutes for bevels, incorrectly scaled artwork, and stretched digits fail the visual gate.

### Behavior and regression evidence

- Layout tests cover each collapsed height, all eight Player/EQ/Playlist collapse combinations, gaps, right-side ENTHEA, closed/detached exclusions, and restoration of preferred Playlist viewport.
- Visibility tests independently cover collapse, close, window hide, miniaturize, occlusion, and host transfer: visible compact Player updates while expanded content and collapsed ENTHEA remain suspended; hidden hosts run neither presentation.
- Interaction checks cover all five transports, volume/balance synchronization both ways, slider endpoints/center, List Options routing, module-specific close, and Player's stack-window minimize. Verify EQ/Playlist have exactly two trailing chrome buttons in both host types, with no hidden minimize hit target or accessibility element.
- Summary/time checks cover no loaded track, unknown duration, long text, long elapsed times, playlist reordering, removal of the loaded track from the list, selection differing from playback, and pause/stop.
- State checks cover repeated collapse/expand, reordering, detach/re-dock, close/reopen, relaunch with collapsed modules, and absence of duplicated subscriptions/display links.
- Keyboard and VoiceOver checks cover every visible control, module actions, focus restoration, hidden-content exclusion, and current control values.
- Build and run `./scripts/run-tests.sh` in the implementation checkout, preserving existing audio/playlist/ENTHEA suites. Run formatting/lint wrappers before committing if installed. Do not use `swift test`; the package has no test target.

## Review decisions

Volume and balance semantics and the two-button EQ/Playlist chrome are confirmed. The extra EQ/Playlist minimize buttons in the compact mockup are explicitly rejected as screenshot errors. The draft proposes the Playlist icon opening existing List Options, measured per-module compact heights, and using the recovered button space for the adjacent controls as described above. These choices are explicit so they can be reviewed before implementation. Further visual deviations require concrete comparison evidence and approval under the original spec's visual contract.
