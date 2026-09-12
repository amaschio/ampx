# AmpX UI Visual Checks — ReferenceMeasurementsV1

**Date:** 2026-09-11  
**Source:** `screenshots/AmpX.png` (998×1576 px, 2× retina; logical canvas 499×788 pt, composition 490 pt wide)  
**Tooling:** `cd scripts && uv run python measure_reference.py ../screenshots/AmpX.png`

All content rectangles are in module-local coordinates (origin below the 22 pt header, excluding outer canvas padding).

## Stack geometry

| Key | Logical value | Notes |
|---|---|---|
| `compositionWidth` | 490 | Module column width at scale 1.0 |
| `canvasPadding.left` | 4.5 | `(499 − 490) / 2` |
| `canvasPadding.top` | 11 | `(788 − 766) / 2` |
| `headerHeight` | 22 | Gold accent line at ~10.5 pt from module top |
| `moduleGap` | 6 | Between Player, Equalizer, Playlist |
| `playerHeight` | 223.5 | Module outer height |
| `equalizerHeight` | 225.5 | Module outer height |
| `playlistHeight` | 305 | Module outer height |
| `playlistNonRowChrome` | 103 | Header offset + footer; viewport = 180 pt |

## Player (`player.*`)

| Key | Content rect (x, y, w, h) | Notes |
|---|---|---|
| `player.displayWell` | (15.0, 10.5, 165.5, 92.0) | Timer + spectrum column |
| `player.trackWell` | (189.5, 11.0, 285.5, 28.0) | Title marquee well |
| `player.metadata` | (189.5, 46.5, 116.5, 21.5) | kbps / kHz / mono / stereo |
| `player.metadata.digitStyle` | **mono** | Roboto Mono; timer stays segment-drawn |
| `player.volume` | (189.0, 81.5, 100.5, 20.5) | Volume slider track |
| `player.balance` | (305.0, 81.5, 61.0, 20.5) | Balance slider track |
| `player.position` | (15.5, 111.5, 458.5, 4.0) | Full-width seek bar |
| `player.transport[0…8]` | See `AmpXMetrics.playerTransport` | prev, play, pause, stop, next, eject, shuffle, repeat, menu — 44×38 pt |

## Equalizer (`eq.*`)

| Key | Content rect (x, y, w, h) |
|---|---|
| `eq.curve` | (68.0, 18.0, 314.0, 24.0) |
| `eq.preamp` | (15.0, 56.0, 18.0, 120.0) |
| `eq.bandRow` | (34.0, 56.0, 440.0, 120.0) |

## Playlist (`playlist.*`)

| Key | Content rect (x, y, w, h) | Notes |
|---|---|---|
| `playlist.rows` | (15.5, 9.5, 424.0, 180.0) | Black row viewport |
| `playlist.scrollbar` | (440.5, 9.5, 16.0, 180.0) | Gold thumb track |
| `playlist.footer` | (15.5, 193.5, 441.0, 89.5) | ADD/REM/SEL/MISC + mini transport |
| `playlist.rowHeight` | 22 | Fixed row pitch |
| `playlist.durationColumnWidth` | 42 | Right-aligned durations |

## Palette & spectrum

| Key | Value | Sample region |
|---|---|---|
| `gold` | `srgb(0.749, 0.627, 0.322)` | Playlist scrollbar thumb |
| `goldLight` | `srgb(1.0, 0.953, 0.286)` | Thumb highlight |
| `spectrum.segmentHeight` | 3.0 pt | L/R analyzer columns |
| `spectrum.segmentGap` | 1.0 pt | Gap between lit segments |

## Composition checkpoints (Tasks 6A–6C)

- [ ] Task 6A: Player crop — wells, timer segments, mono metadata, transport silhouettes
- [ ] Task 6B: Equalizer crop — curve well, preamp, ten band tracks, mock curve
- [ ] Task 6C: Full three-module stack at scale 1.0 and scale bounds

Capture: `./scripts/shoot.sh -- -AmpXNewUI YES`
