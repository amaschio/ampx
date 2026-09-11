# AmpX

Modern audio player. Classic spirit.

A native macOS music player with the compact floating-window workflow — playlist, EQ, visualizer — built for local libraries (MP3, FLAC, WAV, …).

> **This is a personal fork** of [`mbrukman/winamp-macos`](https://github.com/mbrukman/winamp-macos) (originally by Matt Greenwood, MIT licensed), itself a tribute to the original Winamp by Nullsoft.
> Active development continues at [`ratovarius/ampx`](https://github.com/ratovarius/ampx).

## Full Screen

![Fullscreen Visualizer](fullscreen.png)

## Minimized (Playlist + Main Window independently)

![Minimized Playlist](minimized.png)

## Features

- MP3, FLAC, and WAV playback
- Winamp-inspired UI with the signature compact floating window
- Playlist management with M3U support and drag-to-reorder
- Full playback controls (play, pause, stop, next, previous)
- Shuffle and repeat modes
- Media key & macOS Now Playing integration (Control Center / lock screen)
- Spectrum analyzer visualization
- 10-band equalizer
- Milkdrop-style visualizer (click the icon in the main app) with fullscreen mode
- File browser with drag-and-drop support

## Requirements

- macOS 26.5 (Tahoe) or later
- Xcode 26 or later

## Building

### Using Xcode
1. Open `AmpX.xcodeproj` in Xcode
2. Select the AmpX scheme
3. Build and run (⌘R)

alternatively:

```bash
./build.sh --run        # debug build + launch
./build.sh --release    # release build
```

## Testing

Tests live in `Tests/AmpXTests`. Run them via the project script, which generates the required fixtures first:

```bash
./scripts/run-tests.sh
```

## UI Fidelity

Classic Winamp 2.x layout and behavior are informed by **[Webamp](https://github.com/captbaritone/webamp)** ([webamp.org](https://webamp.org/)) — sprite coordinates, window dimensions, shade mode, and playlist chrome.

## Documentation

- [BUILDING.md](BUILDING.md) — full build instructions
- [USAGE.md](USAGE.md) — end-user usage guide
- [CHANGES.md](CHANGES.md) — changelog
- [docs/](docs/) — deeper engineering notes 

## License & Attribution

MIT License.

Forked from [`mbrukman/winamp-macos`](https://github.com/mbrukman/winamp-macos), © 2024 Matt Greenwood, MIT licensed. The upstream project was itself a tribute to the original Winamp by Nullsoft. This fork continues development independently as AmpX.
