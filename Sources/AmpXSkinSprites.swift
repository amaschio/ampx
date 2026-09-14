import AppKit
import SwiftUI

/// RE:AMP classic skin sprite atlases (extracted from Reamp.app Assets.car).
/// Coordinates match Webamp's `skinSprites.ts` / Base 2.91 layout (top-left origin).
enum AmpXSkinSheet: String, CaseIterable {
    case main = "AmpXSkinMain"
    case cbuttons = "AmpXSkinCButtons"
    case shufrep = "AmpXSkinShufrep"
    case posbar = "AmpXSkinPosbar"
    case volume = "AmpXSkinVolume"
    case balance = "AmpXSkinBalance"
    case titlebar = "AmpXSkinTitlebar"
    case numbers = "AmpXSkinNumbers"
    case text = "AmpXSkinText"
    case playpaus = "AmpXSkinPlaypaus"
    case monoster = "AmpXSkinMonoster"
    case eqmain = "AmpXSkinEqmain"
    case pledit = "AmpXSkinPledit"
}

/// Sprite rects in Webamp / Base 2.91 coordinates (top-left origin).
enum AmpXSkinSprites {
    // MARK: - Main window

    enum Main {
        /// Full MAIN.BMP including baked titlebar (prefer `windowBody` + TITLEBAR overlay).
        static let windowBackground = Sprite(sheet: .main, x: 0, y: 0, width: 275, height: 116)
        /// MAIN.BMP below the 14px titlebar — avoids double-drawing corner icons with TITLEBAR.BMP.
        static let windowBody = Sprite(sheet: .main, x: 0, y: 14, width: 275, height: 102)
    }

    enum Titlebar {
        static let bar = Sprite(sheet: .titlebar, x: 27, y: 15, width: 275, height: 14)
        static let barSelected = Sprite(sheet: .titlebar, x: 27, y: 0, width: 275, height: 14)
        static let shadeBar = Sprite(sheet: .titlebar, x: 27, y: 42, width: 275, height: 14)
        static let shadeBarSelected = Sprite(sheet: .titlebar, x: 27, y: 29, width: 275, height: 14)
        static let options = Sprite(sheet: .titlebar, x: 0, y: 0, width: 9, height: 9)
        static let optionsPressed = Sprite(sheet: .titlebar, x: 0, y: 9, width: 9, height: 9)
        static let minimize = Sprite(sheet: .titlebar, x: 9, y: 0, width: 9, height: 9)
        static let minimizePressed = Sprite(sheet: .titlebar, x: 9, y: 9, width: 9, height: 9)
        static let shade = Sprite(sheet: .titlebar, x: 0, y: 18, width: 9, height: 9)
        static let shadePressed = Sprite(sheet: .titlebar, x: 9, y: 18, width: 9, height: 9)
        static let unshade = Sprite(sheet: .titlebar, x: 0, y: 27, width: 9, height: 9)
        static let unshadePressed = Sprite(sheet: .titlebar, x: 9, y: 27, width: 9, height: 9)
        static let close = Sprite(sheet: .titlebar, x: 18, y: 0, width: 9, height: 9)
        static let closePressed = Sprite(sheet: .titlebar, x: 18, y: 9, width: 9, height: 9)
        static let shadePositionBackground = Sprite(sheet: .titlebar, x: 0, y: 36, width: 17, height: 7)
        static let shadePositionThumb = Sprite(sheet: .titlebar, x: 20, y: 36, width: 3, height: 7)
    }

    enum CButtons {
        static let previous = Sprite(sheet: .cbuttons, x: 0, y: 0, width: 23, height: 18)
        static let previousActive = Sprite(sheet: .cbuttons, x: 0, y: 18, width: 23, height: 18)
        static let play = Sprite(sheet: .cbuttons, x: 23, y: 0, width: 23, height: 18)
        static let playActive = Sprite(sheet: .cbuttons, x: 23, y: 18, width: 23, height: 18)
        static let pause = Sprite(sheet: .cbuttons, x: 46, y: 0, width: 23, height: 18)
        static let pauseActive = Sprite(sheet: .cbuttons, x: 46, y: 18, width: 23, height: 18)
        static let stop = Sprite(sheet: .cbuttons, x: 69, y: 0, width: 23, height: 18)
        static let stopActive = Sprite(sheet: .cbuttons, x: 69, y: 18, width: 23, height: 18)
        static let next = Sprite(sheet: .cbuttons, x: 92, y: 0, width: 23, height: 18)
        static let nextActive = Sprite(sheet: .cbuttons, x: 92, y: 18, width: 22, height: 18)
        static let eject = Sprite(sheet: .cbuttons, x: 114, y: 0, width: 22, height: 16)
        static let ejectActive = Sprite(sheet: .cbuttons, x: 114, y: 16, width: 22, height: 16)
    }

    enum ShufRep {
        static let shuffle = Sprite(sheet: .shufrep, x: 28, y: 0, width: 47, height: 15)
        static let shuffleOn = Sprite(sheet: .shufrep, x: 28, y: 30, width: 47, height: 15)
        static let repeatBtn = Sprite(sheet: .shufrep, x: 0, y: 0, width: 28, height: 15)
        static let repeatOn = Sprite(sheet: .shufrep, x: 0, y: 30, width: 28, height: 15)
        static let eqOff = Sprite(sheet: .shufrep, x: 0, y: 61, width: 23, height: 12)
        static let eqOn = Sprite(sheet: .shufrep, x: 0, y: 73, width: 23, height: 12)
        static let plOff = Sprite(sheet: .shufrep, x: 23, y: 61, width: 23, height: 12)
        static let plOn = Sprite(sheet: .shufrep, x: 23, y: 73, width: 23, height: 12)
    }

    enum Posbar {
        static let background = Sprite(sheet: .posbar, x: 0, y: 0, width: 248, height: 10)
        static let thumb = Sprite(sheet: .posbar, x: 248, y: 0, width: 29, height: 10)
    }

    enum Volume {
        /// Frame 0 of the 28-frame filmstrip (quiet). Prefer `background(forNormalized:)`.
        static let background = Sprite(sheet: .volume, x: 0, y: 0, width: 68, height: 13)
        static let thumb = Sprite(sheet: .volume, x: 15, y: 422, width: 14, height: 11)

        /// Webamp volume bar: value 0…1 → sprite 0…27 in a vertical strip of 68×13 cells (15 px stride).
        static func background(forNormalized value: Float) -> Sprite {
            let clamped = min(max(value, 0), 1)
            let number = Int((clamped * 27).rounded())
            return Sprite(sheet: .volume, x: 0, y: CGFloat(number) * 15, width: 68, height: 13)
        }
    }

    enum Balance {
        /// Frame 0 of the 28-frame filmstrip (centered). Prefer `background(forNormalized:)`.
        static let background = Sprite(sheet: .balance, x: 9, y: 0, width: 38, height: 13)
        static let thumb = Sprite(sheet: .balance, x: 15, y: 422, width: 14, height: 11)

        /// `position` is 0…1 with 0.5 = center; frame index follows distance from center (Webamp).
        static func background(forNormalized position: Float) -> Sprite {
            let fromCenter = abs(min(max(position, 0), 1) - 0.5) * 2
            let number = Int((fromCenter * 27).rounded())
            return Sprite(sheet: .balance, x: 9, y: CGFloat(number) * 15, width: 38, height: 13)
        }
    }

    enum PlayPaus {
        static let playing = Sprite(sheet: .playpaus, x: 0, y: 0, width: 9, height: 9)
        static let paused = Sprite(sheet: .playpaus, x: 9, y: 0, width: 9, height: 9)
        static let stopped = Sprite(sheet: .playpaus, x: 18, y: 0, width: 9, height: 9)
    }

    enum MonoSter {
        static let stereo = Sprite(sheet: .monoster, x: 0, y: 12, width: 29, height: 12)
        static let stereoOn = Sprite(sheet: .monoster, x: 0, y: 0, width: 29, height: 12)
        static let mono = Sprite(sheet: .monoster, x: 29, y: 12, width: 27, height: 12)
        static let monoOn = Sprite(sheet: .monoster, x: 29, y: 0, width: 27, height: 12)
    }

    enum Numbers {
        static func digit(_ char: Character) -> Sprite? {
            guard let index = char.wholeNumberValue, index >= 0, index <= 9 else { return nil }
            return Sprite(sheet: .numbers, x: CGFloat(index * 9), y: 0, width: 9, height: 13)
        }

        static let minus = Sprite(sheet: .numbers, x: 20, y: 6, width: 5, height: 1)
        static let colon = Sprite(sheet: .text, x: 12 * 5, y: 1 * 6, width: 5, height: 6) // ':' in TEXT atlas
    }

    enum EQMain {
        static let windowBackground = Sprite(sheet: .eqmain, x: 0, y: 0, width: 275, height: 116)
        /// EQMAIN below the 14px titlebar — avoids double-drawing with `titleBarSelected`.
        static let windowBody = Sprite(sheet: .eqmain, x: 0, y: 14, width: 275, height: 102)
        static let titleBar = Sprite(sheet: .eqmain, x: 0, y: 149, width: 275, height: 14)
        static let titleBarSelected = Sprite(sheet: .eqmain, x: 0, y: 134, width: 275, height: 14)
        static let on = Sprite(sheet: .eqmain, x: 10, y: 119, width: 26, height: 12)
        static let onSelected = Sprite(sheet: .eqmain, x: 69, y: 119, width: 26, height: 12)
        static let auto = Sprite(sheet: .eqmain, x: 36, y: 119, width: 32, height: 12)
        static let autoSelected = Sprite(sheet: .eqmain, x: 95, y: 119, width: 32, height: 12)
        static let presets = Sprite(sheet: .eqmain, x: 224, y: 164, width: 44, height: 12)
        static let presetsSelected = Sprite(sheet: .eqmain, x: 224, y: 176, width: 44, height: 12)
        static let graphBackground = Sprite(sheet: .eqmain, x: 0, y: 294, width: 113, height: 19)
        /// Full EQ color filmstrip (14×2 sprites). Prefer `sliderBackground(forNormalized:)`.
        static let sliderBackgroundSheet = Sprite(sheet: .eqmain, x: 13, y: 164, width: 209, height: 129)
        static let sliderThumb = Sprite(sheet: .eqmain, x: 0, y: 164, width: 11, height: 11)
        static let close = Sprite(sheet: .eqmain, x: 0, y: 116, width: 9, height: 9)
        static let closeActive = Sprite(sheet: .eqmain, x: 0, y: 125, width: 9, height: 9)

        /// Webamp `Band.tsx`: value 0…1 → sprite 0…27 in a 14-wide × 2-tall grid of 15×65 cells.
        static func sliderBackground(forNormalized value: Float) -> Sprite {
            let clamped = min(max(value, 0), 1)
            let number = Int((clamped * 27).rounded())
            let col = number % 14
            let row = number / 14
            return Sprite(
                sheet: .eqmain,
                x: 13 + CGFloat(col) * 15,
                y: 164 + CGFloat(row) * 65,
                width: 14,
                height: 63
            )
        }
    }

    enum Pledit {
        /// Full title plate including gold end-caps (caps have 1px black borders — prefer `titleLabel`).
        static let titleBar = Sprite(sheet: .pledit, x: 26, y: 0, width: 100, height: 20)
        /// Title plate inset past the black-bordered end-caps so tiling meets navy, not black squares.
        static let titleLabel = Sprite(sheet: .pledit, x: 30, y: 0, width: 92, height: 20)
        static let topLeft = Sprite(sheet: .pledit, x: 0, y: 0, width: 25, height: 20)
        static let topRight = Sprite(sheet: .pledit, x: 153, y: 0, width: 25, height: 20)
        static let topTile = Sprite(sheet: .pledit, x: 127, y: 0, width: 25, height: 20)
        /// Mid-slice of topTile (skips edge pixels) for seamless tiling.
        static let topTileSeamless = Sprite(sheet: .pledit, x: 134, y: 0, width: 12, height: 20)
        static let bottomLeft = Sprite(sheet: .pledit, x: 0, y: 72, width: 125, height: 38)
        /// bottomLeft with its leftmost 8px chrome removed (paired with `bottomLeftBorder`).
        static let bottomLeftInset = Sprite(sheet: .pledit, x: 8, y: 72, width: 117, height: 38)
        static let bottomRight = Sprite(sheet: .pledit, x: 126, y: 72, width: 150, height: 38)
        /// bottomRight with its rightmost 8px chrome removed (paired with `bottomRightBorder`).
        static let bottomRightInset = Sprite(sheet: .pledit, x: 126, y: 72, width: 142, height: 38)
        static let bottomTile = Sprite(sheet: .pledit, x: 179, y: 0, width: 25, height: 38)
        /// Left-edge chrome of bottomLeft — used to pad ADD away from the window edge.
        static let bottomLeftBorder = Sprite(sheet: .pledit, x: 0, y: 72, width: 8, height: 38)
        /// Right-edge chrome of bottomRight — used to pad LIST OPTS away from the window edge.
        static let bottomRightBorder = Sprite(sheet: .pledit, x: 268, y: 72, width: 8, height: 38)
        /// Far-right slice of `bottomRight` — resize hatch only (no scroll/LIST OPTS faces).
        static let bottomRightHatch = Sprite(sheet: .pledit, x: 251, y: 72, width: 25, height: 38)
        static let leftTile = Sprite(sheet: .pledit, x: 0, y: 42, width: 12, height: 29)
        static let rightTile = Sprite(sheet: .pledit, x: 31, y: 42, width: 20, height: 29)

        // Windowshade strip (14 px) — Webamp PLAYLIST_SHADE_* sprites.
        static let shadeLeft = Sprite(sheet: .pledit, x: 72, y: 42, width: 25, height: 14)
        static let shadeTile = Sprite(sheet: .pledit, x: 72, y: 57, width: 25, height: 14)
        /// Selected (focused) right cap — includes mini-viz + shade/close faces.
        static let shadeRight = Sprite(sheet: .pledit, x: 99, y: 42, width: 50, height: 14)
        static let shadeRightIdle = Sprite(sheet: .pledit, x: 99, y: 57, width: 50, height: 14)
        static let shadeExpand = Sprite(sheet: .pledit, x: 150, y: 42, width: 9, height: 9)
        static let shadeCollapse = Sprite(sheet: .pledit, x: 62, y: 42, width: 9, height: 9)
        static let shadeClose = Sprite(sheet: .pledit, x: 52, y: 42, width: 9, height: 9)
    }
}

struct Sprite: Hashable {
    let sheet: AmpXSkinSheet
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var rect: CGRect {
        CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
    }
}

// MARK: - Atlas loader

@MainActor
final class AmpXSkinAtlas {
    static let shared = AmpXSkinAtlas()

    private var sheets: [AmpXSkinSheet: NSImage] = [:]
    private var cache: [Sprite: NSImage] = [:]

    func image(for sprite: Sprite) -> NSImage? {
        if let cached = self.cache[sprite] {
            return cached
        }
        guard let sheet = self.loadSheet(sprite.sheet) else { return nil }
        guard let cropped = Self.crop(sheet, rect: sprite.rect) else { return nil }
        self.cache[sprite] = cropped
        return cropped
    }

    func swiftUIImage(for sprite: Sprite) -> Image? {
        guard let nsImage = self.image(for: sprite) else { return nil }
        return Image(nsImage: nsImage)
    }

    private func loadSheet(_ sheet: AmpXSkinSheet) -> NSImage? {
        if let loaded = self.sheets[sheet] {
            return loaded
        }
        guard let image = NSImage(named: sheet.rawValue) else { return nil }
        self.sheets[sheet] = image
        return image
    }

    /// Crop using Webamp's top-left sprite coordinates.
    private static func crop(_ sheet: NSImage, rect: CGRect) -> NSImage? {
        guard let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let scale = CGFloat(cgImage.height) / sheet.size.height
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }
}

// MARK: - SwiftUI views

struct SkinSpriteView: View {
    let sprite: Sprite
    var scale: CGFloat = 1.0

    var body: some View {
        if let image = AmpXSkinAtlas.shared.swiftUIImage(for: self.sprite) {
            image
                .resizable()
                .interpolation(.none)
                .frame(width: self.sprite.width * self.scale, height: self.sprite.height * self.scale)
        }
    }
}

struct AmpXSkinButton: View {
    let normal: Sprite
    let pressed: Sprite
    var scale: CGFloat = 1.0
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            self.isPressed = true
            self.action()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                self.isPressed = false
            }
        }) {
            SkinSpriteView(sprite: self.isPressed ? self.pressed : self.normal, scale: self.scale)
        }
        .buttonStyle(.plain)
    }
}

struct AmpXSkinToggle: View {
    let off: Sprite
    let on: Sprite
    @Binding var isOn: Bool
    var scale: CGFloat = 1.0

    @State private var isPressed = false

    private var active: Sprite {
        self.isOn ? self.on : self.off
    }

    var body: some View {
        Button(action: { self.isOn.toggle() }) {
            SkinSpriteView(sprite: self.active, scale: self.scale)
                .offset(y: self.isPressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in self.isPressed = true }
                .onEnded { _ in self.isPressed = false }
        )
    }
}

// MARK: - Bitmap marquee characters (TEXT.BMP, 5×6 cells)

private func classicTextSprite(row: Int, col: Int) -> Sprite {
    Sprite(sheet: .text, x: CGFloat(col) * 5, y: CGFloat(row) * 6, width: 5, height: 6)
}

struct ClassicBitmapMarquee: View {
    let text: String
    var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let glyphs = ClassicMarqueeTypography.glyphs(for: self.text)
            let periodWidth = ClassicMarqueeTypography.scrollPeriodWidth(
                glyphCount: glyphs.count,
                scale: self.scale
            )
            let needsScroll = periodWidth > geo.size.width

            Group {
                if needsScroll {
                    ClassicScrollingMarqueeStrip(
                        sequence: ClassicMarqueeTypography.scrollingSequence(glyphs: glyphs),
                        periodWidth: periodWidth,
                        scale: self.scale
                    )
                    .id(self.text)
                } else {
                    ClassicMarqueeStrip(sequence: glyphs, offset: 0, scale: self.scale)
                }
            }
        }
        .clipped()
    }
}

/// Linear wrap of a doubled glyph run. Offset animation stays on a normal View.body update,
/// not a TimelineView display-link callback.
private struct ClassicScrollingMarqueeStrip: View {
    let sequence: [Character]
    let periodWidth: CGFloat
    let scale: CGFloat

    @State private var offset: CGFloat = 0

    var body: some View {
        ClassicMarqueeStrip(sequence: self.sequence, offset: self.offset, scale: self.scale)
            .task(id: self.periodWidth) {
                self.offset = 0
                let duration = ClassicMarqueeTypography.scrollCycleDuration(
                    periodWidth: self.periodWidth,
                    scale: self.scale
                )
                guard duration > 0 else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    self.offset = -self.periodWidth
                }
            }
    }
}

private struct ClassicMarqueeStrip: View {
    let sequence: [Character]
    let offset: CGFloat
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(self.sequence.enumerated()), id: \.offset) { _, char in
                if let pos = ClassicMarqueeTypography.fontLookup[char] {
                    SkinSpriteView(
                        sprite: classicTextSprite(row: pos.row, col: pos.col),
                        scale: self.scale
                    )
                }
            }
        }
        .offset(x: self.offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ClassicBitmapTimeDisplay: View {
    let text: String
    var blinkOff: Bool = false
    var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(self.text.enumerated()), id: \.offset) { _, char in
                if char == ":" {
                    SkinSpriteView(sprite: classicTextSprite(row: 1, col: 12), scale: self.scale)
                } else if char == "-" {
                    SkinSpriteView(sprite: AmpXSkinSprites.Numbers.minus, scale: self.scale)
                        .frame(width: 5 * self.scale, height: 2 * self.scale)
                } else if let digit = AmpXSkinSprites.Numbers.digit(char) {
                    SkinSpriteView(sprite: digit, scale: self.scale)
                }
            }
        }
        .opacity(self.blinkOff ? 0.12 : 1.0)
    }
}

/// Horizontal slider using Base 2.91 track + thumb sprites.
struct ClassicBitmapHSlider: View {
    @Binding var position: Double
    let track: Sprite
    let thumb: Sprite
    var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let thumbW = self.thumb.width * self.scale
            let x = (geo.size.width - thumbW) * CGFloat(self.position)

            ZStack(alignment: .leading) {
                SkinSpriteView(sprite: self.track, scale: self.scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                SkinSpriteView(sprite: self.thumb, scale: self.scale)
                    .offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard geo.size.width > 0 else { return }
                        self.position = min(max(Double(drag.location.x / geo.size.width), 0), 1)
                    }
            )
        }
    }
}

/// Classic position bar with POSBAR sprites.
struct ClassicBitmapSeekBar: View {
    @Binding var position: Double
    var scale: CGFloat = 1.0
    let onSeek: (Double) -> Void

    @State private var dragging = false
    @State private var dragPercent: Double = 0

    var body: some View {
        GeometryReader { geo in
            let thumbW = AmpXSkinSprites.Posbar.thumb.width * self.scale
            let percent = CGFloat(self.dragging ? self.dragPercent : self.position)
            let x = max(0, min(geo.size.width - thumbW, (geo.size.width - thumbW) * percent))

            ZStack(alignment: .leading) {
                SkinSpriteView(sprite: AmpXSkinSprites.Posbar.background, scale: self.scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                SkinSpriteView(sprite: AmpXSkinSprites.Posbar.thumb, scale: self.scale)
                    .offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard geo.size.width > 0 else { return }
                        self.dragging = true
                        self.dragPercent = min(max(Double(drag.location.x / geo.size.width), 0), 1)
                    }
                    .onEnded { drag in
                        guard geo.size.width > 0 else { return }
                        let percent = min(max(Double(drag.location.x / geo.size.width), 0), 1)
                        self.onSeek(percent)
                        self.dragging = false
                    }
            )
        }
    }
}

struct ClassicBitmapPlayState: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    var scale: CGFloat = 1.0

    private var sprite: Sprite {
        if self.audioPlayer.isPlaying {
            AmpXSkinSprites.PlayPaus.playing
        } else if self.audioPlayer.duration > 0 {
            AmpXSkinSprites.PlayPaus.paused
        } else {
            AmpXSkinSprites.PlayPaus.stopped
        }
    }

    var body: some View {
        SkinSpriteView(sprite: self.sprite, scale: self.scale)
    }
}

struct ClassicBitmapMonoStereo: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            SkinSpriteView(
                sprite: self.audioPlayer.currentChannels == 1
                    ? AmpXSkinSprites.MonoSter.monoOn
                    : AmpXSkinSprites.MonoSter.mono,
                scale: self.scale
            )
            SkinSpriteView(
                sprite: self.audioPlayer.currentChannels >= 2
                    ? AmpXSkinSprites.MonoSter.stereoOn
                    : AmpXSkinSprites.MonoSter.stereo,
                scale: self.scale
            )
        }
    }
}

struct ClassicBitmapWindowButton: View {
    enum Kind { case options, minimize, shade, unshade, close }

    let kind: Kind
    var scale: CGFloat = 1.0
    let action: () -> Void

    private var sprites: (normal: Sprite, pressed: Sprite) {
        switch self.kind {
        case .options: (AmpXSkinSprites.Titlebar.options, AmpXSkinSprites.Titlebar.optionsPressed)
        case .minimize: (AmpXSkinSprites.Titlebar.minimize, AmpXSkinSprites.Titlebar.minimizePressed)
        case .shade: (AmpXSkinSprites.Titlebar.shade, AmpXSkinSprites.Titlebar.shadePressed)
        case .unshade: (AmpXSkinSprites.Titlebar.unshade, AmpXSkinSprites.Titlebar.unshadePressed)
        case .close: (AmpXSkinSprites.Titlebar.close, AmpXSkinSprites.Titlebar.closePressed)
        }
    }

    var body: some View {
        AmpXSkinButton(
            normal: self.sprites.normal,
            pressed: self.sprites.pressed,
            scale: self.scale,
            action: self.action
        )
    }
}
