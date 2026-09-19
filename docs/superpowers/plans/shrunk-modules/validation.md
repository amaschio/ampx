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

The geometry, transport faces, separate control hit cells, branding placement, timer spacing, and square Expand glyph were inspected against the overlay. The running-host capture is now available; final visual approval remains pending.

## Running Player checkpoint

[Live compact Player](player/player-live-host.png) was captured by window ID with `./scripts/shoot.sh --capture-only --output-prefix /tmp/ampx_compact_player`. It is 980 × 60 pixels at 2×: shared boundaries round the 30.24246877 pt logical height to 30 pt on this host. It uses the user's original **Waterfall / Amber** selection and a live `00:04` clock. This is separate from the frozen dotSpectrum/classic comparison.

[Expanded baseline](player/expanded-live-baseline.png) was captured after launching this worktree's build before collapsing Player. The old expanded source mockup remains unavailable.

Build environment: Debug, arm64, macOS 26.6.2, based on `98c15a1` with the host-integration changes in the commit containing this note. Exact command output and red/green runs are recorded in this plan's local execution ledger.

Verified in the app: collapse/expand, shared timer toggle, compact style change reflected in expanded Player, Stop/Play invocation, accessible chrome and transport controls, minimize, and restoration through Window → AmpX. Restored Waterfall/Amber and elapsed mode after inspecting temporary style/timer changes. The actual-window regression waits for AppKit's minimize/deminiaturize notifications before checking state.

**Review requested:** approve or correct the Player's compact proportions/material treatment before implementing compact EQ and Playlist, per the spec's visual checkpoint. The existing skin bevel is heavier than the source; the shared production visualizer intentionally differs from the pictured legacy spectrum.

## Verification so far

- Baseline: 676 tests passed before Player behavior changed.
- Shared state/actions: 34 focused state, binding, settings-wiring, and expanded-reference tests passed.
- Compact display: 49 focused tests passed, including every style/palette at 1×/2×/3×.
- Compact shell: 28 focused tests passed; wordmark adjustment subsequently passed the deterministic capture test.
- Existing expanded reference tests remain green.
- Host integration full suite: **700 tests passed**.
- Final accessibility, compact controls, cancellation, host/visibility/keyboard, and reference checks: **34 tests passed**.
- Additional actual-window minimize/close/reopen regression: **1 test passed**, using animation-completion notifications.
