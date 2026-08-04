# Vendored ENTHEA

- **Upstream:** https://github.com/elder-plinius/ENTHEA
- **Pinned commit:** `f8eaf39d36178a0097cb6219c67ec1920d2ed7e6`
- **Vendored:** 2026-08-02
- **`index.html` SHA-256:** `2a28fd8acf1866b87aadcc1ee2eddfd2e15a7dea8586cfec14374b36d0037df5`

## Local patches

1. Append `<script src="bridge.js"></script>` after ENTHEA’s main `</script>` (end of `index.html`) so `bridge.js` runs in the page content world after `AUDIO` / `S` / `MODES` exist.
2. `bridge.js` (this directory): neuters ENTHEA’s `keydown` (capture-phase `stopImmediatePropagation`), exposes `window.winampEnthea` / `window.winampAudio`, hides ENTHEA chrome on boot, overrides `resize()` to honor `window.__winampBackingScale` (2.0 Mpx budget from the host).
3. `bridge.js` Task 3: `winampAudio.push` installs a fake `AnalyserNode` (512 bins + stereo PCM) and sets `S.audio.source = "winamp"` so ENTHEA’s DSP runs on host audio without modifying upstream `updateAudio`.
4. `bridge.js` Task 4: `setMode` is absolute; `stepMode(±1)` is relative (avoids clashing with mode id 1); `setDose(delta)` nudges `S.dose`; `getStatus()` feeds the Classic strip title.

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
