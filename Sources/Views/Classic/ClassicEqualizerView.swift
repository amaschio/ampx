import SwiftUI

/// Classic Winamp 2.x equalizer on the fixed 275×116 grid: ON/AUTO toggles,
/// preset button, response graph, and 11 vertical sliders (preamp + 10 bands).
struct ClassicEqualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Environment(\.winampUIScale) private var uiScale
    @Binding var showEqualizer: Bool
    @Binding var isMinimized: Bool

    private var s: CGFloat {
        self.uiScale
    }

    var body: some View {
        Group {
            if self.isMinimized {
                ClassicPanelTitleBar(
                    title: "WINAMP EQUALIZER",
                    scale: self.s,
                    isMinimized: self.$isMinimized,
                    onClose: { self.showEqualizer = false }
                )
            } else {
                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.EQMain.windowBody, scale: self.s)
                        .classicPlaced(x: 0, y: 14, width: 275, height: 102, scale: self.s)

                    WinampSkinToggle(
                        off: WinampSkinSprites.EQMain.on,
                        on: WinampSkinSprites.EQMain.onSelected,
                        isOn: Binding(
                            get: { self.audioPlayer.eqEnabled },
                            set: { self.audioPlayer.setEQEnabled($0) }
                        ),
                        scale: self.s
                    )
                    .classicPlaced(x: 14, y: 18, width: 26, height: 12, scale: self.s)

                    WinampSkinToggle(
                        off: WinampSkinSprites.EQMain.auto,
                        on: WinampSkinSprites.EQMain.autoSelected,
                        isOn: Binding(
                            get: { self.audioPlayer.eqAutoEnabled },
                            set: { self.audioPlayer.setEQAutoEnabled($0) }
                        ),
                        scale: self.s
                    )
                    .classicPlaced(x: 40, y: 18, width: 32, height: 12, scale: self.s)

                    SkinSpriteView(sprite: WinampSkinSprites.EQMain.graphBackground, scale: self.s)
                        .classicPlaced(x: 86, y: 17, width: 113, height: 19, scale: self.s)
                    ClassicEQGraph(
                        bandValues: self.audioPlayer.eqBandValues,
                        preampValue: self.audioPlayer.eqPreampValue
                    )
                    .classicPlaced(x: 87, y: 18, width: 111, height: 17, scale: self.s)

                    ClassicPresetsButton(scale: self.s)
                        .classicPlaced(x: 217, y: 18, width: 44, height: 12, scale: self.s)

                    ClassicEQBandSlider(
                        value: Binding(
                            get: { self.audioPlayer.eqPreampValue },
                            set: { self.audioPlayer.setEQPreamp($0) }
                        ),
                        scale: self.s
                    )
                    .classicPlaced(x: 21, y: 38, width: 14, height: 64, scale: self.s)

                    ForEach(0 ..< WinampEQBands.bandCount, id: \.self) { index in
                        ClassicEQBandSlider(
                            value: Binding(
                                get: { self.audioPlayer.eqBandValues[index] },
                                set: { self.audioPlayer.setEQBand(index, gain: $0 * 12) }
                            ),
                            scale: self.s
                        )
                        .classicPlaced(x: 78 + CGFloat(index) * 18, y: 38, width: 14, height: 64, scale: self.s)
                    }

                    ClassicPanelTitleBar(
                        title: "WINAMP EQUALIZER",
                        scale: self.s,
                        isMinimized: self.$isMinimized,
                        onClose: { self.showEqualizer = false }
                    )
                }
            }
        }
        .frame(
            width: ClassicSkinMetrics.windowWidth * self.s,
            height: self.isMinimized
                ? ClassicSkinMetrics.titleBarHeight * self.s
                : ClassicSkinMetrics.windowHeight * self.s
        )
    }
}

// MARK: - Shared classic panel title bar (EQ)

struct ClassicPanelTitleBar: View {
    let title: String
    var scale: CGFloat = 1.0
    @Binding var isMinimized: Bool
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            SkinSpriteView(sprite: WinampSkinSprites.EQMain.titleBarSelected, scale: self.scale)
                .allowsHitTesting(false)

            PanelTitleBarDragOverlay()
                .frame(width: (275 - 28) * self.scale, height: 14 * self.scale)
                .offset(x: 0, y: 0)

            HStack(spacing: 3 * self.scale) {
                Button { self.isMinimized.toggle() } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: self.onClose) {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .offset(x: (275 - 4 - 9 - 3 - 9) * self.scale, y: 3 * self.scale)
        }
        .frame(width: 275 * self.scale, height: 14 * self.scale)
        .accessibilityLabel(self.title)
    }
}

// MARK: - Presets menu

private struct ClassicPresetsButton: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    var scale: CGFloat = 1.0

    var body: some View {
        Menu {
            ForEach(self.audioPlayer.eqPresets()) { preset in
                Button(preset.name) { self.audioPlayer.applyEQPreset(preset) }
            }
            Divider()
            Button("Load EQF…") { self.audioPlayer.importEQFPresets() }
            Button("Reset") { self.audioPlayer.resetEQ() }
        } label: {
            SkinSpriteView(sprite: WinampSkinSprites.EQMain.presets, scale: self.scale)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

// MARK: - Graph

/// Yellow→orange response curve over the classic dotted grid (RE:AMP reference).
private struct ClassicEQGraph: View {
    let bandValues: [Float]
    let preampValue: Float

    var body: some View {
        Canvas { context, size in
            var midline = Path()
            var x: CGFloat = 0
            while x < size.width {
                midline.addRect(CGRect(x: x, y: size.height / 2, width: 1, height: 1))
                x += 3
            }
            context.fill(midline, with: .color(ClassicSkinColors.ledDim))

            let points = WinampEQBands.responseCurvePoints(
                bandValues: self.bandValues,
                preampValue: self.preampValue,
                width: size.width,
                height: size.height
            )
            context.stroke(
                CatmullRomSpline.path(through: points),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.85, blue: 0.1),
                        Color(red: 1, green: 0.45, blue: 0.05),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color.clear)
    }
}

// MARK: - Band slider

/// Classic vertical EQ slider: color filmstrip frame + thumb (Webamp Band.tsx).
struct ClassicEQBandSlider: View {
    /// -1…1 (bottom…top)
    @Binding var value: Float
    var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let thumbH = WinampSkinSprites.EQMain.sliderThumb.height * self.scale
            let progress = (CGFloat(self.value) + 1) / 2
            let y = (1 - progress) * (geo.size.height - thumbH)
            let track = WinampSkinSprites.EQMain.sliderBackground(forNormalized: Float(progress))

            ZStack(alignment: .top) {
                SkinSpriteView(sprite: track, scale: self.scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                SkinSpriteView(sprite: WinampSkinSprites.EQMain.sliderThumb, scale: self.scale)
                    .frame(maxWidth: .infinity)
                    .offset(y: y)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard geo.size.height > 0 else { return }
                        let p = 1 - drag.location.y / geo.size.height
                        self.value = Float(min(max(p, 0), 1) * 2 - 1)
                    }
            )
        }
    }
}
