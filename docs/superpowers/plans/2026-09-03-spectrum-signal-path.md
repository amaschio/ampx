# Classic Spectrum Signal Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the analysis tap to post-EQ / pre-fader and recalibrate Classic bar heights to a −72…0 dBFS map so the mini spectrum shows real dynamic range.

**Architecture:** `AudioGraph.tapPoint` becomes the last effect’s output (not `mainMixer`). ReplayGain stays on `playerNode.volume`; the main fader moves to `mainMixer.outputVolume`. Classic FFT bands use peak power ÷ window reference, mapped −72…0 dB → 0…1. ENTHEA `quantizedByte` stays unchanged.

**Tech Stack:** Swift 6, AVFoundation (`AVAudioEngine`), Accelerate FFT, XCTest via `./scripts/run-tests.sh`

**Spec:** `docs/superpowers/specs/2026-09-03-spectrum-signal-path-design.md`

## Global Constraints

- Analyzer represents **post-EQ including preamp**, **pre–volume-fader**
- ReplayGain remains on the **player node** (before EQ and tap)
- Volume fader applies only via **`mainMixer.outputVolume`** = `VolumeModel.taper(position)`
- Classic bar window: **−72 dBFS … 0 dBFS** after 0 dBFS reference
- Band energy: **peak** of `vDSP_zvmags` slice only (no second square, no peak+RMS blend)
- Do **not** wire `SpectrumAutoLeveler`
- Do **not** change ENTHEA `quantizedByte` (−100…−30)
- No commits unless the user explicitly asks

## File map

| File | Role |
|---|---|
| `Sources/Audio/AudioGraph.swift` | `tapPoint` = last effect output or `source` |
| `Sources/Audio/FFTSpectrumAnalyzer.swift` | Peak band energy + Classic −72…0 dB map |
| `Sources/AudioPlayer.swift` | Split RG vs fader onto player vs mainMixer; debug probe context |
| `Sources/Audio/VolumeModel.swift` | Optional: document split; keep `appliedGain` for combined listening math / tests |
| `Tests/WinampTests/AudioGraphTests.swift` | Assert new `tapPoint` semantics |
| `Tests/WinampTests/FFTSpectrumAnalyzerTests.swift` | Full-scale / attenuated / silence / neighbor isolation |

---

### Task 1: `AudioGraph.tapPoint` is post-effect (pre-mixer)

**Files:**
- Modify: `Sources/Audio/AudioGraph.swift`
- Modify: `Tests/WinampTests/AudioGraphTests.swift`

**Interfaces:**
- Consumes: `AudioGraph.effects`, `AudioGraph.source`, `engine.mainMixerNode`
- Produces: `var tapPoint: AVAudioNode` — last effect’s `outputNode` if `effects` non-empty, else `source`; never `mainMixerNode` while fader lives on mixer

- [ ] **Step 1: Write the failing tests**

Replace `testTapPointIsMainMixer` and add empty-chain + with-effects cases in `Tests/WinampTests/AudioGraphTests.swift`:

```swift
func testTapPointIsSourceWhenEffectChainEmpty() {
    let engine = AVAudioEngine()
    let graph = AudioGraph(engine: engine)
    XCTAssertTrue(graph.effects.isEmpty)
    XCTAssertTrue(graph.tapPoint === graph.source)
    XCTAssertFalse(graph.tapPoint === engine.mainMixerNode)
}

func testTapPointIsLastEffectOutputWhenChainBuilt() {
    let engine = AVAudioEngine()
    let graph = AudioGraph(engine: engine)
    let eq = EQAudioEffect()
    graph.build(effects: [eq])
    XCTAssertTrue(graph.tapPoint === eq.outputNode)
    XCTAssertFalse(graph.tapPoint === engine.mainMixerNode)
}

func testTapPointFollowsLastEffectAfterAppend() {
    let engine = AVAudioEngine()
    let graph = AudioGraph(engine: engine)
    let eq = EQAudioEffect()
    let extra = PassthroughEffect(identifier: "test.passthrough")
    graph.build(effects: [eq])
    graph.append(extra)
    XCTAssertTrue(graph.tapPoint === extra.outputNode)
}
```

Also update `testRemoveAllEffectsConnectsSourceToMainMixer` to assert `graph.tapPoint === graph.source` after removal.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
./scripts/run-tests.sh -only-testing:WinampTests/AudioGraphTests
```

(or full `./scripts/run-tests.sh` if the script has no `-only-testing` passthrough — then filter output for `AudioGraphTests`)

Expected: FAIL — `tapPoint` still equals `mainMixerNode`.

- [ ] **Step 3: Implement `tapPoint`**

In `Sources/Audio/AudioGraph.swift`, replace:

```swift
var tapPoint: AVAudioNode {
    self.engine.mainMixerNode
}
```

with:

```swift
/// Node the analysis tap (FFT / visualizer) reads from — last effect output (post-EQ),
/// or the source when the chain is empty. Intentionally not `mainMixerNode` so the
/// listening fader can live on the mixer without changing analysis.
var tapPoint: AVAudioNode {
    self.effects.last?.outputNode ?? self.source
}
```

Update the file header comment that says “the graph's final mix” if present.

- [ ] **Step 4: Run tests to verify they pass**

Run the same command as Step 2.

Expected: PASS for the new/updated `AudioGraphTests`.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add Sources/Audio/AudioGraph.swift Tests/WinampTests/AudioGraphTests.swift
git commit -m "$(cat <<'EOF'
Move AudioGraph analysis tapPoint to post-effect output.

EOF
)"
```

---

### Task 2: Classic FFT band mapping (−72…0 dBFS, peak only)

**Files:**
- Modify: `Sources/Audio/FFTSpectrumAnalyzer.swift`
- Modify: `Tests/WinampTests/FFTSpectrumAnalyzerTests.swift`

**Interfaces:**
- Consumes: `rawBinReferenceMagnitude`, `magnitudes` from `vDSP_zvmags`
- Produces: Classic band heights in 0…1 via peak power → `10 * log10(peak / ref)` clamped to [−72, 0]
- Unchanged: `quantizedByte` (−100…−30)

- [ ] **Step 1: Write the failing tests**

Add to `Tests/WinampTests/FFTSpectrumAnalyzerTests.swift` (reuse existing `makeBuffer` helpers):

```swift
func testFullScaleSineNearUnityOnPeakBandWithQuietNeighbors() {
    let sampleRate: Double = 44100
    let frequency: Double = 440
    let frameCount = 1024
    let samples = (0 ..< frameCount).map { index in
        Float(sin(2 * .pi * frequency * Double(index) / sampleRate))
    }
    let analyzer = FFTSpectrumAnalyzer(bandCount: AudioFeatures.spectrumBandCount, fftSize: frameCount)
    let bands = analyzer.analyze(self.makeBuffer(samples: samples, sampleRate: sampleRate))

    let peak = bands.max() ?? 0
    let peakIndex = bands.firstIndex(of: peak) ?? -1
    XCTAssertGreaterThan(peak, 0.85, "full-scale tone should sit near the top of the −72…0 window")
    XCTAssertLessThanOrEqual(peak, 1.0)

    // Neighbors must not all brick — real spectrum shape.
    let neighborEnergies = bands.enumerated()
        .filter { abs($0.offset - peakIndex) > 2 }
        .map(\.element)
    let neighborMax = neighborEnergies.max() ?? 1
    XCTAssertLessThan(neighborMax, peak * 0.55)
}

func testAttenuatedSineIsClearlyLowerThanFullScale() {
    let sampleRate: Double = 44100
    let frequency: Double = 440
    let frameCount = 1024
    let full = (0 ..< frameCount).map { index in
        Float(sin(2 * .pi * frequency * Double(index) / sampleRate))
    }
    let quiet = full.map { $0 * pow(10, -20.0 / 20.0) } // −20 dB

    let analyzerLoud = FFTSpectrumAnalyzer(bandCount: AudioFeatures.spectrumBandCount, fftSize: frameCount)
    let analyzerQuiet = FFTSpectrumAnalyzer(bandCount: AudioFeatures.spectrumBandCount, fftSize: frameCount)
    let loudPeak = analyzerLoud.analyze(self.makeBuffer(samples: full, sampleRate: sampleRate)).max() ?? 0
    let quietPeak = analyzerQuiet.analyze(self.makeBuffer(samples: quiet, sampleRate: sampleRate)).max() ?? 0

    // −20 dB is 20/72 ≈ 0.278 of the window below 0 dBFS → expect a clear gap.
    XCTAssertGreaterThan(loudPeak - quietPeak, 0.15)
    XCTAssertLessThan(quietPeak, 0.85)
}

func testSilenceStaysNearZero() {
    let analyzer = FFTSpectrumAnalyzer(bandCount: AudioFeatures.spectrumBandCount, fftSize: 1024)
    let bands = analyzer.analyze(self.makeBuffer(samples: Array(repeating: 0, count: 1024)))
    XCTAssertTrue(bands.allSatisfy { $0 < 0.05 })
}
```

Keep `testWeakerSignalProducesLowerBandsThanStrongerSignal` — it should still pass after the map change.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
./scripts/run-tests.sh
```

Expected: FAIL on neighbor isolation and/or attenuated gap (old map + peak+RMS blend bricks or compresses range).

- [ ] **Step 3: Implement band energy + `normalizedMagnitude`**

In `Sources/Audio/FFTSpectrumAnalyzer.swift`, inside `bands(fromWindow:sampleRate:)`, replace the per-band loop body with peak-only:

```swift
var bands = [Float](repeating: 0, count: bandCount)
for (index, mapping) in self.bandMappings.enumerated() {
    let slice = self.magnitudes[mapping.start ..< mapping.end]
    let peak = slice.max() ?? 0
    bands[index] = self.normalizedMagnitude(peak)
}
```

Replace `normalizedMagnitude`:

```swift
private func normalizedMagnitude(_ magnitude: Float) -> Float {
    guard magnitude > 0 else { return 0 }
    let normalizedPower = magnitude / self.rawBinReferenceMagnitude
    let decibels = 10 * log10(normalizedPower)
    let floor: Float = -72
    let ceiling: Float = 0
    let clamped = min(max(decibels, floor), ceiling)
    return (clamped - floor) / (ceiling - floor)
}
```

Do **not** change `quantizedByte`.

- [ ] **Step 4: Run tests to verify they pass**

Run `./scripts/run-tests.sh`.

Expected: PASS for new FFT tests; existing ENTHEA / quieter-vs-louder tests still green.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add Sources/Audio/FFTSpectrumAnalyzer.swift Tests/WinampTests/FFTSpectrumAnalyzerTests.swift
git commit -m "$(cat <<'EOF'
Calibrate Classic spectrum bars to −72…0 dBFS peak power.

EOF
)"
```

---

### Task 3: Split ReplayGain (player) vs volume fader (main mixer)

**Files:**
- Modify: `Sources/AudioPlayer.swift`
- Modify: `Sources/Audio/VolumeModel.swift` (doc comments only unless a tiny helper clarifies call sites)

**Interfaces:**
- Consumes: `VolumeModel.taper`, `normalizationLinearGain`, `volume` slider
- Produces: `playerNode.volume` = RG (or 1.0); `mainMixer.outputVolume` = taper(slider)
- Produces: debug probe context `tap=effectChain` (not `tap=mainMixer`)

- [ ] **Step 1: Document the split in `VolumeModel`**

Update the top-of-file comment and `appliedGain` docs to state:

- Live engine path applies **two** gains: player = normalization only; mixer = `taper(position)`.
- `appliedGain` remains the **product** (listening equivalent / tests), not what a single node receives.

Optional helper (only if it simplifies `AudioPlayer` without churn):

```swift
/// Linear gain for `AVAudioPlayerNode.volume` when fader lives on the main mixer.
static func playerNormalizationGain(normalizationEnabled: Bool, normalizationGain: Float) -> Float {
    let gain = normalizationEnabled ? normalizationGain : 1
    return max(0, min(self.maxAppliedGain, gain))
}
```

Add a one-line unit test in `VolumeModelTests` if the helper is added.

- [ ] **Step 2: Rewrite volume application in `AudioPlayer`**

Replace `applyPlayerVolume()` so it sets both nodes on `audioQueue`:

```swift
private func applyPlayerVolume() {
    let normalization = self.volumeNormalizationEnabled ? self.normalizationLinearGain : 1.0
    let playerGain = max(0, min(VolumeModel.maxAppliedGain, normalization))
    let mixerGain = VolumeModel.taper(self.volume)
    self.audioQueue.async { [weak self] in
        guard let self else { return }
        self.playerNode?.volume = playerGain
        self.audioEngine?.mainMixerNode.outputVolume = mixerGain
    }
}
```

In `play()`, stop writing combined `VolumeModel.appliedGain` onto `player.volume`. Instead call the same split (inline or via `applyPlayerVolume()` before/after schedule). Ensure `player.pan = balance` remains.

On first `setupAudioEngine` / after graph start, call `applyPlayerVolume()` once so mixer volume is not left at a stale default if the user never moved the slider.

- [ ] **Step 3: Fix debug probe context**

In `installSpectrumTapIfNeeded`, change:

```swift
context: String(format: "preamp=%.1fdB tap=mainMixer", ...)
```

to:

```swift
context: String(format: "preamp=%.1fdB tap=effectChain", ...)
```

Confirm `analyzer.installTap(on: graph.tapPoint)` already uses `tapPoint` (no change needed beyond Task 1).

- [ ] **Step 4: Run tests**

Run:

```bash
./scripts/run-tests.sh
```

Expected: PASS. There is no full AVAudioEngine player harness for fader-vs-preamp isolation; treat the manual check below as the verification for that product rule.

- [ ] **Step 5: Manual verification**

1. Build/run: `./build.sh --run` (or Xcode ⌘R).
2. Play a hot master; set volume to max; set EQ smile + high preamp.
3. Confirm bars show bass/mid/treble **shape**, not a solid ceiling (unless preamp alone clips individual bands).
4. Drag volume to ~0 — output silent, **bars still move**.
5. Move preamp — bars change height.

- [ ] **Step 6: Commit** (only if user asked)

```bash
git add Sources/AudioPlayer.swift Sources/Audio/VolumeModel.swift Tests/WinampTests/VolumeModelTests.swift
git commit -m "$(cat <<'EOF'
Apply volume fader after analysis tap; keep ReplayGain on player.

EOF
)"
```

---

### Task 4: Spec status + final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-03-spectrum-signal-path-design.md` (status → Approved / Implemented)

- [ ] **Step 1: Mark spec status**

Change header `Status: Draft for user review` → `Status: Approved` (or `Implemented` after Task 3 manual check).

- [ ] **Step 2: Full test suite**

```bash
./scripts/run-tests.sh
```

Expected: all green.

- [ ] **Step 3: Commit docs** (only if user asked)

```bash
git add docs/superpowers/specs/2026-09-03-spectrum-signal-path-design.md docs/superpowers/plans/2026-09-03-spectrum-signal-path.md
git commit -m "$(cat <<'EOF'
Document spectrum signal-path redesign and implementation plan.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| `tapPoint` = last effect / source, not mixer | Task 1 |
| Classic −72…0 dB + peak-only bands | Task 2 |
| RG on player; fader on mainMixer | Task 3 |
| Debug probe `tap=effectChain` | Task 3 |
| ENTHEA `quantizedByte` unchanged | Task 2 (explicit non-change) |
| No `SpectrumAutoLeveler` | Global constraint / no task |
| AudioGraph + FFT tests | Tasks 1–2 |
| Manual fader-vs-preamp check | Task 3 Step 5 |
| Success criteria 1–5 | Tasks 1–4 |

## Plan self-review

- No TBD/placeholder steps.
- Types match existing APIs (`AudioGraph.tapPoint`, `VolumeModel.taper`, `FFTSpectrumAnalyzer.analyze`).
- Commit steps gated on user request per repo rules.
