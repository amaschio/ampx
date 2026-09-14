import AppKit
import SwiftUI

/// Layout policy for the visualizer panel body.
///
/// Theater ↔ docked must share one mounted ENTHEA/`WKWebView` body. Branching
/// `vizBody` into separate `if isTheater` / `else` trees remounts the representable and
/// resets in-page settings (mic sensitivity, reactivity, etc.) to defaults.
enum ClassicVisualizerPanelMounting {
    /// Shade/minimize tears the body down; theater does not.
    static func isBodyMounted(minimized: Bool, theater _: Bool) -> Bool {
        !minimized
    }

    /// Insets that leave room for pledit chrome around the body when docked.
    static func contentInsets(
        isTheater: Bool,
        scale: CGFloat,
        sideLeft: CGFloat,
        sideRight: CGFloat,
        topBarHeight: CGFloat,
        presetStripHeight: CGFloat,
        bottomBarHeight: CGFloat
    ) -> EdgeInsets {
        if isTheater { return EdgeInsets() }
        return EdgeInsets(
            top: (topBarHeight + presetStripHeight) * scale,
            leading: sideLeft * scale,
            bottom: bottomBarHeight * scale,
            trailing: sideRight * scale
        )
    }
}

/// Classic managed visualizer panel: pledit chrome, ENTHEA body, theater, BR resize.
struct ClassicVisualizerPanelView: View {
    @Environment(\.winampUIScale) private var uiScale
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Binding var visualizerSize: CGSize
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool
    @Binding var isTheater: Bool
    /// Window content size (docked `visualizerSize`, or theater fill).
    var displaySize: CGSize

    @State private var isDraggingResize = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var showPhotosensitiveWarning = false
    @StateObject private var entheaController = EntheaPanelController()
    private let entheaPreferences = EntheaPreferences()

    private var s: CGFloat {
        self.uiScale
    }

    private let sideLeft: CGFloat = 12
    private let sideRight: CGFloat = 20
    private var bottomBarHeight: CGFloat { ClassicSkinMetrics.playlistBottomBarHeight }
    private let presetStripHeight: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            if ClassicVisualizerPanelMounting.isBodyMounted(
                minimized: self.isMinimized,
                theater: self.isTheater
            ) {
                // One body instance for docked + theater — do not branch vizBody.
                self.vizBody
                    .padding(self.bodyInsets)
                    .accessibilityHint(self.isTheater ? "Press Escape or F to exit theater" : "")

                if !self.isTheater {
                    self.dockedChrome
                }
            } else {
                ClassicVisualizerShadeBar(
                    isMinimized: self.$isMinimized,
                    showVisualizer: self.$showVisualizer,
                    title: "ENTHEA",
                    scale: self.s
                )
            }
        }
        .background(self.isMinimized || self.isTheater ? Color.black : ClassicSkinColors.body)
        .frame(
            width: self.displaySize.width,
            height: self.isMinimized
                ? ClassicSkinMetrics.playlistShadeHeight * self.s
                : self.displaySize.height
        )
        .clipped()
        .onAppear {
            if !self.entheaPreferences.photosensitiveWarningAccepted {
                self.showPhotosensitiveWarning = true
            }
        }
        .alert("Photosensitivity notice", isPresented: self.$showPhotosensitiveWarning) {
            Button("OK") {
                self.entheaPreferences.photosensitiveWarningAccepted = true
            }
        } message: {
            Text(
                "ENTHEA includes bright, rapidly changing patterns. If you have photosensitive epilepsy or migraines, close the Visualizer. Flicker drive stays off unless you enable it later."
            )
        }
    }

    private var bodyInsets: EdgeInsets {
        ClassicVisualizerPanelMounting.contentInsets(
            isTheater: self.isTheater,
            scale: self.s,
            sideLeft: self.sideLeft,
            sideRight: self.sideRight,
            topBarHeight: ClassicSkinMetrics.playlistTopBarHeight,
            presetStripHeight: self.presetStripHeight,
            bottomBarHeight: self.bottomBarHeight
        )
    }

    /// Pledit chrome drawn around (not instead of) the stable viz body.
    private var dockedChrome: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.leftTile,
                    scale: self.s,
                    axis: .vertical
                )
                .frame(width: self.sideLeft * self.s)
                .frame(maxHeight: .infinity)

                Spacer(minLength: 0)

                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.rightTile,
                    scale: self.s,
                    axis: .vertical
                )
                .frame(width: self.sideRight * self.s)
                .frame(maxHeight: .infinity)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                ClassicVisualizerTitleBar(
                    isMinimized: self.$isMinimized,
                    showVisualizer: self.$showVisualizer,
                    title: "ENTHEA",
                    scale: self.s,
                    onTheater: { AmpXPanelWindowManager.shared.toggleVisualizerTheater() }
                )

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: self.sideLeft * self.s)
                        .allowsHitTesting(false)
                    VStack(spacing: 0) {
                        self.presetStrip
                        Spacer(minLength: 0)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Color.clear
                        .frame(width: self.sideRight * self.s)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                self.bottomBar
            }
        }
    }

    private var vizBody: some View {
        GeometryReader { geo in
            Group {
                if EntheaWebViewLaunch.isRunningUnderTest {
                    Color.black
                } else {
                    EntheaWebView(
                        isActive: self.showVisualizer && !self.isMinimized,
                        size: geo.size,
                        isTheater: self.isTheater,
                        trackURL: self.audioPlayer.currentTrack?.url,
                        currentTime: self.audioPlayer.currentTime,
                        isPlaying: self.audioPlayer.isPlaying,
                        controller: self.entheaController
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var presetStrip: some View {
        HStack {
            Button(action: self.stripPrevious) {
                Text("◀")
                    .font(.system(size: 9 * self.s, weight: .bold))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4 * self.s)

            Button(action: self.stripTitleAction) {
                Text(self.entheaController.stripTitle)
                    .font(.system(size: 8 * self.s, weight: .bold, design: .monospaced))
                    .foregroundColor(ClassicSkinColors.led)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    self.entheaController.reseed()
                }
            )

            Menu {
                Text("Looks — artistic interpretations")
                    .font(.caption)
                ForEach(EntheaLookPreset.all) { preset in
                    Button(preset.title) {
                        self.entheaController.applyLook(preset)
                    }
                    .help(preset.blurb)
                }
            } label: {
                Text("LOOKS")
                    .font(.system(size: 8 * self.s, weight: .bold, design: .monospaced))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .help(EntheaLookPreset.disclaimer)
            .padding(.horizontal, 2 * self.s)

            Button {
                self.entheaController.fireDrop()
            } label: {
                Text("💥")
                    .font(.system(size: 9 * self.s, weight: .bold))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .buttonStyle(.plain)
            .help("Force drop effect")
            .padding(.horizontal, 2 * self.s)

            Button {
                AmpXPanelWindowManager.shared.toggleVisualizerTheater()
            } label: {
                Text(self.isTheater ? "▣" : "⛶")
                    .font(.system(size: 9 * self.s, weight: .bold))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .buttonStyle(.plain)
            .help("Theater mode (F)")
            .padding(.horizontal, 4 * self.s)

            Button(action: self.stripNext) {
                Text("▶")
                    .font(.system(size: 9 * self.s, weight: .bold))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4 * self.s)
        }
        .padding(.horizontal, 4 * self.s)
        .frame(height: self.presetStripHeight * self.s)
        .background(ClassicSkinColors.displayBg)
    }

    private func stripPrevious() {
        if NSEvent.modifierFlags.contains(.shift) {
            self.entheaController.nudgeDose(-0.05)
        } else {
            self.entheaController.previousMode()
        }
    }

    private func stripNext() {
        if NSEvent.modifierFlags.contains(.shift) {
            self.entheaController.nudgeDose(0.05)
        } else {
            self.entheaController.nextMode()
        }
    }

    private func stripTitleAction() {
        self.entheaController.toggleAutopilot()
    }

    /// Pledit bottom geometry: border · inset · tile · inset · border.
    private var bottomBar: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: AmpXSkinSprites.Pledit.bottomLeftBorder, scale: self.s)

                ZStack(alignment: .bottomLeading) {
                    SkinSpriteView(sprite: AmpXSkinSprites.Pledit.bottomLeftInset, scale: self.s)
                    ClassicVisualizerTiledStrip(
                        sprite: AmpXSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 117 * self.s, height: self.bottomBarHeight * self.s)
                }
                .frame(width: 117 * self.s, height: self.bottomBarHeight * self.s)
                .clipped()

                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.bottomTile,
                    scale: self.s,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)
                .frame(height: self.bottomBarHeight * self.s)

                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: AmpXSkinSprites.Pledit.bottomRight, scale: self.s)
                    ClassicVisualizerTiledStrip(
                        sprite: AmpXSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 100 * self.s, height: self.bottomBarHeight * self.s)
                    ClassicVisualizerTiledStrip(
                        sprite: AmpXSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 44 * self.s, height: 28 * self.s)
                    .offset(x: 102 * self.s, y: 5 * self.s)
                    ClassicVisualizerTiledStrip(
                        sprite: AmpXSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 15 * self.s, height: 18 * self.s)
                    .offset(x: 128 * self.s, y: 3 * self.s)
                }
                .frame(width: 150 * self.s, height: self.bottomBarHeight * self.s)
                .clipped()
            }

            self.resizeGrip
        }
        .frame(maxWidth: .infinity)
        .frame(height: self.bottomBarHeight * self.s)
        .background(ClassicSkinColors.body)
        .contentShape(Rectangle())
    }

    private var resizeGrip: some View {
        Color.clear
            .frame(width: 12 * self.s, height: 12 * self.s)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !self.isDraggingResize {
                            self.resizeStartSize = self.visualizerSize
                            self.isDraggingResize = true
                        }
                        let minWidth = ClassicSkinMetrics.windowWidth * self.s
                        let minHeight = AmpXMetrics.visualizerMinHeight * self.s
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.visualizerSize = CGSize(
                                width: max(minWidth, self.resizeStartSize.width + value.translation.width),
                                height: max(minHeight, self.resizeStartSize.height + value.translation.height)
                            )
                        }
                    }
                    .onEnded { _ in self.isDraggingResize = false }
            )
    }
}

// MARK: - Title / shade

private struct ClassicVisualizerTitleBar: View {
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool
    var title: String
    var scale: CGFloat = 1.0
    var onTheater: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: AmpXSkinSprites.Pledit.topLeft, scale: self.scale)

                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )

                Text(self.title)
                    .font(.system(size: 9 * self.scale, weight: .bold, design: .monospaced))
                    .foregroundColor(ClassicSkinColors.led)
                    .padding(.horizontal, 6 * self.scale)

                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )

                SkinSpriteView(sprite: AmpXSkinSprites.Pledit.topRight, scale: self.scale)
            }
            .allowsHitTesting(false)

            PanelTitleBarDragOverlay()
                .padding(.trailing, 40 * self.scale)

            HStack(spacing: 3 * self.scale) {
                Spacer(minLength: 0)
                Button(action: self.onTheater) {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Theater mode (F)")

                Button { self.isMinimized.toggle() } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { self.showVisualizer = false } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4 * self.scale)
            .padding(.top, 3 * self.scale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ClassicSkinMetrics.playlistTopBarHeight * self.scale)
        .background(ClassicSkinColors.body)
        .accessibilityLabel(self.title)
    }
}

private struct ClassicVisualizerShadeBar: View {
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool
    var title: String
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: AmpXSkinSprites.Pledit.shadeLeft, scale: self.scale)

                ClassicVisualizerTiledStrip(
                    sprite: AmpXSkinSprites.Pledit.shadeTile,
                    scale: self.scale,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)
                .frame(height: ClassicSkinMetrics.playlistShadeHeight * self.scale)

                SkinSpriteView(sprite: AmpXSkinSprites.Pledit.shadeRight, scale: self.scale)
            }
            .allowsHitTesting(false)

            PanelTitleBarDragOverlay()
                .padding(.trailing, 28 * self.scale)

            HStack(spacing: 3 * self.scale) {
                Spacer(minLength: 0)
                Button { self.isMinimized.toggle() } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { self.showVisualizer = false } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 4 * self.scale)
            .padding(.top, 3 * self.scale)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ClassicSkinMetrics.playlistShadeHeight * self.scale)
        .accessibilityLabel(self.title)
    }
}

// MARK: - Tiling

private enum ClassicVisualizerTileAxis {
    case horizontal
    case vertical
}

private struct ClassicVisualizerTiledStrip: View {
    let sprite: Sprite
    var scale: CGFloat = 1.0
    var axis: ClassicVisualizerTileAxis = .horizontal

    var body: some View {
        GeometryReader { geo in
            switch self.axis {
            case .horizontal:
                let tileW = max(self.sprite.width * self.scale, 1)
                let count = max(1, Int(ceil(geo.size.width / tileW)))
                HStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            case .vertical:
                let tileH = max(self.sprite.height * self.scale, 1)
                let count = max(1, Int(ceil(geo.size.height / tileH)))
                VStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .frame(
            maxWidth: self.axis == .horizontal ? .infinity : nil,
            maxHeight: self.axis == .vertical ? .infinity : nil
        )
        .frame(
            width: self.axis == .vertical ? self.sprite.width * self.scale : nil,
            height: self.axis == .horizontal ? self.sprite.height * self.scale : nil
        )
        .clipped()
        .layoutPriority(-1)
    }
}
