#!/usr/bin/env python3
"""Generate auditable, manually measured Player landmarks and annotations.
Run from scripts/: uv run python measure_reference.py ../screenshots/AmpX.png
No automatic-design claims, unmeasured EQ/Playlist values, or canonical overrides.
"""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median
from PIL import Image, ImageDraw, ImageFont

SCALE = 2
PANEL = (10, 7, 980, 447)  # Excludes only the soft outer fringe.
ORIGIN = (10, 64)  # Content origin; header/frame seam starts at y=62.
# group | name | visible source x,y,w,h; ±2 source-pixel edge uncertainty.
LANDMARK_TEXT = '''frame|panel|10,7,980,447
frame|content.frame|24,62,952,379
header|header|10,7,980,57
header|header.brand|449,19,100,36
header|header.gripGlyph|29,21,36,32
header|header.leftLine.top|85,26,325,7
header|header.leftLine.bottom|85,38,325,7
header|header.rightLine.top|582,26,238,7
header|header.rightLine.bottom|582,38,238,7
header|header.minimize|834,17,40,40
header|header.collapse|886,17,40,40
header|header.close|937,17,40,40
display|display.well|37,84,336,190
display|display.blackInterior|41,89,328,181
display|display.playGlyph|80,106,28,36
display|display.timer|179,100,164,51
timer|display.timer.digit0|179,101,29,50
timer|display.timer.digit1|229,101,9,49
timer|display.timer.colon|253,112,13,28
timer|display.timer.digit5|282,101,28,50
timer|display.timer.last1|331,101,12,49
display|display.spectrum|76,178,275,82
display|display.channelL|48,192,18,27
display|display.channelR|48,234,18,27
metadata|track.well|385,84,577,63
metadata|track.text|397,100,429,28
metadata|metadata.bitrateWell|385,156,79,50
metadata|metadata.bitrateInk|397,168,51,25
metadata|metadata.kbps|474,171,53,27
metadata|metadata.sampleRateWell|558,157,66,49
metadata|metadata.sampleRateInk|574,168,33,25
metadata|metadata.kHz|635,171,41,23
metadata|metadata.mono|791,175,60,18
metadata|metadata.stereo|871,171,82,22
sliders|volume.track|387,235,211,22
sliders|volume.coloredInterior|393,240,199,12
sliders|volume.thumb|515,230,43,40
sliders|balance.track|615,235,134,22
sliders|balance.coloredInterior|622,240,120,12
sliders|balance.thumb|661,230,43,40
sliders|toggle.eq|763,218,93,57
sliders|toggle.eq.indicator|776,234,20,24
sliders|toggle.eq.label|807,235,26,24
sliders|toggle.pl|866,218,95,57
sliders|toggle.pl.indicator|878,234,21,24
sliders|toggle.pl.label|911,235,27,24
sliders|position.well|37,287,925,39
sliders|position.trackInterior|46,296,908,22
sliders|position.thumb|451,292,95,32
transport|transport.previous|38,343,88,77
transport|transport.play|132,343,92,77
transport|transport.pause|229,343,84,77
transport|transport.stop|321,343,87,77
transport|transport.next|417,343,87,77
transport|transport.eject|515,343,94,77
transport|transport.shuffle|617,343,168,77
transport|transport.repeat|791,343,85,77
transport|transport.menu|893,348,67,71
glyphs|transport.previous.glyph|67,365,29,32
glyphs|transport.play.glyph|166,366,27,31
glyphs|transport.pause.glyph|259,367,24,29
glyphs|transport.stop.glyph|353,369,25,25
glyphs|transport.next.glyph|448,365,28,32
glyphs|transport.eject.glyph|547,368,30,29
glyphs|transport.shuffle.indicator|634,366,21,25
glyphs|transport.shuffle.label|668,372,93,20
glyphs|transport.repeat.glyph|815,365,37,32
glyphs|transport.menu.glyph|911,369,31,28'''
PATCHES = {
    'display.black': (51,152,5,5), 'panel.interior': (700,210,5,5),
    'button.face': (145,352,5,5), 'button.topHighlight': (142,346,10,1),
    'button.leftHighlight': (135,355,1,10), 'button.bottomShadow': (145,416,10,1),
    'frame.highlight': (50,64,10,1), 'frame.darkEdge': (50,66,10,1),
    'thumb.steelFace': (522,237,5,5), 'thumb.steelHighlight': (522,233,10,1),
    'thumb.goldFace': (475,312,10,3), 'thumb.goldHighlight': (467,295,20,1),
}


def converted(rect, origin):
    x,y,w,h = rect
    return [(x-origin[0])/SCALE,(y-origin[1])/SCALE,w/SCALE,h/SCALE]


def lit_runs(im, x):
    runs, start = [], None
    for y in range(205,261):
        r,g,b = im.getpixel((x,y)) if y < 260 else (0,0,0)
        lit = g > 130 and g > b*1.8
        if lit and start is None:
            start = y
        elif not lit and start is not None:
            runs.append([start,y-start])
            start = None
    return runs


def generate(path, output):
    im = Image.open(path).convert('RGB')
    if im.size != (998,1576):
        raise ValueError('Remeasure landmarks for any other source dimensions.')
    output.mkdir(parents=True,exist_ok=True)
    records = []
    for i,line in enumerate(LANDMARK_TEXT.splitlines(),1):
        group,name,raw = line.split('|')
        rect = list(map(int,raw.split(',')))
        x,y,w,h = rect
        assert w > 0 and h > 0 and 0 <= x < x+w <= im.width and 0 <= y < y+h <= im.height
        records.append(dict(id=i,name=name,sourceRect=rect,group=group,
            moduleRect=converted(rect,PANEL[:2]),contentRect=converted(rect,ORIGIN),
            method='manual visible-edge/ink measurement; inspect annotation',edgeUncertaintySourcePx=2))
    colors = {}
    for name,(x,y,w,h) in PATCHES.items():
        values = list(im.crop((x,y,x+w,y+h)).get_flattened_data())
        rgb = [round(median(p[c] for p in values)) for c in range(3)]
        colors[name] = dict(sourcePatch=[x,y,w,h],rgb=rgb,hex='#'+''.join(f'{c:02X}' for c in rgb))
    # Pixel profiles preserve layer widths/gradients without pretending one color
    # sample specifies an entire material. Coordinates are source pixels.
    profiles = {}
    for name,x,y,w,h in (
        ('button.topEdge',150,342,1,12),
        ('button.bottomEdge',150,409,1,12),
        ('frame.topEdge',100,5,1,14),
        ('well.topEdge',400,81,1,12),
        ('steelThumb.topEdge',530,228,1,16),
        ('goldThumb.topEdge',480,290,1,22),
    ):
        profiles[name] = dict(sourcePatch=[x,y,w,h],
            rgb=[list(im.getpixel((x,y+dy))) for dy in range(h)])
    scans = {str(x):lit_runs(im,x) for x in (81,99,116,134)}
    heights = [h for runs in scans.values() for _,h in runs]
    gaps = [b[0]-a[0]-a[1] for runs in scans.values() for a,b in zip(runs,runs[1:])]
    spectrum = dict(sourceRuns=scans,medianLitHeightSourcePx=median(heights) if heights else None,
        medianGapSourcePx=median(gaps) if gaps else None,
        note='Thresholded bright cores at y=205..259; glow excluded. No fallback or canonical override.')
    by_name = {r['name']:r for r in records}
    travel = {}
    for prefix,track in [('volume','volume.coloredInterior'),('balance','balance.coloredInterior'),('position','position.trackInterior')]:
        x,y,w,h = by_name[track]['sourceRect']
        tw = by_name[prefix+'.thumb']['sourceRect'][2]
        travel[prefix] = dict(sourceCenterEndpoints=[x+tw/2,x+w-tw/2],
            method='derived inset-travel proposal; NOT observable from this single pose',
            hitBounds='not observable; define during implementation without enlarging artwork')
    payload = dict(version='ReferenceMeasurementsV2',scope='Player only',
        source='screenshots/AmpX.png',sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        imageSize=list(im.size),sourceScale=SCALE,panelSourceRect=list(PANEL),
        moduleOrigin=list(PANEL[:2]),contentOrigin=list(ORIGIN),headerHeightLogical=28.5,
        convention='x,y,width,height; right/bottom exclusive. Frame includes bevel, excludes soft fringe.',
        records=records,colorSamples=colors,edgeProfiles=profiles,spectrum=spectrum,proposedTravel=travel)
    (output/'player-measurements-v2.json').write_text(json.dumps(payload,indent=2)+'\n')
    font = ImageFont.load_default(size=13)
    groups = ('frame','header','display','timer','metadata','sliders','transport','glyphs')
    for group in groups:
        canvas = im.crop((0,0,998,457)).resize((1497,686))
        draw = ImageDraw.Draw(canvas)
        for r in records:
            if r['group'] == group:
                x,y,w,h = r['sourceRect']
                draw.rectangle((x*1.5,y*1.5,(x+w)*1.5-1,(y+h)*1.5-1),outline='#FF59E7',width=2)
                draw.text((x*1.5+2,y*1.5+2),str(r['id']),font=font,fill='black',stroke_width=2,stroke_fill='white')
        canvas.save(output/f'player-{group}-annotated.png')
    im.crop((10,7,990,454)).save(output/'player-source.png')
    scan = im.crop((70,170,155,263)).resize((510,558))
    draw = ImageDraw.Draw(scan)
    for x in scans:
        draw.line(((int(x)-70)*6,210,(int(x)-70)*6,540),fill='#FF59E7',width=1)
    scan.save(output/'player-spectrum-scan.png')
    material = Image.new('RGB',(1200,600),'#121923')
    draw = ImageDraw.Draw(material)
    for i,(name,box) in enumerate((
        ('Frame / well',(15,55,130,105)),
        ('Raised transport face',(128,337,228,427)),
        ('Steel thumb',(500,222,566,278)),
        ('Gold thumb',(444,284,554,332)),
    )):
        x,y=(i%2)*600,(i//2)*300
        draw.text((x+12,y+10),name,font=font,fill='white')
        crop=im.crop(box)
        crop.thumbnail((570,245))
        # Nearest-neighbor magnification makes the source edge layers explicit.
        factor=min(570/crop.width,245/crop.height)
        material.paste(crop.resize((int(crop.width*factor),int(crop.height*factor)),Image.Resampling.NEAREST),(x+12,y+36))
    material.save(output/'player-material-details.png')
    lines = ['# ReferenceMeasurementsV2 — Player','',
        'Generated by `scripts/measure_reference.py`. Source SHA-256: `'+payload['sha256']+'`.','',
        '**Scope:** Player only. Manually measured artwork bounds, ±2 source-pixel edge uncertainty (±1 pt); right/bottom exclusive. Glyph bounds are visible ink, not font layout cells. Hit areas are not visible in the PNG.','',
        '**Origins:** module `(10,7)` px; content `(10,64)` px. Player crop `980×447` px = `490×223.5` pt. Header convention `28.5` pt; the content-frame highlight begins at y=62, two pixels above that origin. Replaces the V1 inferred y=22 canvas top and 22 pt header.','',
        '## Measured rectangles','','| ID | Element | Source x,y,w,h (px) | Module x,y,w,h (pt) | Content x,y,w,h (pt) |','|---|---|---|---|---|']
    for r in records:
        lines.append(f"| {r['id']} | `{r['name']}` | {r['sourceRect']} | {r['moduleRect']} | {r['contentRect']} |")
    lines += ['','## Annotated checks','']
    for group in groups:
        lines += [f'### {group.title()}','',f'![{group} bounds](player-{group}-annotated.png)','']
    lines += ['## Material samples','','Patch medians are observations, not a uniform replacement palette. The reference has gradients, glow and multiple edge layers. Preserve these variations; coordinates allow verification.','','| Layer | Source patch | RGB | Hex |','|---|---|---|---|']
    for name,c in colors.items():
        lines.append(f"| {name} | {c['sourcePatch']} | {c['rgb']} | `{c['hex']}` |")
    lines += ['', '![Material edge details](player-material-details.png)', '',
        'The JSON `edgeProfiles` contains per-source-pixel RGB scans through frame, well, button and thumb edges. Each sample is 0.5 logical pt; preserve the sequence of highlight, face and shadow layers rather than replacing it with a one-line outline. The enlarged crops use nearest-neighbor scaling to expose source pixels.', '']
    lines += ['','## Spectrum scan','','```json',json.dumps(spectrum,indent=2),'```','',
        '![Spectrum scan](player-spectrum-scan.png)','',
        '## Non-observable properties and implementation constraints','',
        '- Thumb travel and invisible hit bounds cannot be measured from one pose. JSON records a derived inset-travel proposal separately. Validate it during control implementation; do not present it as extracted geometry.',
        '- Font point size, baseline metrics and hidden timer cell widths cannot be uniquely recovered from raster ink. Fit bundled fonts and stable digit cells to measured ink, then verify rendered overlays before freezing metrics. The visible `1` is narrow ink, not a narrower layout cell.',
        '- Keep centered Player branding; single-line track/metadata; distinct kbps, kHz, mono, stereo; EQ/PL and Shuffle optically aligned with indicators. The timer reads `01:51` and must retain its proportions for other values.',
        '- Header source order is left decoration, centered brand between paired lines, then minimize/collapse/close; behavior comes from the spec.','',
        '## V1 corrections','',
        '- Panel top is measured directly, not inferred by centering a total composition height.',
        '- Metadata includes channel labels separately from the two numeric wells.',
        '- The play triangle is outside the timer ink rectangle.',
        '- Volume/balance thumbs exceed the narrow track height. Position includes a recessed well and broad gold handle, not a four-point-high entire control.',
        '- Transport faces have individual widths; Shuffle is 84 pt wide rather than a uniform 44 pt.',
        '- Spectrum raw runs are retained without the unapproved 3 pt override.',
        '- EQ/Playlist V1 values remain unvalidated by this Player-only step.','']
    (output/'player-measurements-v2.md').write_text('\n'.join(lines))
    print(json.dumps(dict(output=str(output),rectangles=len(records),spectrum=spectrum),indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('--output',type=Path,default=Path('../docs/superpowers/plans/reference-crops/v2'))
    args = parser.parse_args()
    generate(args.source,args.output)


if __name__ == '__main__':
    main()
