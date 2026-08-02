# ENTHEA as the Visualizer Panel

**Date:** 2026-08-02  
**Status:** Approved for planning  
**Upstream:** [elder-plinius/ENTHEA](https://github.com/elder-plinius/ENTHEA) (AGPL-3.0)  
**Supersedes (panel body):** Metal fullscreen path in [2026-08-01-milkdrop-panel-design.md](./2026-08-01-milkdrop-panel-design.md) — panel chrome / docking / `showVisualizer` stay

## Goal

Replace the Visualizer panel’s Metal “MilkDrop” body with a vendored, adapted build of **ENTHEA** (WebGL2 psychedelic / music visualizer) hosted in `WKWebView`, driven by this app’s playback and `AudioFeatureBus`. Keep the existing Classic panel shell (show/hide, dock, size, pledit chrome). Eventually remove the fullscreen Metal MilkDrop path. Later, replace the main-window 76×16 mini visualizer with an ENTHEA-derived preview (dedicated stage — not part of the first panel cutover).

This is a personal fork: shipping ENTHEA and relicensing the combined work to AGPL-3.0 is intentional.

## Non-goals

- Rewriting ENTHEA’s 29 modes in Metal as a **required** deliverable (kept only as **optional last stage**)
- A separate forever “Enthea” panel ID alongside Visualizer
- Browser tab-capture / Web MIDI as primary audio inputs (native player owns audio)
- Changing EQ / playlist docking semantics (see note below — out of scope on purpose)

**Not non-goals (explicit later stages):** main-window mini ENTHEA preview; substance / phenomenology preset UI with careful copy; optional full Metal port.

### What “EQ / playlist docking semantics” means

Today the app lays out panels like classic Winamp:

- **Main** is the anchor.
- **EQ** and **playlist** stack in a **vertical column** under main (pack/unpack when shown/hidden; snap as a column).
- **Visualizer** docks to the **right of main** by default and is **excluded** from that vertical pack — it floats/docks via geometry, not as “panel #3 in the stack.”

“Changing EQ / playlist docking semantics” would mean redesigning that behavior (e.g. user-reorderable stacks, visualizer in the vertical column, new snap rules). **This project does not do that** — ENTHEA only replaces what draws *inside* the existing visualizer window. EQ/playlist keep their current dock/pack rules.

## Decisions (locked)

| Topic | Choice |
|---|---|
| Placement vs MilkDrop | **ENTHEA replaces the Visualizer panel body** (same `showVisualizer` / `.visualizer`) |
| Migration | Short **Classic / Enthea** body switch while validating; then remove Metal fullscreen |
| Mini LCD | **Metal until Stage 8**; then replace with ENTHEA-derived preview (see below) |
| Embedding | Vendored ENTHEA HTML in app bundle + `WKWebView` |
| Audio | Inject from `AudioFeatureBus` / player clock; mute ENTHEA’s own Web Audio output |
| License | Relicense **this fork** to **AGPL-3.0**; keep MIT upstream + ENTHEA attribution |
| Theater | Fullscreen / large window is an enhancement of the same Visualizer (not a 4th panel) |
| ENTHEA chrome | Prefer **hidden** (`H`); Classic strip + menus drive mode / autopilot / dose |
| Substance UI | Dedicated stage: expose phenomenology presets with **artistic / non-medical** copy + disclaimers |
| Metal port | **Optional last stage** — rewrite modes natively only if desired after WebKit path is done |

## Architecture

### High-level flow

```
AVAudioEngine → AudioFeatureBus (spectrum / waveform / energies)
                      ↓
              EntheaAudioBridge (display-linked, panel visible only)
                      ↓
         WKWebView ← evaluateJavaScript / message handlers
                      ↓
         Vendored ENTHEA (adapted index.html + bridge.js)
                      ↓
         Classic Visualizer panel chrome (title, strip, resize, close)
```

Track handoff (later stage): `AudioPlayer` / `PlaylistManager` current file URL + playhead → ENTHEA full-track analysis for predictive drops.

### Panel identity (unchanged)

- Keep `WinampPanelID.visualizer` (`"visualizer"`).
- Keep `WinampPanelLayoutState.showVisualizer`, `visualizerSize`, `visualizerMinimized`.
- Keep entry points: double-tap mini viz, options menu Show/Hide Visualizer, panel close.
- Do **not** add `showEnthea` or a fourth managed panel.

### Chrome / UI

Evolve `ClassicMilkdropPanelView` (rename when Metal body is gone, e.g. `ClassicVisualizerPanelView`):

```
┌─ classic title bar (shade + close + drag) ──────────────┐
│  ◀  ENTHEA • mode / autopilot                       ▶  │  ← control strip
│                                                         │
│              WKWebView (ENTHEA WebGL2)                   │
│                                                         │
└─ classic border / resize grip (BR) ─────────────────────┘
```

- **Migration strip:** temporary toggle or segment **Metal | Enthea** until Metal fullscreen is deleted.
- **Post-migration strip:** mode prev/next, autopilot, optional dose / reseed / force-drop; hide ENTHEA’s HTML UI by default.
- **Windowshade / resize / dock:** same as today’s MilkDrop panel (right of main by default, 600×450, Zoom-scaled).
- **Hide:** tear down or unload WebView content (same hygiene as Metal teardown today) so GPU/WebContent process stops when `showVisualizer == false`.

### Hosting

New AppKit bridge (names indicative):

| Unit | Responsibility |
|---|---|
| `EntheaWebView` (`NSViewRepresentable`) | `WKWebView` filling panel body; `sizingOptions`-safe layout like `MilkdropMTKHostView` |
| `EntheaBundleLoader` | Load vendored `Resources/Enthea/` via `loadFileURL` / bundle URL |
| `EntheaAudioBridge` | Snapshot `AudioFeatureBus` → JS while visible |
| `EntheaControlBridge` | Swift → JS commands (mode, autopilot, dose, UI hide, reseed, drop) |
| `EntheaTrackBridge` (Stage 6) | File URL / seek / isPlaying → predictive analysis |

Prefer a thin `bridge.js` + small patches to vendored `index.html` over a giant in-Swift HTML string. Keep upstream ENTHEA attribution in-tree (`NOTICE` or header comment).

### Audio bridge contract

JS surface (illustrative; exact names fixed in implementation plan):

```js
window.winampAudio = {
  push(features) { /* spectrum[], waveformL/R, bass/mid/treble/overall, t, isPlaying */ },
  // optional later:
  loadTrack({ url, duration }) { … },
  setPosition(seconds) { … },
};
window.winampEnthea = {
  setMode(idOrDelta) { … },
  setAutopilot(on) { … },
  setDose(delta) { … },
  hideChrome() { … },
  fireDrop() { … },
  reseed() { … },
};
```

Rules:

- While the panel is visible and playing, push features at ~display refresh (or ENTHEA’s expected analyser rate); pause pushes when hidden or idle if ENTHEA allows a static frame.
- ENTHEA must **not** open mic / play its own music by default inside the app.
- Map 32-band log spectrum + energies into ENTHEA’s 7-band / analyser expectations in the adapter (document the mapping in code comments).

### Fullscreen theater

- Same visualizer module: menu or strip control expands to fullscreen (or a large borderless window), equivalent to ENTHEA `F`.
- Exit restores docked panel size/position from layout state.
- Not a separate `WinampPanelID`.

### Main-window mini visualizer

Yes — replacing the mini LCD **is** the former non-goal “Putting ENTHEA in the main-window 76×16 mini visualizer.” It is now an **explicit later stage**, not part of the first panel cutover.

Constraints:

- Slot is ~**76×16** Classic pixels (scaled with Zoom) — a full second ENTHEA `WKWebView` there is possible but heavy and nearly unreadable as a UI.
- Double-tap must keep toggling `showVisualizer`.

**Recommended approach (Stage 8):** ENTHEA-**derived** preview, not a naive second full app instance:

1. Prefer **shared preview**: when the Visualizer panel is open, periodically sample / downscale the panel WebGL into the LCD (or a tiny offscreen WebView sized for the LCD only while the panel is open).
2. When the panel is **closed**, show a cheap fallback (last frame, idle ENTHEA-tinted bars, or current Metal spectrum) so the main window does not keep a WebContent process forever.
3. Only if shared preview is insufficient, evaluate a dedicated tiny WebView with extreme cost controls (paused when main occluded, low FPS).

Exact sampling API is an implementation detail for that stage’s plan; Stage 8 is the product commitment.

## License

1. Replace root `LICENSE` with **AGPL-3.0**.
2. Document in `README.md` / `AGENTS.md` / `USAGE.md`:
   - This combined work is AGPL-3.0.
   - Original winamp-macos / upstream lineage remains MIT-licensed code incorporated under AGPL terms.
   - ENTHEA © Pliny / elder-plinius, AGPL-3.0, vendored under `Resources/Enthea/` (or equivalent).
3. Add a short `NOTICE` (or README section) listing third-party AGPL/MIT components.

No attempt to keep the distributed app MIT-only while bundling ENTHEA.

## Staged delivery

Each stage leaves the app buildable and usable.

| Stage | Deliverable |
|---|---|
| **0 — License** | AGPL-3.0 + attribution docs |
| **1 — Host shell** | Visualizer panel can show a blank/`WKWebView` host with correct sizing, show/hide teardown |
| **2 — Boot ENTHEA** | Vendored HTML loads; WebGL paints; ENTHEA UI hidden; flicker off; first-open photosensitive note |
| **3 — Live audio** | `AudioFeatureBus` → bridge; visuals react to current track; no double audio |
| **4 — Classic controls** | Strip/menus for mode, autopilot, dose, reseed; persist last mode/autopilot |
| **5 — Theater + retire Metal path** | Fullscreen theater; remove Metal\|Enthea switch and fullscreen Metal MilkDrop (**mini LCD still Metal**) |
| **6 — Predictive drops** | Track file + playhead sync; drop arsenal works with playlist |
| **7 — Polish** | Album art → Image Warp; FPS/visibility caps; `USAGE.md` shortcuts |
| **8 — Mini ENTHEA LCD** | Replace main-window 76×16 Metal viz with ENTHEA-derived preview (shared/downscaled preferred); keep double-tap → panel |
| **9 — Substance / phenomenology UI** | Classic menu or strip for ENTHEA substance presets; **artistic interpretation** copy only; disclaimers (not dosing/medical advice); photosensitive note remains |
| **10 — Optional Metal port** | Optionally rewrite ENTHEA modes (up to all 29) in Metal — last, only if WebKit cost or native desire justifies it |

**Minimum “ENTHEA is the visualizer panel”:** Stages 0–5.  
**Full product intent:** through Stage 9.  
**Stage 10** is explicitly optional.

## Testing

| Case | Kind |
|---|---|
| License/docs mention AGPL + ENTHEA attribution | Doc review |
| `showVisualizer` still defaults false; size/dock persistence unchanged | Existing layout tests |
| EQ/playlist vertical pack unchanged after visualizer work | Existing dock/pack tests + manual |
| WebView torn down or idle when panel hidden | Manual / light unit on bridge `isActive` |
| Audio push only while visible | Unit on bridge gate |
| Feature mapping (32-band → ENTHEA input) documented + smoke | Manual with known track |
| Controls: mode / autopilot / close / shade / resize | Manual + `./scripts/shoot.sh` |
| Track change updates analysis (Stage 6) | Manual |
| Photosensitive note once | Manual / defaults flag |
| Mini LCD ENTHEA preview + double-tap (Stage 8) | Manual / shoot |
| Substance UI copy has disclaimer, no medical claims (Stage 9) | Doc + UI review |

Automated UI tests for WebGL content are out of scope; prefer bridge unit tests + interactive verification.

## Risks

| Risk | Mitigation |
|---|---|
| WebKit WebGL2 / perf vs Chrome | Smoke early (Stage 2); cap FPS when docked; theater for heavy modes |
| ENTHEA assumes Web Audio analyser shape | Adapter layer; do not expect mic/tab path inside app |
| File URL / sandbox for track analysis | Use security-scoped bookmarks / readable temp copies as needed (Stage 6) |
| Large single HTML hard to patch | Isolate patches in `bridge.js` + minimal hooks; vendor with clear commit hash / tag |
| Photosensitive flicker | Flicker off by default; one-time warning |
| Key focus in borderless panel | Forward only when visualizer is key window; don’t steal playlist hotkeys |
| Mini LCD WebKit cost (Stage 8) | Prefer shared/downscaled preview; avoid always-on second WebView |
| Substance UI misread as medical advice (Stage 9) | Explicit disclaimers; “artistic / phenomenological” framing only |

## Implementation outline (for the plan)

1. License + NOTICE + doc updates (Stage 0).
2. `EntheaWebView` host inside visualizer panel; blank load; hide teardown (Stage 1).
3. Vendor ENTHEA; boot with chrome hidden (Stage 2).
4. `EntheaAudioBridge` + JS adapter (Stage 3).
5. Control strip + persistence (Stage 4).
6. Theater + delete Metal fullscreen / rename panel view (Stage 5).
7. Track/position bridges + drop UX (Stage 6).
8. Polish + USAGE (Stage 7).
9. Mini LCD ENTHEA-derived preview (Stage 8).
10. Substance / phenomenology preset UI + disclaimers (Stage 9).
11. Optional Metal port (Stage 10) — only if pursued.
## References

- [ENTHEA README](https://github.com/elder-plinius/ENTHEA)
- [ENTHEA SCIENCE.md](https://github.com/elder-plinius/ENTHEA/blob/main/SCIENCE.md)
- Existing panel: `ClassicMilkdropPanelView`, `WinampPanelWindowManager`, `WinampPanelLayoutState`
- Audio: `AudioFeatureBus`, `AudioFeatures`, `AudioPlayer` spectrum tap
