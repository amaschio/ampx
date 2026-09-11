---
description: 
alwaysApply: true
---

# AGENTS.md

## Project Overview

**AmpX** — *Modern audio player. Classic spirit.*

**Goal:** a production-quality, modern macOS music player that preserves the Winamp UX spirit while using best-in-class audio engineering, Metal-accelerated visualizations.

Target users are music collectors and audiophiles who remember Winamp fondly and want that workflow — compact floating window, playlist, EQ, visualizer — but with lossless audio quality, modern codec support, and a native macOS feel.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + AppKit interop where needed |
| Audio engine | AVFoundation / AVAudioEngine |
| DSP / EQ | AVAudioUnitEQ (10-band parametric) |
| Visualizations | Metal |

---

## Module Map & Boundaries

`Sources/` is a single SPM/Xcode module. It documents each area's **responsibility and the rules to respect**:

- **Top-level `Sources/`** — the app shell and primary models/views: `AmpXApp` (`@main` + menus),
  `ContentView` (root view + AppKit window setup), `AudioPlayer` (AVAudioEngine + EQ + media keys),
  `PlaylistManager`, `Track`, and the parsers (`M3UParser`, `TrackMetadataParser`).
- **`Audio/`** — DSP & analysis (FFT, EQ bands, feature bus, ring buffer, auto-leveler, EQF). Pure
  signal/data code.
- **`Playlist/`** — persistence & file I/O (state store, M3U file service). UI talks to this only through `PlaylistManager`, not these types directly.
- **`Views/Classic`** — the Winamp 2.x skin UI (main, shade, playlist, EQ, **MilkDrop panel**) at
  Webamp’s 275 px geometry. New chrome **must match this Classic aesthetic** (see Architecture
  Principles). Shared skin helpers live in `AmpXSkinSprites` / `ClassicSkinTheme`.
- **`Views/Visualizer`, `Visualization/`, `Shaders/`** — the Metal-backed visualizer and `.metal`
  shaders. Heavy/optional; must degrade gracefully when the visualizer window is closed.
- **`Utilities/`** — cross-cutting helpers (colors, metrics, UI scale, typography, FS helpers,
  title-bar drag overlay, marquee typography).
- **`AudioPlaybackControlling`** — protocol abstracting the player so `PlaylistManager` (and tests)
  can inject a mock. Classic UI uses the concrete `AudioPlayer` via `@EnvironmentObject`; prefer the
  protocol at the playlist/test seam, not as a universal rule for every new view.

Supporting dirs: `Tests/` (XCTest `AmpXTests` + generated `Fixtures/`), `scripts/` (test runner,
`uv` fixture generation, `shoot.sh` UI screenshots), `Resources/` (asset catalog, audio, fonts),
`AmpX.xcodeproj/` (primary build), `Package.swift` (**build-smoke secondary** — executable target
only, no asset catalog, **no SPM test target**; run tests via Xcode / `./scripts/run-tests.sh`).

---

## Architecture Principles

**Winamp UX fidelity.**
The compact-player aesthetic is intentional. Do not introduce full-window redesigns. New UI panels should match the existing retro aesthetic.

---

## Coding Conventions

- **Swift formatting:** follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

---

## Build & Test

### Quick build (command line)
```bash
./build.sh --run        # debug build + launch
./build.sh --release    # release build
```

### Xcode
Open `AmpX.xcodeproj`, select the `AmpX` scheme, target `My Mac`, then `⌘R`.

### Iterating on UI (see the rendered app)
```bash
./scripts/shoot.sh            # build + relaunch + screenshot each window
./scripts/shoot.sh --no-build # skip the build; just relaunch + screenshot (fast)
```
Screenshots land in `/tmp/ampx_shot0.png`, `…shot1.png`, etc. Captures **by window ID**
(`screencapture -l<id>`) so it grabs the real window pixels even when occluded — no need to
fight window focus. Essential for Classic skin fidelity work: edit SwiftUI → `shoot.sh` → compare
to the reference skin → repeat.

### Clean build
```bash
xcodebuild -project AmpX.xcodeproj -scheme AmpX clean
# or in Xcode: ⌘⇧K
```

### Running tests
Use the project script — it generates the required fixtures first, then runs the suite:
```bash
./scripts/run-tests.sh
```
This wraps:
```bash
./scripts/generate-fixtures.sh   # builds Tests/Fixtures (sample.m3u, short.wav)
xcodebuild test -project AmpX.xcodeproj -scheme AmpX \
    -destination 'platform=macOS,arch=arm64' ONLY_ACTIVE_ARCH=YES
```
`scripts/run-tests.sh` picks `arm64` or `x86_64` via `uname -m` so Intel Macs work without editing the script.
Running `xcodebuild test` directly without generating fixtures first will fail the fixture-dependent suites (M3U, WAV) — those are missing-file errors, not real regressions.

### Formatting & linting
The repo ships `.swiftformat` and `.swiftlint.yml` configs with wrapper scripts:
```bash
./scripts/format-swift.sh   # apply SwiftFormat
./scripts/lint-swift.sh     # run SwiftLint
```
Run these before committing if the tools are installed; do not hand-fight their style choices.

### Python (`scripts/`)

Fixture generation and any other Python in this repo run through **[uv](https://docs.astral.sh/uv/)**.

- **Agents:** always use `uv` from `scripts/` (e.g. `cd scripts && uv run …`).
- **Entry point:** `./scripts/generate-fixtures.sh` runs `uv sync` then `uv run generate-fixtures`.
- **Add dependencies** in `scripts/pyproject.toml` and lock with `uv lock` (commit `scripts/uv.lock`).

```bash
cd scripts
uv sync
uv run generate-fixtures
uv run python -c "import ampx_fixtures"   # ad-hoc checks
```
