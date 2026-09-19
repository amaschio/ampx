# Compact module validation

Player checkpoint status: **pending user review**. EQ and Playlist compact bodies are not implemented yet.

Reference: `screenshots/shrinked_modules.png`, SHA-256 `d792a98ad96ae4d0792251256a644081c1f3fa08b4a5970e7d796e4f78781aed`.
Source rectangles, colors, normalization, and uncertainty are recorded in [measurements](reference/measurements.json).
Player/EQ source crops are 1361 × 84 px; Playlist is 1361 × 76 px.
Uniform normalization to 490 pt yields heights 30.24246877 / 30.24246877 / 27.36223365 pt.

## Deterministic Player

[Comparison and overlay](player/player-comparison.png), [native 1×](player/compact-player-1x.png), [2×](player/compact-player-2x.png), [3×](player/compact-player-3x.png).

These captures combine actual AppKit chrome/digits with the production Metal offscreen renderer at the visualizer's measured rectangle. BGRA texture data is composed through a color-managed Core Graphics context, with top-origin texture scanlines mapped into bottom-origin drawing coordinates. Capture choices never write user defaults. A regression test verifies actual green signal pixels in the resulting PNG, in addition to deterministic bytes.

The selected comparison style is **dotSpectrum / classic**. Its 32 columns, dark grid, and palette gradient differ from the old mockup as allowed by the confirmed choice to share the expanded Player's settings. The frozen signal is not the mockup's audio data. The app uses the existing skin's bevel material, whose edge bands are heavier than the source at this small size. Brand and timer are vector/font drawing, not extracted bitmaps.

The geometry, transport faces, separate control hit cells, branding placement, timer spacing, and square Expand glyph were inspected against the overlay. Final visual approval remains pending a running-host capture.

## Verification so far

- Baseline: 676 tests passed before Player behavior changed.
- Shared state/actions: 34 focused state, binding, settings-wiring, and expanded-reference tests passed.
- Compact display: 49 focused tests passed, including every style/palette at 1×/2×/3×.
- Compact shell: 28 focused tests passed; wordmark adjustment subsequently passed the deterministic capture test.
- Existing expanded reference tests remain green.
