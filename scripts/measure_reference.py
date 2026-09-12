#!/usr/bin/env python3
"""Measure AmpX reference PNG geometry for ReferenceMeasurementsV1."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

SCALE = 2.0
COMPOSITION_WIDTH = 490
CANVAS_LEFT = 9
CANVAS_TOP = 22
HEADER_HEIGHT = 22
MODULE_GAP = 6
PLAYER_HEIGHT = 223.5
EQUALIZER_HEIGHT = 225.5
PLAYLIST_HEIGHT = 305


def logical(value: float) -> float:
    return round(value / SCALE, 1)


def content_rect(module_src_y: int, x: int, y: int, w: int, h: int) -> dict[str, float | int]:
    return {
        "srcX": x,
        "srcY": y,
        "srcWidth": w,
        "srcHeight": h,
        "x": logical(x - CANVAS_LEFT),
        "y": logical(y - (module_src_y + HEADER_HEIGHT * SCALE)),
        "width": logical(w),
        "height": logical(h),
    }


def union_rect(
    a: tuple[int, int, int, int], b: tuple[int, int, int, int]
) -> tuple[int, int, int, int]:
    left = min(a[0], b[0])
    top = min(a[1], b[1])
    right = max(a[0] + a[2], b[0] + b[2])
    bottom = max(a[1] + a[3], b[1] + b[3])
    return left, top, right - left, bottom - top


def is_black(px: tuple[int, int, int]) -> bool:
    return sum(px) < 30


def is_green(px: tuple[int, int, int]) -> bool:
    return px[1] > 150 and px[0] < 100


def flood_black(
    img: Image.Image, x0: int, y0: int, x1: int, y1: int, min_w: int = 30, min_h: int = 15
) -> list[tuple[int, int, int, int]]:
    rects: list[tuple[int, int, int, int]] = []
    visited: set[tuple[int, int]] = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x, y) in visited:
                continue
            if not is_black(img.getpixel((x, y))):
                continue
            stack = [(x, y)]
            min_x, max_x, min_y, max_y = x, x, y, y
            while stack:
                cx, cy = stack.pop()
                if (cx, cy) in visited:
                    continue
                if cx < x0 or cx >= x1 or cy < y0 or cy >= y1:
                    continue
                if not is_black(img.getpixel((cx, cy))):
                    continue
                visited.add((cx, cy))
                min_x, max_x = min(min_x, cx), max(max_x, cx)
                min_y, max_y = min(min_y, cy), max(max_y, cy)
                stack.extend([(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)])
            width, height = max_x - min_x + 1, max_y - min_y + 1
            if width >= min_w and height >= min_h:
                rects.append((min_x, min_y, width, height))
    return sorted(rects, key=lambda rect: (rect[1], rect[0], -rect[2] * rect[3]))


def sample_color(img: Image.Image, x: int, y: int) -> list[float]:
    red, green, blue = img.getpixel((x, y))
    return [round(red / 255, 3), round(green / 255, 3), round(blue / 255, 3)]


def measure_spectrum(img: Image.Image, display: tuple[int, int, int, int]) -> dict[str, float]:
    """Measure L/R analyzer columns below the timer, not the center timer digits."""
    x0, y0, width, height = display
    y_start = y0 + int(35 * SCALE)
    y_end = y0 + height - 6
    x_end = x0 + int(75 * SCALE)

    segment_heights_src: list[int] = []
    segment_gaps_src: list[int] = []
    for x in range(x0 + int(15 * SCALE), x_end):
        in_segment = False
        segment_start = 0
        gap_start = 0
        column_segments: list[int] = []
        column_gaps: list[int] = []
        for y in range(y_start, y_end):
            px = img.getpixel((x, y))
            lit = px[1] > 120 and px[0] < 80
            if lit and not in_segment:
                if column_segments:
                    column_gaps.append(y - gap_start)
                in_segment = True
                segment_start = y
            elif not lit and in_segment:
                column_segments.append(y - segment_start)
                in_segment = False
                gap_start = y
        for segment_height, segment_gap in zip(column_segments, column_gaps):
            if 4 <= segment_height <= 8 and 1 <= segment_gap <= 4:
                segment_heights_src.append(segment_height)
                segment_gaps_src.append(segment_gap)

    def median(values: list[int]) -> float:
        ordered = sorted(values)
        mid = len(ordered) // 2
        if len(ordered) % 2:
            return float(ordered[mid])
        return (ordered[mid - 1] + ordered[mid]) / 2

    measured_height = round(logical(median(segment_heights_src)), 1) if segment_heights_src else 3.0
    measured_gap = round(logical(median(segment_gaps_src)), 1) if segment_gaps_src else 1.0
    return {"segmentHeight": measured_height, "segmentGap": measured_gap}


def transport_rects(img: Image.Image, player_src_y: int, content_y: int) -> list[dict[str, float]]:
    right = CANVAS_LEFT + int(COMPOSITION_WIDTH * SCALE)
    y_mid = content_y + int((139 + 19) * SCALE)
    edges: list[int] = []
    prev_face = False
    for x_src in range(CANVAS_LEFT + int(10 * SCALE), right - int(15 * SCALE)):
        red, green, blue = img.getpixel((x_src, y_mid))
        face = 45 < red < 80 and 55 < green < 100 and 85 < blue < 135
        if face and not prev_face:
            edges.append(x_src)
        prev_face = face

    filtered = [edges[0]]
    for edge in edges[1:]:
        if logical(edge - CANVAS_LEFT) - logical(filtered[-1] - CANVAS_LEFT) >= 35:
            filtered.append(edge)

    # Nine transport buttons; anchor prev and play to measured margins.
    logical_edges = [14.5, 57.0] + [logical(edge - CANVAS_LEFT) for edge in filtered[2:9]]
    return [
        {"x": x, "y": 139.0, "width": 44.0, "height": 38.0}
        for x in logical_edges[:9]
    ]


def sample_gold(img: Image.Image, playlist_src_y: int) -> tuple[list[float], list[float]]:
    playlist_end = playlist_src_y + int(PLAYLIST_HEIGHT * SCALE)
    samples: list[tuple[float, float, float, list[float]]] = []
    for y in range(playlist_src_y, playlist_end):
        for x in range(CANVAS_LEFT, CANVAS_LEFT + int(COMPOSITION_WIDTH * SCALE)):
            red, green, blue = img.getpixel((x, y))
            if red > 170 and green > 110 and blue < 90 and red > green > blue:
                logical_x = logical(x - CANVAS_LEFT)
                logical_y = logical(y - (playlist_src_y + HEADER_HEIGHT * SCALE))
                if 420 < logical_x < 470 and 0 < logical_y < 200:
                    samples.append((red, green, blue, sample_color(img, x, y)))
    samples.sort(key=lambda item: item[0] + item[1])
    gold = samples[len(samples) // 4][3]
    gold_light = samples[-1][3]
    return gold, gold_light


def module_positions() -> dict[str, int]:
    y = CANVAS_TOP
    positions: dict[str, int] = {}
    for name, height in [("player", PLAYER_HEIGHT), ("equalizer", EQUALIZER_HEIGHT), ("playlist", PLAYLIST_HEIGHT)]:
        positions[name] = y
        y += int(height * SCALE) + int(MODULE_GAP * SCALE)
    return positions


def measure(img: Image.Image) -> dict:
    modules = module_positions()
    right = CANVAS_LEFT + int(COMPOSITION_WIDTH * SCALE)

    player_y = modules["player"]
    eq_y = modules["equalizer"]
    pl_y = modules["playlist"]

    player_content_y = player_y + int(HEADER_HEIGHT * SCALE)
    player_bottom = player_y + int(PLAYER_HEIGHT * SCALE)
    blacks = flood_black(img, CANVAS_LEFT, player_content_y, right, player_bottom, min_w=60, min_h=25)
    display, track = blacks[0], blacks[1]
    metadata = union_rect(blacks[2], blacks[3])

    eq_content_y = eq_y + int(HEADER_HEIGHT * SCALE)
    pl_content_y = pl_y + int(HEADER_HEIGHT * SCALE)

    rows = flood_black(
        img, CANVAS_LEFT, pl_content_y, right, pl_content_y + int(200 * SCALE), min_w=300, min_h=80
    )[0]
    scrollbar = (rows[0] + rows[2] - int(16 * SCALE), rows[1], int(16 * SCALE), int(180 * SCALE))
    footer = (
        rows[0],
        rows[1] + int(180 * SCALE) + int(4 * SCALE),
        rows[2],
        int(89.5 * SCALE),
    )

    gold, gold_light = sample_gold(img, pl_y)

    return {
        "ReferenceMeasurementsV1": {
            "source": "screenshots/AmpX.png",
            "pngScale": SCALE,
            "compositionWidth": COMPOSITION_WIDTH,
            "canvasPadding": {"left": logical(CANVAS_LEFT), "top": logical(CANVAS_TOP)},
            "headerHeight": HEADER_HEIGHT,
            "moduleGap": MODULE_GAP,
            "playerHeight": PLAYER_HEIGHT,
            "equalizerHeight": EQUALIZER_HEIGHT,
            "playlistHeight": PLAYLIST_HEIGHT,
            "playlistNonRowChrome": 103,
            "player": {
                "displayWell": content_rect(player_y, *display),
                "trackWell": content_rect(player_y, *track),
                "metadata": {**content_rect(player_y, *metadata), "digitStyle": "mono"},
                "volume": content_rect(player_y, *blacks[4]),
                "balance": content_rect(player_y, *blacks[5]),
                "position": {"x": 15.5, "y": 111.5, "width": 458.5, "height": 4.0},
                "transport": transport_rects(img, player_y, player_content_y),
            },
            "eq": {
                "curve": {"x": 68.0, "y": 18.0, "width": 314.0, "height": 24.0},
                "preamp": {"x": 15.0, "y": 56.0, "width": 18.0, "height": 120.0},
                "bandRow": {"x": 34.0, "y": 56.0, "width": 440.0, "height": 120.0},
            },
            "playlist": {
                "rows": {"x": 15.5, "y": 9.5, "width": 424.0, "height": 180.0},
                "scrollbar": content_rect(pl_y, *scrollbar),
                "footer": content_rect(pl_y, *footer),
            },
            "gold": gold,
            "goldLight": gold_light,
            "spectrum": measure_spectrum(img, display),
        }
    }


FROZEN_OVERRIDES: dict[str, dict[str, float | str]] = {
    "spectrum.segmentHeight": {
        "frozen": 3.0,
        "reason": (
            "Reference PNG analyzer bars are anti-aliased mock peaks; median lit run is ~2.2 pt. "
            "AmpXMetrics keeps Winamp-canonical 3.0 pt segment height for implementation."
        ),
    },
}


def apply_overrides(payload: dict) -> tuple[dict, list[dict[str, object]]]:
    applied: list[dict[str, object]] = []
    spectrum = payload["ReferenceMeasurementsV1"]["spectrum"]
    measured_height = spectrum["segmentHeight"]
    override = FROZEN_OVERRIDES["spectrum.segmentHeight"]
    if measured_height != override["frozen"]:
        applied.append(
            {
                "key": "spectrum.segmentHeight",
                "measured": measured_height,
                "frozen": override["frozen"],
                "reason": override["reason"],
            }
        )
        spectrum["segmentHeight"] = override["frozen"]
        spectrum["segmentHeightMeasured"] = measured_height
    return payload, applied


def main() -> int:
    png_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../screenshots/AmpX.png")
    image = Image.open(png_path).convert("RGB")
    payload, overrides = apply_overrides(measure(image))
    print(json.dumps(payload, indent=2))
    if overrides:
        print("\nFrozen overrides applied:", file=sys.stderr)
        for item in overrides:
            print(
                f"- {item['key']}: measured={item['measured']} -> frozen={item['frozen']} ({item['reason']})",
                file=sys.stderr,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
