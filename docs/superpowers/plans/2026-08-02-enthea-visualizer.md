# ENTHEA Visualizer Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Visualizer panel’s Metal MilkDrop body with vendored ENTHEA (WKWebView + a fake-AnalyserNode audio shim), then deliver theater, natively-computed predictive drops, an ENTHEA-styled Metal mini viz, and substance UI per the approved spec.

**Licensing: nothing to do.** This repo is private and undistributed, so no AGPL obligation is active — §5/§6 attach to conveying, §13 to network interaction, and §2 permits private modification unconditionally. Task 2 vendors ENTHEA's own `LICENSE` next to its source and records the relicense trigger in `VENDOR.md`. The root `LICENSE` is not touched.

**Architecture:** Keep `WinampPanelID.visualizer` / `showVisualizer` unchanged. Host a fill-bounds `WKWebView` inside Classic pledit chrome (`ClassicMilkdropPanelView` → rename later). **Do not invent a feature contract** — publish raw 512-bin linear FFT magnitudes on `AudioFeatureBus`, then impersonate `AUDIO.analyser` in `bridge.js` so ENTHEA's own DSP (bands, centroid, flux, onsets, BPM, beat grid, build envelope, drop detection) runs unmodified. Drive modes via `window.winampEnthea`. Temporary Metal|Enthea switch through Tasks 1–4, **defaulting to Metal** until Task 3; a hidden kill switch replaces it in Task 5. EQ/playlist docking untouched.

**Tech Stack:** Swift 6, SwiftUI + AppKit, WebKit (`WKWebView`), vendored ENTHEA HTML/JS (WebGL2), `AudioFeatureBus` + vDSP, XCTest

**Spec:** `docs/superpowers/specs/2026-08-02-enthea-visualizer-design.md`

**Upstream pin:** `elder-plinius/ENTHEA` @ `f8eaf39d36178a0097cb6219c67ec1920d2ed7e6`. The spec's *Upstream facts* table records everything this plan assumes about that file — re-verify it if the pin moves.

## Global Constraints

- No commits unless the user explicitly asks
- **Task −1 is a hard gate.** No vendoring, no `Resources/Enthea/` until the WebKit spike passes
- Do **not** touch the root `LICENSE`, and do **not** create a `NOTICE`. See the licensing note above
- Do **not** add a fourth panel ID or `showEnthea` — reuse `.visualizer` / `showVisualizer`
- Do **not** change EQ / playlist vertical-pack / docking semantics
- Do **not** write a "32 log bands → 7 bands" mapper. If a task seems to need one, the raw-bin channel from Task 0 is missing or wired wrong
- Mini LCD stays Metal **permanently**; Task 8 adds a Metal mode, never a second `WKWebView`
- ENTHEA must not open mic, tab capture, its entrainment drone, or its own file playback
- ENTHEA's `keydown` listener must be dead before Task 2 ships — `space` is play/pause
- Flicker drive off by default; first-open photosensitive note (Task 2)
- Substance UI copy is artistic / phenomenological only — no medical or dosing advice (Task 9)
- Task 10 (further Metal ports) is **optional** — skip unless explicitly pursued
- Minimum shippable “ENTHEA is the visualizer”: Tasks −1 through 5
- Tests: `./scripts/run-tests.sh` after tasks that touch Swift; WebGL content is manual / `./scripts/shoot.sh`
- Follow Swift API Design Guidelines; run `./scripts/format-swift.sh` / lint if tools installed before commit batches

## File map

| File | Role |
|---|---|
| `USAGE.md` | ENTHEA usage + shortcuts (Task 7) |
| `Resources/Enthea/LICENSE` | ENTHEA's own AGPL-3.0 text, vendored beside its source |
| `Sources/Audio/FFTSpectrumAnalyzer.swift` | Publish raw 512-bin magnitudes (Task 0) |
| `Sources/Audio/AudioFeatureBus.swift` | New raw-bin channel + snapshot accessor (Task 0) |
| `Resources/Enthea/index.html` | Vendored ENTHEA (pinned commit) |
| `Resources/Enthea/bridge.js` | Fake-analyser shim + control surface |
| `Resources/Enthea/VENDOR.md` | Source URL, commit hash, patch notes |
| `Winamp.xcodeproj/project.pbxproj` | **Folder reference** for `Resources/Enthea`; link WebKit if needed |
| `Sources/Enthea/EntheaBundleLoader.swift` | Resolve bundle directory + index URL |
| `Sources/Enthea/EntheaWebView.swift` | `NSViewRepresentable` + fill-bounds `WKWebView` host |
| `Sources/Enthea/EntheaAudioBridge.swift` | Gate + coalesce + encode raw bins/PCM → JS |
| `Sources/Enthea/EntheaAudioPayloadCodec.swift` | Pure bins+PCM → base64 blob |
| `Sources/Enthea/EntheaControlBridge.swift` | Swift commands → `window.winampEnthea.*` |
| `Sources/Enthea/EntheaTrackAnalyzer.swift` | **Native** offline drop/section analysis (Task 6) |
| `Sources/Enthea/EntheaTrackBridge.swift` | Timeline + playhead → `S.timeline` / `AUDIO.fileEl` shim (Task 6) |
| `Sources/Enthea/EntheaPreferences.swift` | Persisted mode, autopilot, disclaimer, kill-switch flags |
| `Sources/Views/Classic/ClassicMilkdropPanelView.swift` | Body switch Metal\|Enthea → Enthea-default; strip controls |
| `Sources/Views/Classic/ClassicVisualizerPanelView.swift` | Rename target after Task 5 |
| `Sources/Visualization/MetalVisualizationPlugin.swift` | Task 8 ENTHEA-styled mini plugin |
| `Sources/Shaders/VisualizerShaders.metal` | Task 8 mini fragment shader |
| `Sources/WinampPanelWindowManager.swift` | Theater expand/restore helper (Task 5) |
| `Tests/WinampTests/AudioFeatureBusRawBinTests.swift` | Raw-bin channel (Task 0) |
| `Tests/WinampTests/EntheaBundleLoaderTests.swift` | **Resource resolves from `Bundle.main`** |
| `Tests/WinampTests/EntheaAudioPayloadCodecTests.swift` | Blob round-trip |
| `Tests/WinampTests/EntheaAudioBridgeTests.swift` | Gate + coalescing |
| `Tests/WinampTests/EntheaTrackAnalyzerTests.swift` | Native timeline (Task 6) |
| `Tests/WinampTests/EntheaPreferencesTests.swift` | Defaults persistence |

## Locked JS / Swift contracts

```js
// Resources/Enthea/bridge.js — loaded AFTER ENTHEA's script, in the PAGE content world.
// ENTHEA's AUDIO / S / MODES are `const` at classic-script top level: NOT window properties,
// but bare-identifier resolvable from anything evaluated later in the page world.
// setMode / fireDrop / togglePanel / toggleFull / cycleWall ARE window properties.
window.winampAudio = {
  push(blobBase64, sampleRate, isPlaying) {},  // 512 u8 bins + 2048 f32 L + 2048 f32 R
  setTimeline(timeline) {},                    // Task 6 — natively computed
  setPosition(seconds, paused) {},             // Task 6 — drives the AUDIO.fileEl shim
};
window.winampEnthea = {
  setMode(idOrDelta) {},
  setAutopilot(on) {},
  setDose(delta) {},
  hideChrome() {},
  fireDrop() {},
  reseed() {},
  setSubstance(id) {},         // Task 9
  ready: false,
};
```

```swift
// Task 0 — the prerequisite that makes ENTHEA's DSP work at all
extension AudioFeatureBus {
    /// Linear FFT magnitudes, 0...255, `bin[i]` centred at `i * sampleRate / 2 / count`.
    /// Mirrors AnalyserNode.getByteFrequencyData so ENTHEA needs no changes.
    func rawBinSnapshot(at now: Double) -> (bins: [UInt8], sampleRate: Double, isPlaying: Bool)
}

// Task 3 — transport only. There is deliberately no `bands7`, no `bass/mid/treble`.
enum EntheaAudioPayloadCodec {
    static func encode(bins: [UInt8], left: [Float], right: [Float]) -> String  // base64
}

enum EntheaBodyMode: String {  // Task 1–5 migration; hidden kill switch after Task 5
    case metal
    case enthea
}
```

---

### Task −1: WebKit performance spike (Stage −1) — GO/NO-GO GATE

**Throwaway branch. No commits to the working branch. Nothing below starts until this passes.**

WebKit WebGL2 performance is the top risk in the spec, and everything after this task is built on the assumption that it clears. ENTHEA is one ~1000-line GLSL fragment shader with 36 `uMode` branches plus COMPOSE / PRESENT / transform-feedback programs — the cold-compile cost is the specific unknown.

- [ ] **Step 1: Minimal harness**

Throwaway Swift file or a scratch Xcode playground-style target: one `WKWebView` in a plain `NSWindow` sized 600×450, `loadFileURL` on a locally downloaded upstream `index.html`.

- [ ] **Step 2: Measure**

| Metric | Method | Concern threshold |
|---|---|---|
| Cold boot → first painted frame | `Date()` around load + a `postMessage` from ENTHEA's first `frame()` | > 2 s means don't tear down the web view on hide |
| Steady-state FPS, default mode | rAF frame counter injected via `evaluateJavaScript` (the spike runs unpatched upstream, so its keyboard shortcuts still work for switching modes) | < 45 fps sustained |
| Steady-state FPS, heaviest mode (Hyperspace / Fractal / Particle Flow) | same | < 30 fps sustained |
| FPS at DPR 2 vs DPR 1 | force `devicePixelRatio` clamp | informs the Task 2 clamp value |
| CPU / GPU while idle-but-visible | Activity Monitor | sustained high draw is a product problem |

- [ ] **Step 3: Decide and record**

Write findings into the spec's *Upstream facts* / *Risks* tables. Outcomes:

- **Go** — proceed to Task 0.
- **Go with clamps** — proceed, but fix the DPR clamp and FPS cap values now and carry them into Task 2.
- **No-go** — stop. Reopen the spec; Stage 10's Metal port becomes the primary path rather than the optional one.

- [ ] **Step 4: Delete the spike branch** — nothing from it ships.

---

### Task 0: Raw linear FFT bin channel (Stage 0)

**Files:**
- Modify: `Sources/Audio/FFTSpectrumAnalyzer.swift`
- Modify: `Sources/Audio/AudioFeatureBus.swift`
- Test: `Tests/WinampTests/AudioFeatureBusRawBinTests.swift`

**Produces:** 512 linear magnitudes per FFT hop, published alongside the existing 32 log bands. Pure Swift, no WebKit, independently useful — this task is worth keeping even if ENTHEA is later abandoned.

**Why:** `AudioFeatures.spectrum` is 32 **log**-spaced bands (60 Hz → Nyquist, normalized across −60/+18 dB). ENTHEA's `band(f0, f1)` indexes bins **linearly** and its spectral flux differences adjacent bins. Feeding it upsampled log bands yields a stair-stepped spectrum whose flux is ~zero except at step boundaries: onset detection, BPM, and reactive drops all fail *silently* while the visuals still appear to move. `FFTSpectrumAnalyzer` already computes `self.magnitudes` (512 bins from the 1024-point FFT) and discards it.

- [ ] **Step 1: Failing tests**

```swift
func testRawBinSnapshotHasLinearBinCount() {
    // 512 bins for fftSize 1024
}

func testRawBinSnapshotIsLinearlySpaced() {
    // Feed a synthesized 1 kHz sine at a known sample rate; assert the peak bin index
    // is within ±1 of round(1000 / (sampleRate / 2 / 512)).
    // This is the test that catches an accidental log mapping.
}

func testRawBinSnapshotReportsSampleRate() {
    // ENTHEA computes binHz = sampleRate * 0.5 / d.length — a wrong rate silently
    // misplaces every band edge.
}

func testExistingThirtyTwoBandSpectrumUnchanged() {
    // Regression guard: the Metal mini viz must see exactly what it saw before.
}
```

- [ ] **Step 2: Implement**

Add an `onRawBins` path from `FFTSpectrumAnalyzer` into a lock-protected slot on `AudioFeatureBus`, matching the existing `publishSpectrumFrames` concurrency pattern (`NSLock`, `@unchecked Sendable`). Quantize to `UInt8` with the same dB window the byte-frequency data of a real `AnalyserNode` uses, and carry the real `sampleRate`.

Do **not** apply `VisualizationFeatureSmoother` — ENTHEA does its own `approachTau` smoothing and double-smoothing mushes onset detection.

- [ ] **Step 3: Verify**

```bash
./scripts/run-tests.sh
```

Expected: new tests pass, all existing visualization tests still pass, mini viz visually unchanged.

- [ ] **Step 4: Commit** (only if user asks)

```bash
git commit -m "feat: publish raw linear FFT bins on AudioFeatureBus"
```

---

### Task 1: WKWebView host shell in Visualizer panel (Stage 1)

**Files:**
- Create: `Sources/Enthea/EntheaWebView.swift`
- Create: `Sources/Enthea/EntheaBundleLoader.swift` (stub returning placeholder HTML OK)
- Modify: `Sources/Views/Classic/ClassicMilkdropPanelView.swift`
- Modify: `Winamp.xcodeproj/project.pbxproj` (add Swift files to Winamp target; link `WebKit.framework` if not automatic)

**Interfaces:**
- Produces: `struct EntheaWebView: NSViewRepresentable` with `var isActive: Bool`, `var size: CGSize`
- Produces: `final class EntheaWKHostView: NSView` — mirrors `MilkdropMTKHostView`: pin `WKWebView` to bounds on `layout`
- Produces: panel `@State private var bodyMode: EntheaBodyMode = .metal` — **`.metal`, not `.enthea`**. Shipping a green "ENTHEA host" placeholder where the visualizer used to be would violate the "every stage leaves the app usable" invariant. Flip the default in Task 3.
- Consumes: existing `GeometryReader` body slot in `ClassicMilkdropPanelView`

- [ ] **Step 1: Implement fill-bounds host**

```swift
import AppKit
import SwiftUI
import WebKit

final class EntheaWKHostView: NSView {
    let webView: WKWebView

    override init(frame frameRect: NSRect) {
        // A configuration is required for WKUserScript injection and message handlers
        // in later tasks. nonPersistent(): ENTHEA's localStorage writes (scene snapshots,
        // MIDI map) are all try/catch-guarded, so discarding them is harmless.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.webView.underPageBackgroundColor = .black
        self.addSubview(self.webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        self.webView.frame = self.bounds
    }

    func loadPlaceholder() {
        let html = "<!doctype html><meta charset=utf-8><body style='margin:0;background:#000;color:#0f0;font:12px monospace'>ENTHEA host</body>"
        self.webView.loadHTMLString(html, baseURL: nil)
    }

    /// Blanking the page does NOT stop the WebContent process — only releasing the
    /// WKWebView does. `WinampPanelWindowManager.hidePanel` nils `contentViewController`
    /// for `.visualizer`, which deallocates this view; this just stops work in the
    /// window between that and dealloc.
    func teardown() {
        self.webView.stopLoading()
        self.webView.load(URLRequest(url: URL(string: "about:blank")!))
    }
}

struct EntheaWebView: NSViewRepresentable {
    var isActive: Bool
    var size: CGSize

    func makeNSView(context: Context) -> EntheaWKHostView {
        let host = EntheaWKHostView(frame: CGRect(origin: .zero, size: self.size))
        if self.isActive { host.loadPlaceholder() }
        return host
    }

    func updateNSView(_ host: EntheaWKHostView, context: Context) {
        host.frame.size = self.size
        if self.isActive {
            if host.webView.url == nil { host.loadPlaceholder() }
        } else {
            host.teardown()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: EntheaWKHostView, context _: Context) -> CGSize? {
        self.size
    }
}
```

> **Do not** use `setValue(false, forKey: "drawsBackground")`. It is private KVC on a documented-readonly surface; `underPageBackgroundColor` is the supported API.

- [ ] **Step 2: Wire panel body switch**

In `ClassicMilkdropPanelView`, add strip control **Metal | Enthea** (defaulting to Metal) and:

```swift
GeometryReader { geo in
    Group {
        if bodyMode == .enthea {
            EntheaWebView(isActive: showVisualizer && !isMinimized, size: geo.size)
        } else {
            MilkdropMetalVisualizationView(preset: currentPreset, size: geo.size)
                .opacity(fadeOpacity)
        }
    }
    .frame(width: geo.size.width, height: geo.size.height)
}
```

When `isMinimized` or `showVisualizer` becomes false, ensure `isActive == false` so `teardown()` runs.

- [ ] **Step 3: Build**

```bash
./build.sh
```

Expected: success. Manual: Show Visualizer → Metal MilkDrop as before; switch to Enthea → black host with green “ENTHEA host”; Hide → WebContent process exits (Activity Monitor spot-check).

- [ ] **Step 4: Commit** (if asked)

```bash
git commit -m "feat: add WKWebView host shell in visualizer panel"
```

---

### Task 2: Vendor ENTHEA + boot with chrome hidden and keyboard dead (Stage 2)

**Files:**
- Create: `Resources/Enthea/index.html` (copy from upstream, pinned)
- Create: `Resources/Enthea/LICENSE` (ENTHEA's own AGPL-3.0 text)
- Create: `Resources/Enthea/bridge.js`
- Create: `Resources/Enthea/VENDOR.md`
- Modify: `Sources/Enthea/EntheaBundleLoader.swift`
- Modify: `Sources/Enthea/EntheaWebView.swift`
- Modify: `Winamp.xcodeproj/project.pbxproj` — **folder reference** for `Resources/Enthea`
- Create: `Sources/Enthea/EntheaPreferences.swift`
- Test: `Tests/WinampTests/EntheaBundleLoaderTests.swift`
- Test: `Tests/WinampTests/EntheaPreferencesTests.swift`

- [ ] **Step 1: Vendor source + its license**

```bash
mkdir -p Resources/Enthea
BASE=https://raw.githubusercontent.com/elder-plinius/ENTHEA/f8eaf39d36178a0097cb6219c67ec1920d2ed7e6
curl -fsSL -o Resources/Enthea/index.html "$BASE/index.html"
curl -fsSL -o Resources/Enthea/LICENSE   "$BASE/LICENSE"
shasum -a 256 Resources/Enthea/index.html
```

The root `LICENSE` is **not** touched. Root MIT covers this repo's code; the vendored subdirectory carries its own AGPL terms. That is accurate today and is standard vendoring hygiene.

- [ ] **Step 2: Write `VENDOR.md` — including the relicense trigger**

Repo URL, commit SHA `f8eaf39d36178a0097cb6219c67ec1920d2ed7e6`, file checksum, date, the running list of local patches, and this note verbatim so future-you cannot miss it:

```markdown
## License

This directory is ENTHEA, © Pliny / elder-plinius, licensed AGPL-3.0. See `LICENSE`
in this directory.

This repository is **private and undistributed**, so no AGPL obligation is currently
active: §5/§6 attach to conveying a copy, §13 to network interaction with a modified
version, and §2 permits private modification unconditionally.

**Trigger:** publishing this repository, or sharing a build with anyone, makes the
combined work AGPL-3.0. At that point replace the root `LICENSE` with AGPL-3.0 and add
a `NOTICE` crediting the MIT upstream (mbrukman/winamp-macos). Note also that AGPL and
Mac App Store distribution are incompatible.
```

- [ ] **Step 2: Bundle as a FOLDER REFERENCE — not individual files**

`project.pbxproj` uses a `PBXFileSystemSynchronizedRootGroup` for `Sources/` but *individual file references* for every resource today (`startup.mp3`, the two `.ttf`s). Adding `index.html` / `bridge.js` that way flattens them into `Contents/Resources/`, the `Enthea/` subdirectory never exists, and both lookup paths return `nil` — silently, at runtime, as a blank panel. `loadFileURL(_:allowingReadAccessTo:)` needs the real directory regardless.

```swift
enum EntheaBundleLoader {
    static func directoryURL(in bundle: Bundle = .main) -> URL? {
        guard let url = bundle.url(forResource: "Enthea", withExtension: nil),
              (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else { return nil }
        return url
    }

    static func indexHTMLURL(in bundle: Bundle = .main) -> URL? {
        guard let directory = directoryURL(in: bundle) else { return nil }
        let index = directory.appendingPathComponent("index.html")
        return FileManager.default.fileExists(atPath: index.path) ? index : nil
    }
}
```

Note the fallback from the earlier draft is gone on purpose: a nil-returning fallback chain hides exactly the bundling mistake this task is most likely to make.

- [ ] **Step 3: The test that earns its keep**

```swift
func testEntheaDirectoryIsBundledAsADirectory() {
    XCTAssertNotNil(EntheaBundleLoader.directoryURL(in: .main),
                    "Resources/Enthea must be a folder reference in project.pbxproj, not loose files")
}

func testIndexHTMLResolvesFromMainBundle() {
    XCTAssertNotNil(EntheaBundleLoader.indexHTMLURL(in: .main))
}

func testBridgeScriptResolvesFromMainBundle() {
    let bridge = EntheaBundleLoader.directoryURL(in: .main)?.appendingPathComponent("bridge.js")
    XCTAssertEqual(bridge.map { FileManager.default.fileExists(atPath: $0.path) }, true)
}
```

- [ ] **Step 4: `bridge.js` — control surface + keyboard kill**

Loaded **after** ENTHEA's script, in the **page content world**. ENTHEA's `AUDIO` / `S` / `MODES` are `const` at classic-script top level, so they are *not* `window` properties — bare-identifier resolution reaches them from a later page-world script, but an isolated `WKContentWorld` sees nothing and every call silently no-ops. `setMode` / `fireDrop` / `togglePanel` / `toggleFull` / `cycleWall` *are* function declarations and therefore *are* on `window`.

```js
(function () {
  // 1. Kill ENTHEA's keyboard before anything else. Its global keydown handler binds
  //    space with preventDefault() (cycles visual mode) plus a b d f h j k m r t w =
  //    and 1-8. Space is play/pause in this app, and the playlist owns several others.
  //    Capture-phase stopImmediatePropagation beats the listener ENTHEA already added.
  window.addEventListener("keydown", function (e) {
    e.stopImmediatePropagation();
  }, true);

  const api = {
    ready: false,
    hideChrome() { if (typeof setCollapsed === "function") setCollapsed(true); },
    setMode(i) { if (typeof setMode === "function") setMode(i, true); },
    setAutopilot(on) {
      const el = document.getElementById("tgJourney");
      if (el && el.classList.contains("on") !== !!on) el.click();
    },
    setDose(delta) { /* wired in Task 4 */ },
    fireDrop() { if (typeof fireDrop === "function") fireDrop(false); },
    reseed() { if (typeof S === "object") S.reseed = 2; },
    setSubstance(id) { /* wired in Task 9 */ },
  };
  window.winampEnthea = api;
  window.winampAudio = { push() {}, setTimeline() {}, setPosition() {} };
  api.ready = true;
})();
```

Patch `index.html` minimally: `<script src="bridge.js"></script>` **after** the main `</script>` at line 3087. Record every patch in `VENDOR.md`.

- [ ] **Step 5: Load + clamp resolution**

`EntheaWKHostView.loadEnthea()`: `loadFileURL(index, allowingReadAccessTo: directory)`.

ENTHEA caps DPR at 2 internally (`const DPR = Math.min(window.devicePixelRatio || 1, 2)`). A Zoom-scaled 600×450 panel at 2× backing is 1200×900 of raymarching per frame. Inject a clamp override sized from panel dimensions and `uiScale.level`, using the value the Task −1 spike measured.

- [ ] **Step 6: Photosensitive prefs + first-open alert**

```swift
struct EntheaPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private static let warningKey = "entheaPhotosensitiveWarningAccepted"
    private static let autopilotKey = "entheaAutopilot"
    private static let modeKey = "entheaModeID"
    private static let forceMetalBodyKey = "entheaForceMetalBody"  // kill switch, Task 5

    var photosensitiveWarningAccepted: Bool {
        get { self.defaults.bool(forKey: Self.warningKey) }
        nonmutating set { self.defaults.set(newValue, forKey: Self.warningKey) }
    }
    // autopilot / modeID / forceMetalBody follow the same pattern
}
```

Injectable `UserDefaults` from the start — the earlier `enum` + `.standard` design was not testable. On first Enthea body appear: SwiftUI `.alert` with the photosensitive epilepsy warning; on OK set the flag. Do not enable flicker.

```swift
func testPhotosensitiveWarningDefaultsFalse() {
    let suite = UserDefaults(suiteName: #function)!
    suite.removePersistentDomain(forName: #function)
    XCTAssertFalse(EntheaPreferences(defaults: suite).photosensitiveWarningAccepted)
}
```

- [ ] **Step 7: Build + manual smoke**

```bash
./scripts/run-tests.sh && ./build.sh --run
```

Show Visualizer → switch to Enthea → patterns animate (no audio yet). ENTHEA's own HTML UI is hidden. **Press space: the track plays/pauses and the visual mode does not change.** Try the playlist hotkeys with the panel key — all unaffected. Hide panel → WebContent process exits.

- [ ] **Step 8: Commit** (if asked)

```bash
git commit -m "feat: vendor ENTHEA and boot inside visualizer WebView"
```

---

### Task 3: Fake-analyser audio shim (Stage 3)

**Files:**
- Create: `Sources/Enthea/EntheaAudioPayloadCodec.swift`
- Create: `Sources/Enthea/EntheaAudioBridge.swift`
- Modify: `Resources/Enthea/bridge.js` — install the fake analyser
- Modify: `Sources/Enthea/EntheaWebView.swift` (own the bridge; start/stop with `isActive`)
- Modify: `ClassicMilkdropPanelView.swift` — flip `bodyMode` default to `.enthea`
- Test: `Tests/WinampTests/EntheaAudioPayloadCodecTests.swift`
- Test: `Tests/WinampTests/EntheaAudioBridgeTests.swift`

**The whole design in one paragraph:** ENTHEA's `updateAudio(dt)` early-returns unless `S.audio.on && AUDIO.analyser`, then reads exactly two things — `AUDIO.analyser.getByteFrequencyData(AUDIO.data)` and `getFloatTimeDomainData(AUDIO.wave)` (plus `AUDIO.anL`/`anR` for stereo). Everything else it computes itself. So `bridge.js` replaces `AUDIO.analyser` with a plain object whose two methods `.set()` from buffers Swift refreshes, stubs `AUDIO.ctx` as `{ sampleRate }`, and sets `S.audio.on = true`. ENTHEA's DSP is not modified at all.

- [ ] **Step 1: Install the shim in `bridge.js`**

```js
const BINS = 512, WAVE = 2048;
const bins = new Uint8Array(BINS);
const waveL = new Float32Array(WAVE), waveR = new Float32Array(WAVE);
const waveMono = new Float32Array(WAVE);

function installFakeAnalyser(sampleRate) {
  AUDIO.ctx = AUDIO.ctx || { sampleRate: sampleRate, currentTime: 0 };
  const mk = (src) => ({
    fftSize: WAVE, frequencyBinCount: BINS, smoothingTimeConstant: 0,
    getByteFrequencyData(out) { out.set(bins.subarray(0, out.length)); },
    getFloatTimeDomainData(out) { out.set(src.subarray(0, out.length)); },
  });
  AUDIO.analyser = mk(waveMono);
  AUDIO.anL = mk(waveL);
  AUDIO.anR = mk(waveR);
  AUDIO.data = new Uint8Array(BINS);
  AUDIO.wave = new Float32Array(WAVE);
  AUDIO.waveL = new Float32Array(WAVE);
  AUDIO.waveR = new Float32Array(WAVE);
  S.audio.on = true;
  S.audio.source = "winamp";   // must not be 'system' — that arms the DRM-silence watchdog
}
```

`updateAudio` derives `binHz` from `AUDIO.ctx.sampleRate` and is generic over `d.length`, so 512 bins works unmodified — but the sample rate must be truthful or every band edge lands in the wrong place.

- [ ] **Step 2: Codec tests, then the codec**

```swift
func testEncodedBlobRoundTripsBinsAndWaveforms() {
    // 512 bins + 2048 L + 2048 R survive base64 with byte-exact bins and
    // float32 waveforms within tolerance. JSON would be ~50 KB/frame.
}

func testEncodedBlobLayoutIsStable() {
    // bins first, then L, then R — bridge.js decodes by fixed offsets.
}
```

- [ ] **Step 3: Bridge with gating AND coalescing**

`evaluateJavaScript` is an async IPC round trip. A naive 60 Hz timer queues unboundedly if the web process stalls, and the queue never drains. Both properties need tests:

```swift
func testBridgeDoesNotEvaluateWhenInactive() {
    let evaluator = SpyJavaScriptEvaluator()
    let bridge = EntheaAudioBridge(featureBus: .shared, evaluator: evaluator)
    bridge.isActive = false
    bridge.tick()
    XCTAssertEqual(evaluator.callCount, 0)
}

func testBridgeSkipsPushWhileAPreviousEvaluationIsInFlight() {
    let evaluator = SpyJavaScriptEvaluator()  // does not invoke completion
    let bridge = EntheaAudioBridge(featureBus: .shared, evaluator: evaluator)
    bridge.isActive = true
    bridge.tick(); bridge.tick(); bridge.tick()
    XCTAssertEqual(evaluator.callCount, 1, "pushes must coalesce, not queue")
}
```

Use a protocol `EntheaJavaScriptEvaluating` so the spy substitutes cleanly. Push **raw, unsmoothed** values — no `VisualizationFeatureSmoother`; ENTHEA's own `approachTau` smoothing does that job and double-smoothing mushes onset detection.

Also gate on `isMinimized` and window occlusion, not just `showVisualizer`.

- [ ] **Step 4: Flip the default body to `.enthea`**

This is the stage where ENTHEA becomes what you see by default. The Metal|Enthea switch stays visible for one more task.

- [ ] **Step 5: Manual — verify beat lock, not just motion**

The failure mode this task is guarding against looks fine at a glance: wrong bins still produce moving visuals, they just never lock to the beat. So verify against ground truth:

- Play a **known-BPM track or click track** and read `S.audio.bpm` back via `evaluateJavaScript` (ENTHEA's own `=` HUD is unreachable now that the keyboard is neutered). It should converge to the real tempo within a few seconds.
- Confirm the beat pulse lands on the kick, not near it.
- Confirm a track with an obvious drop triggers the reactive arsenal.
- Mute the player → motion calms. No second audio stream from the WebView.

- [ ] **Step 6: `./scripts/run-tests.sh` + commit if asked**

```bash
git commit -m "feat: drive ENTHEA's DSP from a fake AnalyserNode shim"
```

---

### Task 4: Classic control strip (Stage 4)

**Files:**
- Modify: `ClassicMilkdropPanelView.swift` (strip: prev/next mode, autopilot, dose, reseed; keep Metal|Enthea)
- Create: `Sources/Enthea/EntheaControlBridge.swift`
- Modify: `EntheaPreferences.swift` (mode + autopilot persistence)
- Modify: `bridge.js` (`setDose`, and finish anything stubbed in Task 2)

**Interfaces:**
- Produces: `EntheaControlBridge` methods matching `window.winampEnthea`
- Strip labels: `ENTHEA • <mode or AUTOPILOT>` instead of MilkDrop preset name when `bodyMode == .enthea`

- [ ] Wire ◀/▶ → `setMode(-1/+1)`; center click or button → toggle autopilot; optional small controls for dose/reseed
- [ ] Poll or await `winampEnthea.ready` before issuing restore commands — commands sent before `bridge.js` runs are silently dropped
- [ ] On appear: restore persisted autopilot/mode
- [ ] Manual: controls work with ENTHEA's HTML UI still hidden; mode survives a panel hide/show cycle
- [ ] Commit if asked: `feat: add Classic ENTHEA control strip`

---

### Task 5: Theater + retire the Metal panel body (Stage 5)

**Files:**
- Modify: `ClassicMilkdropPanelView.swift` → rename to `ClassicVisualizerPanelView.swift` (update all refs + window manager `makeRoot`)
- Modify: `WinampPanelWindowManager.swift` — theater expand/restore helper
- Modify: `EntheaPreferences.swift` — `forceMetalBody` kill switch
- Modify: `USAGE.md:150` — the fullscreen claim becomes true (or gets corrected)

**Theater — `toggleFullScreen` will not work here.** `WinampWindowConfigurator.apply(to:resizable:)` builds panels as `[.borderless, .miniaturizable]` with `collectionBehavior = []`; native fullscreen needs at least `.fullScreenPrimary`, and borderless plus native fullscreen is unreliable even then. There is no `toggleFullScreen` call anywhere in `Sources/` today.

- [ ] Implement theater as: expand the panel window frame to `screen.visibleFrame`, hide Classic chrome, optionally set `NSApp.presentationOptions` to hide the menu bar; restore size/position from `WinampPanelLayoutState` on exit
- [ ] Do not route through ENTHEA's `toggleFull()` / `requestFullscreen` — the page should not own the window
- [ ] Remove the visible Metal|Enthea segment; body is `EntheaWebView` unless `forceMetalBody` is set

**What this task does NOT delete.** `FullscreenMetalPlugin` is covered by `MetalVisualizationSmokeTests.testAllFullscreenPresetsRender`, shares `MetalVisualizationEngine` with the mini viz, and backs 11 `VisualizationPreset` cases plus a `fullscreenFragment` branch in `VisualizerShaders.metal`. All of it **stays** — the kill switch depends on it and it is cheap to leave compiled. Deleting it is a separate decision after Task 7.

- [ ] Manual: docked ENTHEA → theater → exit restores size/position; kill-switch flag restores the Metal body; mini LCD still Metal; EQ/playlist pack unchanged
- [ ] `./scripts/run-tests.sh` + `./scripts/shoot.sh`
- [ ] Commit if asked: `feat: ENTHEA visualizer panel with theater mode`

---

### Task 6: Predictive drops via native track analysis (Stage 6)

**Files:**
- Create: `Sources/Enthea/EntheaTrackAnalyzer.swift` — offline analysis in Swift
- Create: `Sources/Enthea/EntheaTrackBridge.swift`
- Modify: `bridge.js` (`setTimeline`, `setPosition`, `AUDIO.fileEl` shim)
- Test: `Tests/WinampTests/EntheaTrackAnalyzerTests.swift`

**Do the analysis natively — do not hand the file to WebKit.** The original approach (copy the track into `caches/`, let ENTHEA `decodeAudioData` it) has three problems: copying lossless files per track change is expensive for a player whose stated goal is lossless support; WebKit's `decodeAudioData` coverage for FLAC/ALAC/DSD is not something to put on the critical path; and it re-decodes audio the app has already decoded.

`analyzeTrack()` merely returns a plain object assigned to `S.timeline`, and `updateTimeline()` reads only `S.timeline` plus `AUDIO.fileEl.currentTime` / `.paused`. Both are trivially producible from Swift.

**Interfaces:**
- `EntheaTrackAnalyzer.analyze(url:) async -> EntheaTimeline` — `AVAudioFile` + vDSP, mirroring upstream's onset/section heuristic; returns `{dur, drops[], sections[]}`
- `EntheaTrackBridge` assigns the timeline via `winampAudio.setTimeline(...)` on track change and drives `setPosition(seconds:paused:)` at ~4–10 Hz while playing
- `bridge.js` shims `AUDIO.fileEl = { currentTime, paused }` and forces `S.audio.source === 'file'` so `useTL` evaluates true
- Strip “Drop” → `fireDrop()`

- [ ] Unit-test the analyzer against a generated fixture with drops at known timestamps (`scripts/generate-fixtures.sh` already has the `uv` harness for synthesizing audio)
- [ ] Manual: EDM-style track with a clear drop → arsenal fires on time; seeking backward rewinds the timeline pointers; track change reanalyzes
- [ ] Confirm analysis runs off the main actor and does not stall playback on a long file
- [ ] Commit if asked: `feat: natively computed predictive drop timeline for ENTHEA`

---

### Task 7: Polish (Stage 7)

**Files:**
- Album art → Image Warp: pass cover image data to the bridge if `Track` / metadata exposes artwork
- Cap push rate when docked small (e.g. max 30 FPS); pause when minimized or the app is occluded
- Update `USAGE.md`: Show/Hide Visualizer, theater, strip controls, photosensitive note
- Remove the `forceMetalBody` kill switch once this ships and the WebKit path has been lived with

- [ ] Manual + shoot
- [ ] Decide (and record) whether `FullscreenMetalPlugin` / `VisualizationPreset` / the `fullscreenFragment` branch / its smoke test get deleted now that the kill switch is gone
- [ ] Commit if asked: `feat: polish ENTHEA visualizer (art warp, caps, docs)`

---

### Task 8: ENTHEA-styled Metal mini viz (Stage 8)

**Files:**
- Modify: `Sources/Visualization/MetalVisualizationPlugin.swift` — new mini plugin kind
- Modify: `Sources/Shaders/VisualizerShaders.metal` — port one cheap ENTHEA mode's GLSL to MSL
- Modify: `Sources/SpectrumView.swift` — add the mode to the tap cycle
- Test: extend `MetalVisualizationSmokeTests`

**No WebKit in this task.** Both web routes were considered and rejected in the spec: `WKWebView.takeSnapshot` forces a full render pass plus image encode per frame to fill a 76×16 slot and only works while the panel is open (so Metal has to exist as a fallback anyway), and a second resident `WKWebView` in the main window is an explicit non-goal. Porting one cheap mode to Metal costs less than either and has no runtime overhead.

**Constraints:**
- Double-tap still toggles `showVisualizer`
- Single-tap still cycles `visualizationMode` (`@AppStorage`); the new mode joins the cycle rather than replacing bars/oscilloscope/analyzer
- Classic 76×16 geometry unchanged

- [ ] Pick the cheapest visually-distinct ENTHEA mode (Waveform / Cellular / Breathing Walls are candidates); port its GLSL, not the uber-shader
- [ ] Drive it from the existing `AudioFeatureBus` snapshot the mini renderer already reads
- [ ] Smoke test renders headlessly like the other plugins
- [ ] Manual: mode cycles, double-tap opens the panel, no extra process
- [ ] Commit if asked: `feat: add ENTHEA-styled Metal mini visualizer mode`

---

### Task 9: Substance / phenomenology UI (Stage 9)

**Files:**
- Modify: Classic strip or options menu — “Looks…” submenu listing ENTHEA substance presets by name
- Modify: `bridge.js` `setSubstance(id)` — wire to the `SUBSTANCES` table (`const` at top level, bare-resolvable from the page world)
- Modify: `USAGE.md` + in-app disclaimer string

**Copy rules (mandatory):**
- Label as **artistic / phenomenological looks**, not “drugs” as medical guidance
- One-line disclaimer near menu / first use: not dosing advice, not medical advice; simulator only
- Keep the photosensitive warning from Task 2

- [ ] Wire menu → `setSubstance`
- [ ] UI review: no medical claims
- [ ] Commit if asked: `feat: add ENTHEA phenomenology look presets with disclaimers`

---

### Task 10: Optional further Metal port (Stage 10) — SKIP unless requested

**Files (only if pursued):**
- `Sources/Shaders/VisualizerShaders.metal`
- New Metal plugins per mode, reusing the porting pattern established in Task 8

**Exit criteria:** User explicitly asks to continue the Metal port after the WebKit path is satisfactory. Note that a no-go on Task −1 promotes this from optional to primary.

- [ ] Do not start in the default execution of this plan

---

## Verification matrix

| After task | Command / check |
|---|---|
| −1 | Spike numbers recorded in the spec; explicit go/no-go |
| 0 | `./scripts/run-tests.sh`; 1 kHz sine lands in the expected linear bin; mini viz unchanged |
| 1 | `./build.sh`; Metal still default; placeholder WebView on switch; process exits on hide |
| 2 | Bundle-resolution tests pass; ENTHEA paints; UI hidden; **space still plays/pauses**; warning once; `Resources/Enthea/` has `LICENSE` + `VENDOR.md`; root `LICENSE` untouched |
| 3 | `./scripts/run-tests.sh`; coalescing test passes; **BPM HUD matches a click track** |
| 4 | Strip controls work; mode survives hide/show |
| 5 | Theater expands and restores; kill switch works; mini still Metal; dock pack OK |
| 6 | Analyzer fixture test passes; drops land on time; seek rewinds |
| 7 | USAGE updated; caps work; kill switch retired |
| 8 | Metal smoke test passes; mode in tap cycle; no second process |
| 9 | Looks menu + disclaimer |
| 10 | Optional only |

## Spec coverage checklist

| Spec item | Task |
|---|---|
| WebKit spike gate | −1 |
| Raw linear FFT bin channel | 0 |
| WKWebView host + teardown | 1 |
| Vendor + folder reference + vendored `LICENSE`/`VENDOR.md` + boot + hide chrome + keyboard kill + DPR clamp + warning | 2 |
| Fake-analyser shim + coalesced push | 3 |
| Classic controls + persist | 4 |
| `visibleFrame` theater + Enthea-default body + kill switch | 5 |
| Native predictive drop timeline | 6 |
| Polish / art / USAGE / retire kill switch | 7 |
| ENTHEA-styled Metal mini viz | 8 |
| Substance UI + disclaimers | 9 |
| Optional further Metal port | 10 |
| No 4th panel / no EQ-PL dock changes | Global constraints |
| No 32→7 band mapper | Global constraints |
| Mini LCD stays Metal permanently | Global constraints, Task 8 |

## Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-02-enthea-visualizer.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — execute tasks in this session with checkpoints

Which approach? **Start at Task −1** — it is a gate, and everything after it assumes WebKit performance clears. Task 0 is worth doing regardless of the gate's outcome, since raw FFT bins are useful to any future visualizer.
