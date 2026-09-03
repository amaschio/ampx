# Classic Spectrum Signal Path & dB Mapping

**Date:** 2026-09-03  
**Status:** Implemented  
**Related:** [VISUALIZER_PERFORMANCE.md](../../VISUALIZER_PERFORMANCE.md), ENTHEA raw-bin path in [2026-08-02-enthea-visualizer-design.md](./2026-08-02-enthea-visualizer-design.md)

## Goal

Make the Classic mini spectrum (and the shared analysis tap) show a **real post-EQ spectrum with usable dynamic range**: independent of the main volume fader, honest about EQ preamp and band boosts, calibrated to digital full scale so hot masters plus a smile curve do not paint a solid red wall at normal listening levels.

## Non-goals

- Wiring or redesigning `SpectrumAutoLeveler` for Classic display (stays unused)
- Changing ENTHEA’s `quantizedByte` window (−100…−30 dB)
- Changing MilkDrop / ENTHEA panel chrome, docking, or shaders
- Limiting or auto-compensating EQ preamp for listening (AUTO preamp policy unchanged)
- A second analysis tap or a parallel “dry file” spectrum path

## Decisions (locked)

| Topic | Choice |
|---|---|
| What the analyzer represents | **Post-EQ including preamp**, **pre–volume-fader** (Classic Winamp-like) |
| ReplayGain | Stays on the **player node**, before EQ and before the tap |
| Volume fader | Moves to **`mainMixer.outputVolume`** (taper only), after the tap |
| Classic bar dB window | **−72 dBFS … 0 dBFS** → height 0…1, after 0 dBFS reference |
| Band energy | **Peak** of squared-magnitude bins in the band (no second square, no peak+RMS blend) |
| Auto-range | **Off** — hot preamp may clip the top of bars |
| Shared consumers | Oscilloscope PCM and ENTHEA raw bins use the **same** new tap point |

## Problem (root cause)

Today the FFT taps `mainMixerNode` after:

1. `playerNode.volume` = `VolumeModel.appliedGain` (fader taper × ReplayGain), and  
2. EQ preamp + 10 bands.

A maxed fader plus a high preamp and treble boost drives many bands into the Classic display ceiling. Separately, Classic `normalizedMagnitude` does **not** divide by the window reference ENTHEA already uses, and band energy double-squares `vDSP_zvmags` output, so the wall appears even earlier than an honest 0 dBFS map would require.

macOS also pins **`mainMixerNode` taps** to ~100 ms buffers; moving the tap off the mixer is desirable for analysis cadence (hop publishing already mitigates this; a non-mixer tap is still the right long-term point).

## Architecture

### Signal graph

```
AVAudioPlayerNode.volume     = ReplayGain linear gain, or 1.0 if normalization off
        ↓
EQ preamp (AVAudioMixerNode) = preamp dB → linear (unchanged)
        ↓
AVAudioUnitEQ                = 10 parametric bands (unchanged)
        ↓
analysis tap                 = AudioGraph.tapPoint  ← FFT / scope / ENTHEA bins
        ↓
mainMixer.outputVolume       = VolumeModel.taper(slider position) only
        ↓
hardware output
```

Listening loudness remains `ReplayGain × preamp × EQ × fader`. Only analysis stops seeing the fader.

### `AudioGraph.tapPoint`

- With a non-empty effect chain: **last effect’s `outputNode`** (today: EQ).
- With an empty chain: **`source`** (player).
- Must **not** be `mainMixerNode` while the fader lives on the mixer.

Update `AudioGraphTests` accordingly (today they assert tap === `mainMixerNode`).

### Volume application (`AudioPlayer`)

Split what is today a single `applyPlayerVolume()` write to `playerNode.volume`:

| Control | Node property | Value |
|---|---|---|
| ReplayGain on/off + track tags | `playerNode.volume` | `normalizationLinearGain` or `1.0` (existing RG clamp / peak limit) |
| Main volume slider | `engine.mainMixerNode.outputVolume` | `VolumeModel.taper(position)` in `0…1` |

`VolumeModel.appliedGain` remains valid for tests and any call site that still wants the **combined** listening gain; the live engine path must apply the two factors on the two nodes above so the tap sits between them.

Update `SpectrumAnalyzerDebugProbe` context string from `tap=mainMixer` to something accurate (e.g. `tap=effectChain`).

### FFT → Classic bar height

In `FFTSpectrumAnalyzer.bands(fromWindow:sampleRate:)`:

1. Keep log-spaced band mappings (60 Hz … Nyquist).
2. Per band: `peak = max(magnitudes[start..<end])` where `magnitudes` are `vDSP_zvmags` (power).
3. `normalizedMagnitude`:
   - `guard peak > 0`
   - `dB = 10 * log10(peak / rawBinReferenceMagnitude)`
   - clamp to `[−72, 0]`
   - return `(dB + 72) / 72`

Leave `quantizedByte` (−100…−30, same reference) unchanged for ENTHEA.

Leave `VisualizationFeatureSmoother` attack/release unchanged.

Do **not** call `SpectrumAutoLeveler` from the Metal mini path.

## Error handling & edge cases

| Case | Behavior |
|---|---|
| Volume slider at 0 | Output silent; analyzer and scope still move (tap is upstream) |
| Preamp / bands at +12 dB on a hot master | Boosted bars may sit at 1.0; quieter bands still move — honest clip |
| EQ disabled / flat bypass | Tap still on EQ output node; bit-perfect passthrough policy unchanged |
| No effects in graph | Tap on `source`; mixer still owns the fader |
| Engine / tap not installed | Same as today — no spectrum updates |

## Testing

| Area | Expectations |
|---|---|
| `AudioGraph` | `tapPoint` is last effect output (or source if empty), not `mainMixer` |
| `FFTSpectrumAnalyzer` | Full-scale 440 Hz at unity → peak band near 1.0, neighbors much lower; −20 dB tone clearly lower; silence ~0; relative loud/quiet ordering still holds |
| Volume vs preamp (unit or player harness) | Changing only the fader does not change published band heights; changing preamp does |
| Regression | Existing ENTHEA bridge / raw-bin tests still pass without window changes |

Manual check: play a hot master with volume max and a smile EQ — bars should show bass/mid/treble shape, not a solid ceiling, unless preamp alone drives individual bands into clip.

## Files expected to change

- `Sources/Audio/AudioGraph.swift` — `tapPoint` definition  
- `Sources/AudioPlayer.swift` — split volume / RG application; debug probe context  
- `Sources/Audio/FFTSpectrumAnalyzer.swift` — band energy + Classic dB map  
- `Sources/Audio/VolumeModel.swift` — optional helpers clarifying split gains (only if it keeps call sites clearer)  
- `Tests/WinampTests/AudioGraphTests.swift`  
- `Tests/WinampTests/FFTSpectrumAnalyzerTests.swift`  
- New or extended tests for fader-vs-preamp analysis isolation if a lightweight harness exists; otherwise document the manual check above

## Success criteria

1. Main volume fader does not change Classic bar heights.  
2. EQ preamp and band gains do change them.  
3. Typical playback at 0 dB preamp shows peaks **and** valleys (usable dynamic range).  
4. ENTHEA byte spectrum behavior unchanged aside from seeing pre-fader / post-EQ PCM (same as Classic).  
5. Automated tests above green via `./scripts/run-tests.sh`.
