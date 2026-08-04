# ENTHEA as the Visualizer Panel

**Date:** 2026-08-02 (revised 2026-08-02 after upstream source review)  
**Status:** Approved for planning  
**Upstream:** [elder-plinius/ENTHEA](https://github.com/elder-plinius/ENTHEA) (AGPL-3.0), reviewed at commit `f8eaf39d36178a0097cb6219c67ec1920d2ed7e6`  
**Supersedes (panel body):** Metal fullscreen path in [2026-08-01-milkdrop-panel-design.md](./2026-08-01-milkdrop-panel-design.md) — panel chrome / docking / `showVisualizer` stay

### Upstream facts this design depends on

Read from `index.html` at the pinned commit. Re-verify if the pin moves.

| Fact | Value |
|---|---|
| Size / structure | 216 KB, 3089 lines, **one** classic `<script>` block (lines 358–3087), no modules |
| External dependencies | **None** — zero `fetch`/CDN/remote URLs; fully offline |
| Globals | `AUDIO`, `S`, `MODES`, `SUBSTANCES` are `const` → **not** on `window`; `setMode`, `fireDrop`, `togglePanel`, `toggleFull`, `cycleWall` are `function` declarations → **are** on `window` |
| Audio input | Everything derives from `AUDIO.analyser.getByteFrequencyData()` (1024 linear bins) + `getFloatTimeDomainData()` (2048 float samples) + optional `AUDIO.anL`/`anR` for stereo |
| Analysis gate | `updateAudio(dt)` early-returns unless `S.audio.on && AUDIO.analyser` |
| Bin math | Linear: `binHz = (AUDIO.ctx.sampleRate * 0.5) / d.length`; generic over `d.length` |
| Track timeline | `analyzeTrack()` returns a plain `{dur, drops[], sections[], fps, _di, _si, _lastCt, _cd, _sx}` assigned to `S.timeline`; `updateTimeline()` reads only `S.timeline` + `AUDIO.fileEl.currentTime` / `.paused` |
| Rendering | One ~1000-line GLSL uber-shader with 36 `uMode` branches, plus COMPOSE / PRESENT / transform-feedback programs; DPR capped at 2 internally |
| Keyboard | Global `keydown` listener binds `space` (with `preventDefault`), `a b d f h j k m r t w =` and `1`–`8` |
| Storage | `localStorage` for scene snapshots + MIDI map, all `try`/`catch`-guarded |

### Stage −1 spike results — measured, gate **passed**

Bare `WKWebView` + unpatched upstream `index.html`, MacBook Pro M1 Pro (16-core GPU), macOS 26.5.2,
built-in Liquid Retina XDR (`backingScaleFactor` 2, `maximumFramesPerSecond` 120). rAF-counter FPS
over 4 s windows per mode, all 29 modes, autopilot disabled. Verdict: **Go with clamps.**

| Measurement | Result |
|---|---|
| Cold boot → first frame, first-ever launch (cold OS caches) | **1699 ms** |
| Cold boot → first frame, first load in a fresh app process | **416–554 ms** |
| Re-boot in a fresh `WKWebView` inside a live process | **226–288 ms** |
| Steady FPS at 600×450 @ DPR 2 (1200×900 backing) | **60.0 fps in all 29 modes**, zero dropped frames |
| Heaviest modes at panel size | No mode is heavy at panel size — worst is 59.8 fps |
| DPR 2 vs DPR 1 at panel size | Both 60 fps; GPU device utilization median **53 % vs 38 %** (idle baseline 13–21 %) |
| Theater 1728×1080 pt @ DPR 2 (3456×2160) | **2 modes < 30 fps** (SACRED GEOM 24, HYPERSPACE 26), 3 modes < 45 |
| Theater 1728×1080 pt @ DPR 1 | All modes 60 fps |
| 60 fps pixel budget (worst mode) | Holds to ~**2.0 Mpx** backing; 55 fps at 3.0 Mpx, 40 fps at 4.3 Mpx, 30 fps at 5.9 Mpx |
| Visible-but-silent cost, panel size | ~**20 % of one CPU core** (WebContent ≈ 8 %, GPU process ≈ 9.5 %, host ≈ 3.4 %); GPU device util ~50 % |
| Window ordered out, web view still alive | rAF **fully suspends — 0.0 fps**, GPU returns to baseline, reshow resumes at 60 fps with no re-boot |
| WebKit helper resident memory | ~136 MB (WebContent 63, GPU 57, Networking 16) |
| GLSL uber-shader compile | Never blocks the JS thread — first 12 rAF callbacks run in 6, 1, 1, 1 … ms |
| Mode switching | Free. One uber-shader covers all 36 `uMode` branches; no stall on `setMode` |

## Goal

Replace the Visualizer panel’s Metal “MilkDrop” body with a vendored, adapted build of **ENTHEA** (WebGL2 psychedelic / music visualizer) hosted in `WKWebView`, driven by this app’s playback and `AudioFeatureBus`. Keep the existing Classic panel shell (show/hide, dock, size, pledit chrome). Eventually retire the Metal MilkDrop *panel body*. Later, give the main-window 76×16 mini visualizer an ENTHEA-derived look — as a native Metal mode, not as embedded web content (dedicated stage — not part of the first panel cutover).

This is a **private, undistributed** personal fork. That fact does real work in this design: it removes the AGPL question entirely (see *License*) and it means "ship" throughout this doc means "runs on my machine," not "released."

## Non-goals

- Rewriting ENTHEA’s 29 modes in Metal as a **required** deliverable (kept only as **optional last stage**; Stage 8 ports exactly **one** cheap mode for the mini LCD, which is not the same thing)
- A separate forever “Enthea” panel ID alongside Visualizer
- Browser tab-capture / Web MIDI as primary audio inputs (native player owns audio)
- Changing EQ / playlist docking semantics (see note below — out of scope on purpose)

**Not non-goals (explicit later stages):** ENTHEA-styled main-window mini visualizer; substance / phenomenology preset UI with careful copy; optional full Metal port.

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
| Migration | **Metal \| Enthea** body switch through Stages 1–4, **defaulting to Metal** until Stage 3; the visible switch goes away in Stage 5, the hidden kill switch outlives it |
| Mini LCD | **Metal permanently.** Stage 8 restyles it as an ENTHEA-*derived Metal* mode — no second `WKWebView`, no snapshotting |
| Embedding | Vendored ENTHEA HTML in app bundle + `WKWebView`, loaded from a **folder reference** |
| Audio | **Impersonate `AUDIO.analyser`** — feed raw linear FFT bins + PCM so ENTHEA’s own DSP runs unmodified (see below). No bespoke feature contract |
| Spectrum source | New raw-bin channel on `AudioFeatureBus` (512 linear magnitudes); the 32 log bands are **not** sufficient |
| License | **Leave `LICENSE` alone.** Private repo, no distribution → no AGPL obligations. Vendor ENTHEA's own `LICENSE` beside its source and record the trigger condition in `VENDOR.md` |
| Theater | Expand to `screen.visibleFrame` and restore from layout state. **Not** `NSWindow.toggleFullScreen` — the panel is borderless with `collectionBehavior = []` |
| ENTHEA chrome | Prefer **hidden** (`H` / `togglePanel()`); Classic strip + menus drive mode / autopilot / dose |
| ENTHEA keyboard | **Disabled entirely.** Its `keydown` listener binds `space` with `preventDefault` — a direct collision with play/pause |
| Kill switch | Hidden `UserDefaults` flag restores the Metal panel body even after the switch UI is gone; kept until Stage 7 has shipped |
| Substance UI | Dedicated stage: expose phenomenology presets with **artistic / non-medical** copy + disclaimers |
| Metal port | **Optional last stage** for the *panel*. Stage 8 ports one cheap mode for the mini LCD regardless, establishing the pattern Stage 10 would reuse |

## Architecture

### High-level flow

```
AVAudioEngine → FFTSpectrumAnalyzer
                      ↓
        AudioFeatureBus ── 32 log bands ──→ Metal mini viz (unchanged)
                      └── 512 raw linear bins + 2048 PCM L/R  (new channel)
                                    ↓
              EntheaAudioBridge (display-linked, panel visible only)
                                    ↓
                    WKWebView ← evaluateJavaScript (coalesced)
                                    ↓
              bridge.js installs a FAKE AUDIO.analyser
                                    ↓
              ENTHEA's own updateAudio() runs UNMODIFIED
              (7 bands, centroid, flux, onsets, BPM, beat grid,
               build envelope, drop detection, crest, ZCR)
                                    ↓
         Classic Visualizer panel chrome (title, strip, resize, close)
```

Track handoff (later stage): `AudioPlayer` / `PlaylistManager` → **native Swift** offline analysis → a timeline object assigned to `S.timeline`, plus a shimmed `AUDIO.fileEl` clock. ENTHEA never touches the audio file.

### Why the analyser shim, and not a feature contract

The obvious design — define `window.winampAudio.push({spectrum, bands7, bass, mid, …})` and patch ENTHEA to read it — throws away most of what makes ENTHEA worth vendoring. Its entire analysis chain hangs off two calls inside `updateAudio(dt)`:

```js
AUDIO.analyser.getByteFrequencyData(AUDIO.data);
const d = AUDIO.data, n = d.length, binHz = (AUDIO.ctx.sampleRate * 0.5) / n;
…
AUDIO.analyser.getFloatTimeDomainData(AUDIO.wave);
if (AUDIO.anL && AUDIO.anR) { AUDIO.anL.getFloatTimeDomainData(AUDIO.waveL); … }
```

Everything downstream is derived: the 7 pitch-mapped bands, spectral centroid, spectral flux, onset and kick detection, BPM from inter-onset intervals, the grid-locked beat phase, the build/anticipation envelope, the "calm-before" primed state, reactive drop firing, crest factor, and zero-crossing rate. Substituting a hand-rolled payload means reimplementing all of that in Swift — badly — instead of reusing it.

**Decision:** `bridge.js` replaces `AUDIO.analyser` (and `AUDIO.anL` / `AUDIO.anR`) with plain objects whose two methods `.set()` from buffers that Swift refreshes, stubs `AUDIO.ctx` as `{ sampleRate }`, and sets `S.audio.on = true`. ENTHEA's `updateAudio` is untouched. This is the only patch point in the analysis path.

### Why raw FFT bins are a prerequisite

`AudioFeatures.spectrum` is **32 log-spaced bands, 60 Hz → Nyquist**, already normalized to 0–1 across a −60/+18 dB window. ENTHEA's `band(f0, f1)` helper indexes bins **linearly**, and spectral flux is a frame-to-frame difference across all bins. Upsampling 32 log bands into a linear array produces a stair-stepped spectrum whose flux is ~zero except at the handful of step boundaries — onset detection, BPM, and reactive drop detection would degrade or fail silently. The result would look reactive but never lock to the beat, which is the whole point.

`FFTSpectrumAnalyzer` already computes 512 linear magnitudes (1024-point FFT) internally and discards them. Publishing that array on a new `AudioFeatureBus` channel is the fix. ENTHEA's `updateAudio` is generic over `d.length`, so a **512**-entry `Uint8Array` works without modification — `AUDIO.ctx.sampleRate` just has to be truthful so `binHz` comes out right.

### Feature plumbing rules

- Push **raw, unsmoothed** values. `VisualizationFeatureSmoother` exists for the Metal path; ENTHEA does its own `approachTau` smoothing and double-smoothing mushes beat detection.
- Waveform sizing already matches: `AudioFeatures.scopeWaveformSampleCount` is 2048 with separate L/R, exactly what `AUDIO.wave` / `anL` / `anR` want.
- **Document two known offsets.** (1) `WaveformRingBuffer.readResampled(count:)` stretches the whole 4096-sample ring (~93 ms @ 44.1 kHz) into the requested count, so a 2048-sample read is half-rate — ENTHEA's `zcr` (`zc/wn*4`) reads ~2× low. (2) The ring is appended per tap at ~10 Hz while the spectrum is paced per hop-frame at display rate by `VisualizationPlayoutClock`, so waveform-derived features (crest, ZCR, the polar scope) stair-step at 10 Hz while spectral features are smooth.
- Never start mic, tab capture, or ENTHEA's entrainment drone.

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

- **Migration strip:** temporary toggle or segment **Metal | Enthea** through Stages 1–4. Default is **Metal** until Stage 3 proves live audio works — a stage that ships a green "ENTHEA host" placeholder where the visualizer used to be violates the "every stage leaves the app usable" rule.
- **Post-migration strip:** mode prev/next, autopilot, optional dose / reseed / force-drop; hide ENTHEA’s HTML UI by default.
- **Kill switch:** when the visible Metal|Enthea segment is removed in Stage 5, a hidden `UserDefaults` flag keeps the Metal body reachable. Retired after Stage 7.
- **Windowshade / resize / dock:** same as today’s MilkDrop panel (right of main by default, 600×450, Zoom-scaled).
- **Hide:** release the `WKWebView` (not just blank it) so the WebContent process actually exits. `WinampPanelWindowManager.hidePanel` already nils `contentViewController` for `.visualizer`, which achieves this — the representable must not hold the web view alive past that.

### Hosting

New AppKit bridge (names indicative):

| Unit | Responsibility |
|---|---|
| `EntheaWebView` (`NSViewRepresentable`) | `WKWebView` filling panel body; `sizingOptions`-safe layout like `MilkdropMTKHostView` |
| `EntheaBundleLoader` | Resolve vendored `Resources/Enthea/` directory for `loadFileURL(_:allowingReadAccessTo:)` |
| `EntheaAudioBridge` | Snapshot `AudioFeatureBus` → JS while visible, with in-flight coalescing |
| `EntheaControlBridge` | Swift → JS commands (mode, autopilot, dose, UI hide, reseed, drop) |
| `EntheaTrackBridge` (Stage 6) | Native timeline + playhead clock → `S.timeline` / `AUDIO.fileEl` shim |

Prefer a thin `bridge.js` + small patches to vendored `index.html` over a giant in-Swift HTML string. Keep upstream ENTHEA attribution in-tree (`Resources/Enthea/LICENSE` + `VENDOR.md`).

#### Hosting constraints (all verified against the current codebase)

- **Bundling must use a folder reference.** `project.pbxproj` uses a `PBXFileSystemSynchronizedRootGroup` for `Sources/` but *individual file references* for every resource today (`startup.mp3`, the two TTFs). Adding `index.html` / `bridge.js` as individual files flattens them into `Contents/Resources/`, the `Enthea/` subdirectory never exists, and both lookup paths return `nil` — silently, at runtime, as a blank panel. `allowingReadAccessTo:` needs the real directory anyway. A unit test asserting the resource resolves from `Bundle.main` is the highest-value test in this project.
- **`WKWebView` needs a `WKWebViewConfiguration`** for `WKUserScript` injection and message handlers. Use `WKWebsiteDataStore.nonPersistent()` — ENTHEA's `localStorage` writes (scene snapshots, MIDI map) are all `try`/`catch`-guarded, so losing them is harmless.
- **No private KVC.** Do not `setValue(false, forKey: "drawsBackground")`. Use `underPageBackgroundColor`.
- **Script world and order matter.** ENTHEA's `AUDIO` / `S` / `MODES` are `const` at classic-script top level, so they are *not* `window` properties. Bare-identifier resolution reaches them from anything evaluated later **in the page content world only** — never from an isolated `WKContentWorld`. Load `bridge.js` *after* ENTHEA's script and pin the content world explicitly, or every call silently no-ops.
- **Kill ENTHEA's keyboard.** Its global `keydown` handler binds `space` with `preventDefault()` (cycles visual mode), plus `a b d f h j k m r t w =` and `1`–`8`. Space is play/pause, and this fork has in-flight playlist-hotkey work (`WinampHotkeys`, `WinampPlaylistKeyboard`). Remove or neuter the listener and/or refuse first responder on the host view. This is a Stage 2 requirement, not polish.
- **Keep releasing the web view on hide.** Only releasing the `WKWebView` stops the WebContent process, which `WinampPanelWindowManager`'s existing `contentViewController = nil` on hide already achieves. The spike measured the re-boot cost at **226–288 ms** inside a live process (416–554 ms for the first show after app launch), so the "if it is multi-second, keep it alive instead" escape hatch does **not** trigger. Keep the teardown; it reclaims ~136 MB. Keep-alive stays available as a cheap latency optimization if the re-show gap ever feels bad — the spike confirmed a hidden window suspends rAF completely (0 fps, GPU at baseline), so a retained hidden web view burns nothing but memory.
- **Cap the resolution — measured budget ~2.0 Mpx.** ENTHEA caps DPR at 2 internally, which is fine at panel size (600×450 pt → 1200×900 = 1.08 Mpx → 60 fps in every mode) but not in theater (3456×2160 = 7.5 Mpx → 24 fps in SACRED GEOM). Clamp the backing store to a pixel budget rather than to a fixed DPR:

  ```swift
  let budget = 2_000_000.0  // backing pixels; 60 fps in all 29 modes on M1 Pro
  let fit = (budget / (widthPt * heightPt)).squareRoot()
  let scale = min(max(min(window.backingScaleFactor, fit), 1.0), 2.0)
  ```

  That yields the full 2.0 at panel sizes up to ~1000×750 pt and ~1.03 in theater, matching the measured 60 fps points. Feed the result to ENTHEA's `resize()` in place of `window.devicePixelRatio`.
- **Idle power policy (locked for Task 2+ / Stage 7):** No FPS cap is needed for *throughput* at panel size (60 fps locked). For *power*, when the Visualizer panel is visible but playback is **stopped** (or the panel is minimized), **pause the ENTHEA render loop to 0 fps** (do not keep a soft throttle like 15 fps). Resume at full rate when playback starts again. Hidden/torn-down panel already costs 0 fps via WebView release. Implement the pause in Stage 7; Stages 2–6 may leave continuous draw until then.
- **Coalesce the audio push.** `evaluateJavaScript` is an async IPC round trip; a naive 60 Hz timer queues unboundedly if the web process stalls. Skip a push while the previous one is in flight, and prefer a base64 binary blob over JSON (512 bins + 2×2048 floats is ~50 KB/frame as JSON).

### Audio bridge contract

JS surface (illustrative; exact names fixed in implementation plan):

```js
window.winampAudio = {
  // Base64 blob: 512 uint8 linear FFT bins, then 2048 float32 L, then 2048 float32 R.
  // bridge.js decodes into the buffers the fake analyser hands out. No feature fields —
  // ENTHEA derives bands/centroid/flux/BPM/drops itself.
  push(blob, sampleRate, isPlaying) { … },
  setTimeline(timeline) { … },   // Stage 6 — native-computed {dur, drops[], sections[]}
  setPosition(seconds, paused) { … },  // Stage 6 — drives the AUDIO.fileEl shim
};
window.winampEnthea = {
  setMode(idOrDelta) { … },      // → window.setMode(i, true)
  setAutopilot(on) { … },        // → #tgJourney
  setDose(delta) { … },
  hideChrome() { … },            // → window.togglePanel() / setCollapsed(true)
  fireDrop() { … },              // → window.fireDrop(false)
  reseed() { … },                // → S.reseed = 2
  setSubstance(id) { … },        // Stage 9
  ready: false,
};
```

Rules:

- While the panel is visible and playing, push at ~display refresh with in-flight coalescing; drop the rate or stop entirely when hidden, minimized, or idle.
- ENTHEA must **not** open mic, tab capture, its entrainment drone, or its own file playback inside the app.
- **No feature mapping layer.** The adapter's job is transport only — get raw bins and PCM into the fake analyser's buffers. Any "map 32 bands to 7" logic is a design smell here; see *Why the analyser shim*.

### Fullscreen theater

`NSWindow.toggleFullScreen` **will not work** on this window. `WinampWindowConfigurator.apply(to:resizable:)` creates panels as `[.borderless, .miniaturizable]` with `collectionBehavior = []`; native fullscreen needs at least `.fullScreenPrimary`, and borderless plus native fullscreen is unreliable even then. There is no `toggleFullScreen` call anywhere in `Sources/` today.

- **Approach:** expand the panel window frame to `screen.visibleFrame`, hide the Classic chrome, and restore size/position from `WinampPanelLayoutState` on exit. Optionally `NSApp.presentationOptions` to hide the menu bar.
- Do not route through ENTHEA's own `toggleFull()` / `requestFullscreen` — the page has no business owning the window.
- Exit restores docked panel size/position from layout state.
- Not a separate `WinampPanelID`.
- `USAGE.md:150` already claims "Fullscreen is available from the visualizer UI when open." That is currently false; this stage makes it true (or the line gets deleted earlier).

### Main-window mini visualizer

The 76×16 LCD **stays Metal, permanently.** Stage 8 gives it an ENTHEA-*derived look*, not ENTHEA pixels.

Both WebKit routes were considered and rejected:

- **`WKWebView.takeSnapshot` from the panel.** Forces a full render pass plus image encode, returns asynchronously, and would burn meaningful CPU at any useful frame rate — to fill 76×16 points. It also only works while the panel is open, so the Metal path has to exist as a fallback anyway, which means maintaining both.
- **A second tiny `WKWebView`.** A permanently resident WebContent process in the main window for a thumbnail-sized slot. Explicitly ruled out in the non-goals.

**Approach (Stage 8):** port one cheap ENTHEA mode to Metal (a `MetalVisualizationKind` case alongside the existing bars / analyzer / oscilloscope), driven from the same `AudioFeatureBus` the mini viz already reads. Result: an ENTHEA-styled LCD with zero WebKit cost, no snapshot plumbing, and no second process. This is the one place where the "optional Metal port" is actually the *right* answer rather than a fallback — which also shrinks Stage 10's scope, since a mode-porting pattern already exists by then.

Constraints:

- Slot is ~**76×16** Classic pixels (scaled with Zoom).
- Double-tap must keep toggling `showVisualizer`.
- Single-tap must keep cycling `visualizationMode` (`@AppStorage("visualizationMode")`); the ENTHEA-styled mode joins that cycle rather than replacing it.

## License

**Do nothing to `LICENSE`.** This is a private, undistributed repo, and every AGPL obligation attaches to an act this project never performs.

| AGPL clause | Trigger | Does it apply here? |
|---|---|---|
| §5 / §6 — source with conveyed binaries | *Conveying* a copy to someone else | No. Nothing is shipped |
| §13 — network clause | Users interacting with a modified version **over a network** | No. Local desktop app, no service |
| §2 — private modification | — | Explicitly permitted, unconditionally |

Nothing is "caught." Relicensing is available at the moment of distribution and costs nothing to defer, so deferring is strictly better than doing it now — it keeps the repo's own history MIT and avoids a change that is annoying to unwind across subsequent contributions.

### What to actually do (two small steps, both inside Stage 2)

1. **Vendor ENTHEA's `LICENSE` alongside its source** at `Resources/Enthea/LICENSE`. Standard vendoring hygiene, accurate as-is: root MIT covers this repo's code, the vendored subdirectory carries its own AGPL terms. Costs one `curl`.
2. **Record the trigger condition in `Resources/Enthea/VENDOR.md`** so future-you cannot miss it:

   > This directory is AGPL-3.0. This repo is private and undistributed, so no AGPL obligations are active. **Publishing this repo, or sharing a build with anyone, makes the combined work AGPL-3.0** — at that point replace the root `LICENSE` with AGPL-3.0 and add a `NOTICE` crediting the MIT upstream.

Optionally add one line to `README.md` noting the vendored AGPL component. No `NOTICE`, no relicense, no doc sweep across `README.md` / `AGENTS.md` / `USAGE.md`.

### Edge cases worth knowing, not worth acting on

- **A private repo with a few collaborators is fine.** Even if sharing the repo with them counts as conveying, they receive complete source including `Resources/Enthea/LICENSE` — which is exactly what AGPL requires.
- **If this ever goes public or a build gets shared**, the relicense becomes required, and Mac App Store distribution becomes impossible (Apple's terms conflict with GPL-family redistribution). Noted so the decision is informed, not to constrain anything today.
- **MIT → AGPL remains a valid one-way incorporation** if that day comes: MIT's only conditions are attribution and notice retention, both satisfied by AGPL distribution.

## Staged delivery

Each stage leaves the app buildable and usable.

| Stage | Deliverable |
|---|---|
| **−1 — WebKit spike** ✅ **done — Go with clamps** | Measured in a throwaway harness: 60 fps in all 29 modes at 600×450 @ DPR 2, 226–288 ms per re-boot. Carry the 2.0 Mpx resolution clamp into Stage 2. See *Stage −1 spike results* above |
| **0 — Raw FFT bins** | New `AudioFeatureBus` channel publishing 512 linear magnitudes from `FFTSpectrumAnalyzer`; Metal path unchanged. Pure Swift, unit-testable, useful independent of ENTHEA |
| **1 — Host shell** | Visualizer panel can show a blank/`WKWebView` host with correct sizing, show/hide teardown. Metal stays the default body |
| **2 — Boot ENTHEA** | Vendored HTML + ENTHEA's `LICENSE` + `VENDOR.md` land via a folder reference; WebGL paints; ENTHEA UI hidden; **keyboard listener neutered**; flicker off; DPR clamp; first-open photosensitive note |
| **3 — Live audio** | Fake-analyser shim fed from the raw-bin channel; ENTHEA's own DSP reacts to the current track; no double audio. Enthea becomes the default body |
| **4 — Classic controls** | Strip/menus for mode, autopilot, dose, reseed; persist last mode/autopilot |
| **5 — Theater + retire Metal panel path** | `visibleFrame` theater; remove Metal\|Enthea switch UI (**keep the hidden kill-switch flag**); retire the Metal MilkDrop *panel body* (**mini LCD still Metal**) |
| **6 — Predictive drops** | **Native Swift** offline track analysis → `S.timeline`; playhead shim; drop arsenal works with the playlist |
| **7 — Polish** | Album art → Image Warp; FPS/visibility caps; `USAGE.md` shortcuts. **Kill switch may be removed after this ships** |
| **8 — ENTHEA-styled mini LCD** | New ENTHEA-derived *Metal* mode in the main-window 76×16 viz, joining the tap-cycle; no WebKit involved; keep double-tap → panel |
| **9 — Substance / phenomenology UI** | Classic menu or strip for ENTHEA substance presets; **artistic interpretation** copy only; disclaimers (not dosing/medical advice); photosensitive note remains |
| **10 — Optional further Metal port** | Optionally rewrite more ENTHEA modes in Metal, reusing the Stage 8 porting pattern — last, only if WebKit cost or native desire justifies it |

**Minimum “ENTHEA is the visualizer panel”:** Stages −1 through 5.  
**Full product intent:** through Stage 9.  
**Stage 10** is explicitly optional.

### What Stage 5 does and does not delete

`FullscreenMetalPlugin` is exercised by `MetalVisualizationSmokeTests.testAllFullscreenPresetsRender`, shares `MetalVisualizationEngine` with the mini viz, and backs 11 `VisualizationPreset` cases plus a `fullscreenFragment` branch in `VisualizerShaders.metal`. Stage 5 **keeps all of it** — the kill switch depends on it, and it is cheap to leave compiled. Only the *default* body changes and the user-visible Metal|Enthea switch goes away. Deleting `FullscreenMetalPlugin`, the presets, the shader branch, and the smoke test is a separate decision to make after Stage 7, when the kill switch retires.

## Testing

| Case | Kind |
|---|---|
| **`EntheaBundleLoader` resolves `index.html` from `Bundle.main`** | **Unit — highest value; catches the folder-reference mistake** |
| Raw 512-bin channel: length, ordering, normalization (Stage 0) | Unit on `FFTSpectrumAnalyzer` / bus |
| Push payload encode/decode round-trip (bins + PCM survive base64) | Unit |
| Audio push gated off when hidden / minimized | Unit on bridge gate |
| Push coalescing: no enqueue while a previous eval is in flight | Unit with a fake `EntheaJavaScriptEvaluating` |
| Native timeline analyzer: known fixture → expected drop times (Stage 6) | Unit |
| `Resources/Enthea/` carries ENTHEA's `LICENSE` + a `VENDOR.md` naming the relicense trigger | Doc review |
| `showVisualizer` still defaults false; size/dock persistence unchanged | Existing layout tests |
| EQ/playlist vertical pack unchanged after visualizer work | Existing dock/pack tests + manual |
| **Space bar still plays/pauses while the visualizer panel is key** | **Manual — regression guard on the keyboard neuter** |
| Playlist hotkeys unaffected while visualizer is open | Manual |
| Theater expands to `visibleFrame` and restores docked geometry | Manual + existing layout tests |
| Kill-switch flag restores the Metal body | Manual |
| WebView released (not just blanked) when panel hidden | Manual / Activity Monitor |
| Beat lock: BPM readout tracks a known-tempo track | Manual with a click track |
| Controls: mode / autopilot / close / shade / resize | Manual + `./scripts/shoot.sh` |
| Photosensitive note once | Manual / defaults flag |
| ENTHEA-styled mini Metal mode + tap cycle + double-tap (Stage 8) | Metal smoke test + manual / shoot |
| Substance UI copy has disclaimer, no medical claims (Stage 9) | Doc + UI review |

Automated UI tests for WebGL content are out of scope; prefer bridge unit tests + interactive verification.

## Risks

| Risk | Mitigation |
|---|---|
| ~~**WebKit WebGL2 / perf vs Chrome**~~ — **retired, gate passed** | Measured 60 fps in all 29 modes at 600×450 @ DPR 2 with zero dropped frames. Residual risk is theater only, handled by the 2.0 Mpx clamp above |
| Forgetting the AGPL trigger if the repo is ever published | `Resources/Enthea/VENDOR.md` states it in the same place the vendored source lives |
| ~~Cold-boot cost of the 36-branch uber-shader on every panel show~~ — **retired, measured** | 226–288 ms per show in a live process; the compile never blocks the JS thread. Keep the release-on-hide teardown |
| **32 log bands are the wrong shape for ENTHEA's linear-bin DSP** | **Stage 0 publishes 512 raw linear bins**; never upsample the log bands |
| Silent degradation if bins are wrong | Verify beat lock against a known-BPM click track, not by eyeballing motion |
| ENTHEA assumes Web Audio analyser shape | Impersonate `AUDIO.analyser` rather than patching the analysis; do not expect mic/tab path inside app |
| **File URL / sandbox / codec support for track analysis** | **Do the analysis natively in Swift** (Stage 6) — no file handed to WebKit, no `decodeAudioData` FLAC/ALAC gamble, no per-track cache copy |
| Large single HTML hard to patch | Isolate patches in `bridge.js` + minimal hooks; vendor with pinned commit hash; keep the upstream-facts table current |
| `const` globals invisible to injected scripts | Load `bridge.js` after ENTHEA's script, pin the page content world, assert `ready` before issuing commands |
| Resource silently missing from the bundle | Folder reference + a unit test that resolves `index.html` from `Bundle.main` |
| Photosensitive flicker | Flicker off by default; one-time warning |
| **ENTHEA's `keydown` steals space / playlist hotkeys** | **Neuter the listener in Stage 2**; verify play/pause and playlist keys manually while the panel is key |
| Push backpressure collapsing the web process | In-flight coalescing; binary blob instead of JSON |
| Regret after the Metal panel body is gone | Hidden kill-switch flag; keep `FullscreenMetalPlugin` and its smoke test through Stage 7 |
| Mini LCD WebKit cost (Stage 8) | Not applicable — mini LCD stays Metal; Stage 8 is a Metal mode, not a preview |
| Substance UI misread as medical advice (Stage 9) | Explicit disclaimers; “artistic / phenomenological” framing only |

## Implementation outline (for the plan)

1. WebKit spike on a throwaway branch — go/no-go (Stage −1).
2. Raw 512-bin FFT channel on `AudioFeatureBus` (Stage 0).
3. `EntheaWebView` host inside visualizer panel; blank load; hide teardown; Metal still default (Stage 1).
4. Vendor ENTHEA (+ its `LICENSE` + `VENDOR.md`); boot with chrome hidden, keyboard neutered, DPR clamped (Stage 2).
5. Fake-analyser shim + `EntheaAudioBridge`; Enthea becomes default body (Stage 3).
6. Control strip + persistence (Stage 4).
7. `visibleFrame` theater + retire the Metal panel body behind a kill switch (Stage 5).
8. Native timeline analysis + playhead shim + drop UX (Stage 6).
9. Polish + USAGE; retire the kill switch (Stage 7).
10. ENTHEA-styled Metal mini viz mode (Stage 8).
11. Substance / phenomenology preset UI + disclaimers (Stage 9).
12. Optional further Metal port (Stage 10) — only if pursued.

## References

- [ENTHEA README](https://github.com/elder-plinius/ENTHEA)
- [ENTHEA SCIENCE.md](https://github.com/elder-plinius/ENTHEA/blob/main/SCIENCE.md)
- Existing panel: `ClassicMilkdropPanelView`, `WinampPanelWindowManager`, `WinampPanelLayoutState`
- Audio: `AudioFeatureBus`, `AudioFeatures`, `AudioPlayer` spectrum tap
