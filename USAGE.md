# AmpX — Usage Guide

A native Classic Winamp 2.x–style player for macOS (AmpX). The UI is the **Classic skin only** (275 px Webamp geometry): main player, shade mode, playlist, equalizer, and a managed ENTHEA visualizer panel. There is no modern dual UI.

**Requires macOS 26.5 (Tahoe) or later.**

---

## Getting started

### Open the app

1. Open `AmpX.xcodeproj` in Xcode, select the **AmpX** scheme, and run (⌘R), **or**
2. From the repo root: `./build.sh --run`

On launch you get the Classic main window (275×116). Playlist and equalizer panels open by default and dock under the main window. The visualizer starts closed.

### Requirements

| | |
|---|---|
| OS | macOS 26.5 (Tahoe)+ |
| Xcode | 26+ (to build from source) |
| Formats | WAV, MP3, FLAC (via AVFoundation) |

---

## Adding music

### File menu

| Action | Shortcut |
|--------|----------|
| **File → Add Files…** | ⌘L |
| **File → Add Folder…** | ⌘⇧L |

Add Files accepts WAV, MP3, and FLAC. Add Folder walks the folder recursively for those extensions.

### Eject button

The Classic eject control on the main window also opens the add-files picker.

### Drag and drop

Drop audio files or folders onto the playlist panel.

### M3U playlists

Load and save M3U playlists from the playlist panel’s menus (same supported audio extensions).

---

## Playback

### Keyboard

| Shortcut | Action |
|----------|--------|
| `X` / `C` / `Space` | Play / Pause |
| `V` | Stop |
| `Z` / `B` | Previous / Next track |
| `R` / `S` | Toggle Repeat / Shuffle |
| `←` / `→` | Seek −/+ 5 seconds (when playlist is not focused) |
| `↑` / `↓` | Volume ± (when playlist is not focused) |
| `L` / `⇧L` | Add file / Add folder |
| `⌘L` / `⌘⇧L` | Add file / Add folder (File menu) |

**Playlist** (when the playlist window is key):

| Shortcut | Action |
|----------|--------|
| Click / `⇧`-click / `⌘`-click | Select / range / toggle |
| `↑` `↓` · `⇧`+arrows | Move cursor · extend selection |
| `Home` / `End` · `Page Up` / `Page Down` | Jump / page (~⅕ of list) |
| `Return` | Play cursor / selection |
| `Delete` | Remove selected |
| `⌘⌫` | Crop (keep selected only) |
| `⌘⇧⌫` | Clear playlist |
| `⌥↑` / `⌥↓` | Move selected rows |
| `⌘A` / `⌘I` | Select all / Invert |
| `⌘⇧1` / `⌘⇧2` / `⌘⇧3` | Sort by title / file name / path |
| `⌘R` / `⌘⇧R` | Reverse / Randomize |

Winamp `Ctrl` shortcuts map to **⌘** on Mac.

### On-skin controls

- **Previous / Play / Pause / Stop / Next** — transport
- **Seek bar** — scrub the current track
- **Volume** and **balance** sliders
- **Shuffle** and **Repeat** toggles (bottom of the main window)
- **EQ** / **PL** toggles — show or hide the equalizer and playlist panels
- Click the time display to switch elapsed vs remaining time

Media keys and macOS Now Playing (Control Center / lock screen) are supported.

### Shuffle and repeat

Both modes are live:

- **Shuffle** — next/previous follow a shuffled order of the playlist
- **Repeat** — wraps at the end of the list (and of the shuffle cycle)

---

## Classic windows

All chrome follows Base 2.91 / Webamp layout. Panels snap and dock to each other (and to the main window); drag a title bar to move a panel or a connected stack. Double-click a title bar for **windowshade** (roll-up), not Dock minimize.

### Main player

Fixed **275×116** skin:

1. Title bar — options menu (left), minimize / shade / close (right)
2. Time digits, play-state LED, bitrate / sample-rate readouts
3. **FFT spectrum / oscilloscope** (76×16) — real analysis from the audio engine, not simulated
4. Scrolling marquee (artist – title)
5. Volume, balance, EQ/PL toggles
6. Seek bar and transport, plus shuffle / repeat

### Shade mode

Click the shade button in the title bar (or double-click the title) to collapse the main window to a thin strip with mini time, transport, and spectrum. Click shade again (or the strip) to restore.

### Playlist

Toggle with the **PL** button on the main window (or close from the playlist title bar).

- Track list with selection and context menu (play / remove)
- Bottom chrome menus (classic Winamp):
  - **ADD** — Add File…, Add Directory…
  - **REM** — Remove, Crop, Clear Playlist (Remove and Crop require a selection)
  - **SEL** — Select All, Select None, Invert Selection
  - **MISC** — Sort by Title / Filename / Path, Reverse, Randomize, File Info
  - **LIST** — New List, Save List…, Load List… (Load replaces the current playlist)
- Multi-select: click, Shift-click, and ⌘-click (keyboard shortcuts in **Playback → Keyboard → Playlist** above)
- **File Info** shows metadata for the first selected track in playlist order when multiple rows are selected; with no selection it uses the currently playing track
- Resize from the bottom-right grip; width stays at least as wide as the main window when docked
- Windowshade via title double-click or the panel’s shade control

### Equalizer

Toggle with the **EQ** button.

- 10-band parametric EQ: 60, 170, 310, 600, 1k, 3k, 6k, 12k, 14k, 16k Hz (−12 dB … +12 dB)
- Preamp, ON / AUTO, and built-in presets
- **Load EQF…** — import Winamp `.eqf` / `.q1` preset files

### Visualizer panel (ENTHEA)

A separate managed window (same docking system as EQ and playlist), not an inline widen of the main player.

**Open it by:**

1. **Double-click** the mini spectrum on the main window (or shade strip), or
2. Title-bar **options** menu → **Show Visualizer**

Close from the panel’s close control or the same menu (**Hide Visualizer**). The panel hosts **ENTHEA** (WebGL) with Classic pledit chrome:

| Control | Action |
|--------|--------|
| ◀ / ▶ | Previous / next visual mode (hold **⇧** to nudge dose) |
| Title | Toggle autopilot · **double-click** to reseed |
| **LOOKS** | Artistic / phenomenological look presets (not medical advice) |
| 💥 | Force a drop effect |
| ⛶ / **F** | Theater (full display including menu-bar / notch band) |
| **Escape** / **F** | Exit theater and restore size/position |

While a track plays, native offline analysis maps drops/sections into ENTHEA’s timeline (no file handed to WebKit). Embedded album art (when present) feeds **Image Warp**. Audio IPC caps at ~30 Hz when the docked panel is small and ~60 Hz when large or in theater; rendering and IPC pause when playback is stopped, the panel is shaded/hidden, or the window is occluded. The main-window mini spectrum stays Metal.

Photosensitivity: the first open shows a notice. Flicker drive stays off by default.

**Looks** are artistic visual interpretations of ENTHEA’s substance presets (titles like “Electric Lattices”, not dosing guidance). Not dosing advice, not medical advice; simulator only.

### Zoom

**Zoom** menu — scale the Classic UI (skin metrics and panels) without changing the 275 px logical layout.

---

## Supported formats & metadata

| Format | Support |
|--------|---------|
| **WAV** | Yes |
| **MP3** | Yes |
| **FLAC** | Yes |

Displayed metadata includes title, artist, duration, bitrate, and sample rate (as available from the file).

---

## Tips

1. **Docking** — snap panels under or beside each other; connected stacks move together. Positions are the source of truth (geometry-primary docking).
2. **Shade** — keep a thin strip on screen while listening; playlist and EQ can shade independently where supported.
3. **Audio path** — AVAudioEngine with a 10-band `AVAudioUnitEQ` and an analysis tap feeding FFT features to the mini spectrum and ENTHEA host.
4. **UI iteration for developers** — `./scripts/shoot.sh` builds/relaunches and screenshots each window to `/tmp/ampx_shot*.png`.

---

## Troubleshooting

### No playback

- Confirm the file is WAV, MP3, or FLAC and not corrupt
- Check the on-skin volume and system output device
- Ensure duration appears after load

### Files won’t open

- Grant access when the open panel asks (user-selected file access)
- Prefer Add Files / Add Folder over paths the sandbox cannot read

### No spectrum / empty visualizer

- Start playback — analysis follows the engine tap
- Open the visualizer panel via double-click on the mini spectrum if you expect the full visualizer window

---

## Technical overview

| Layer | Role |
|-------|------|
| SwiftUI + AppKit | Classic skin views (`Views/Classic`), borderless panel windows |
| AVFoundation / AVAudioEngine | Decode, playback, EQ, FFT feature bus |
| WebKit / WebGL | ENTHEA visualizer panel (`Resources/Enthea/`, `Sources/Enthea/`) |
| Metal | Mini spectrum (`Visualization/`, `Shaders/`) |

**Audio pipeline (simplified):**

```
Audio file → player node → 10-band EQ → mixer → output
                              ↘ analysis tap → FFT / features → spectrum + ENTHEA
```

Key sources: `AmpXApp.swift`, `ContentView.swift`, `AudioPlayer.swift`, `PlaylistManager.swift`, `Views/Classic/*`, `AmpXPanelWindowManager.swift`.

---

## Credits

Tribute to the original Winamp by Nullsoft.

“It really whips the llama's ass!” — Justin Frankel

## License

MIT — see `LICENSE`.
