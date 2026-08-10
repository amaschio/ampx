# Winamp macOS — Usage Guide

A native Classic Winamp 2.x–style player for macOS. The UI is the **Classic skin only** (275 px Webamp geometry): main player, shade mode, playlist, equalizer, and a managed ENTHEA visualizer panel. There is no modern dual UI.

**Requires macOS 26.5 (Tahoe) or later.**

---

## Getting started

### Open the app

1. Open `Winamp.xcodeproj` in Xcode, select the **Winamp** scheme, and run (⌘R), **or**
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
| `X` | Play / Pause |
| `V` | Stop |
| `Z` | Previous track |
| `B` | Next track |
| `Space` | Play / Pause (when not typing in a text field) |

Playlist (when the playlist window is key): ↑ / ↓ move selection; Return plays the selected track.

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

- Track list with selection, context menu (play / remove), and playlist actions (add, clear, M3U, etc.)
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

Close from the panel’s close control or the same menu (**Hide Visualizer**). The panel hosts **ENTHEA** (WebGL) with Classic pledit chrome: mode ◀/▶, title toggles autopilot, **F** (or the ⛶ strip control) enters theater mode (covers the full display including the menu-bar / notch band; **Escape** or **F** exits and restores size/position). The main-window mini spectrum stays Metal.

Photosensitivity: the first open shows a notice. Flicker drive stays off by default.

Kill switch (rollback to Metal MilkDrop body): `defaults write com.winamp.macos entheaForceMetalBody -bool YES`, then reopen the panel.

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
3. **Audio path** — AVAudioEngine with a 10-band `AVAudioUnitEQ` and an analysis tap feeding FFT features to the spectrum and MilkDrop views.
4. **UI iteration for developers** — `./scripts/shoot.sh` builds/relaunches and screenshots each window to `/tmp/winamp_shot*.png`.

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
| Metal | Mini spectrum and MilkDrop panel (`Visualization/`, `Shaders/`) |

**Audio pipeline (simplified):**

```
Audio file → player node → 10-band EQ → mixer → output
                              ↘ analysis tap → FFT / features → spectrum + MilkDrop
```

Key sources: `WinampApp.swift`, `ContentView.swift`, `AudioPlayer.swift`, `PlaylistManager.swift`, `Views/Classic/*`, `WinampPanelWindowManager.swift`.

---

## Credits

Tribute to the original Winamp by Nullsoft.

“It really whips the llama's ass!” — Justin Frankel

## License

MIT — see `LICENSE`.
