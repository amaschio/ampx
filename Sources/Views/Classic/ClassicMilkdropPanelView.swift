import AppKit
import SwiftUI

/// Classic managed MilkDrop panel: pledit-style chrome, preset strip, Metal body, BR resize.
struct ClassicMilkdropPanelView: View {
    @Environment(\.winampUIScale) private var uiScale
    @Binding var visualizerSize: CGSize
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool

    @State private var currentPreset: VisualizationPreset = .kaleidoscope
    @State private var autoChangeTimer: Timer?
    @State private var fadeOpacity: Double = 1.0
    @State private var isDraggingResize = false
    @State private var resizeStartSize: CGSize = .zero
    // Default Enthea for Task 2+ smoke; Metal remains available via the strip.
    // (Plan flipped this at Task 3; brought forward so panel open shows the WebView host.)
    @State private var bodyMode: EntheaBodyMode = .enthea
    @State private var showPhotosensitiveWarning = false
    @StateObject private var entheaController = EntheaPanelController()
    private let entheaPreferences = EntheaPreferences()

    private var s: CGFloat {
        self.uiScale
    }

    private let sideLeft: CGFloat = 12
    private let sideRight: CGFloat = 20
    /// Match playlist pledit bottom chrome (sprites are 38px tall) — the old 14pt
    /// flat `Color` bar looked unfinished and hid the mode switch.
    private var bottomBarHeight: CGFloat { ClassicSkinMetrics.playlistBottomBarHeight }
    private let presetStripHeight: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            if self.isMinimized {
                ClassicMilkdropShadeBar(
                    isMinimized: self.$isMinimized,
                    showVisualizer: self.$showVisualizer,
                    scale: self.s
                )
            } else {
                HStack(spacing: 0) {
                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.leftTile,
                        scale: self.s,
                        axis: .vertical
                    )
                    .frame(width: self.sideLeft * self.s)
                    .frame(maxHeight: .infinity)

                    Spacer(minLength: 0)

                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.rightTile,
                        scale: self.s,
                        axis: .vertical
                    )
                    .frame(width: self.sideRight * self.s)
                    .frame(maxHeight: .infinity)
                }

                VStack(spacing: 0) {
                    ClassicMilkdropTitleBar(
                        isMinimized: self.$isMinimized,
                        showVisualizer: self.$showVisualizer,
                        scale: self.s
                    )

                    // Fill remaining height *above* the bottom bar so the bar is never clipped.
                    HStack(spacing: 0) {
                        Color.clear.frame(width: self.sideLeft * self.s)
                        VStack(spacing: 0) {
                            self.presetStrip
                            GeometryReader { geo in
                                Group {
                                    if self.bodyMode == .enthea {
                                        EntheaWebView(
                                            isActive: self.showVisualizer && !self.isMinimized,
                                            size: geo.size,
                                            controller: self.entheaController
                                        )
                                    } else {
                                        MilkdropMetalVisualizationView(
                                            preset: self.currentPreset,
                                            size: geo.size
                                        )
                                        .opacity(self.fadeOpacity)
                                    }
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Color.clear.frame(width: self.sideRight * self.s)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    self.bottomBar
                }
            }
        }
        .background(self.isMinimized ? Color.clear : ClassicSkinColors.body)
        .frame(
            width: self.visualizerSize.width,
            height: self.isMinimized
                ? ClassicSkinMetrics.playlistShadeHeight * self.s
                : self.visualizerSize.height
        )
        .clipped()
        .onAppear {
            self.startAutoChangeTimer()
            if self.bodyMode == .enthea, !self.entheaPreferences.photosensitiveWarningAccepted {
                self.showPhotosensitiveWarning = true
            }
        }
        .onChange(of: self.bodyMode) { mode in
            if mode == .enthea, !self.entheaPreferences.photosensitiveWarningAccepted {
                self.showPhotosensitiveWarning = true
            }
        }
        .alert("Photosensitivity notice", isPresented: self.$showPhotosensitiveWarning) {
            Button("OK") {
                self.entheaPreferences.photosensitiveWarningAccepted = true
            }
        } message: {
            Text(
                "ENTHEA includes bright, rapidly changing patterns. If you have photosensitive epilepsy or migraines, switch back to Metal or close the Visualizer. Flicker drive stays off unless you enable it later."
            )
        }
        .onDisappear { self.stopAutoChangeTimer() }
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
                Text(self.presetStripTitle)
                    .font(.system(size: 8 * self.s, weight: .bold, design: .monospaced))
                    .foregroundColor(ClassicSkinColors.led)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if self.bodyMode == .enthea {
                        self.entheaController.reseed()
                    }
                }
            )

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

    private var presetStripTitle: String {
        switch self.bodyMode {
        case .metal:
            return "MILKDROP • \(self.currentPreset.name.uppercased())"
        case .enthea:
            return self.entheaController.stripTitle
        }
    }

    private func stripPrevious() {
        switch self.bodyMode {
        case .metal:
            self.previousPreset()
        case .enthea:
            if NSEvent.modifierFlags.contains(.shift) {
                self.entheaController.nudgeDose(-0.05)
            } else {
                self.entheaController.previousMode()
            }
        }
    }

    private func stripNext() {
        switch self.bodyMode {
        case .metal:
            self.nextPreset()
        case .enthea:
            if NSEvent.modifierFlags.contains(.shift) {
                self.entheaController.nudgeDose(0.05)
            } else {
                self.entheaController.nextMode()
            }
        }
    }

    private func stripTitleAction() {
        guard self.bodyMode == .enthea else { return }
        self.entheaController.toggleAutopilot()
    }

    /// Same pledit bottom geometry as the playlist: border · inset · tile · inset · border.
    /// Full-height tile covers hide playlist faces; native hatch remains on the right.
    private var bottomBar: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomLeftBorder, scale: self.s)

                ZStack(alignment: .bottomLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomLeftInset, scale: self.s)
                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 117 * self.s, height: self.bottomBarHeight * self.s)
                    self.bodyModeSwitch
                        .padding(.leading, 6 * self.s)
                        .padding(.bottom, 12 * self.s)
                }
                .frame(width: 117 * self.s, height: self.bottomBarHeight * self.s)
                .clipped()

                ClassicMilkdropTiledStrip(
                    sprite: WinampSkinSprites.Pledit.bottomTile,
                    scale: self.s,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)
                .frame(height: self.bottomBarHeight * self.s)

                // Full bottomRight (150) so hatch+border stay one skin piece.
                // Cover only button faces — leave hatch chrome/bevel untouched.
                ZStack(alignment: .topLeading) {
                    SkinSpriteView(sprite: WinampSkinSprites.Pledit.bottomRight, scale: self.s)
                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 100 * self.s, height: self.bottomBarHeight * self.s)
                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.bottomTile,
                        scale: self.s,
                        axis: .horizontal
                    )
                    .frame(width: 44 * self.s, height: 28 * self.s)
                    .offset(x: 102 * self.s, y: 5 * self.s)
                    ClassicMilkdropTiledStrip(
                        sprite: WinampSkinSprites.Pledit.bottomTile,
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

    /// Task 1–5 migration control — LED-style inset like the playlist time readout.
    private var bodyModeSwitch: some View {
        HStack(spacing: 4 * self.s) {
            self.bodyModeButton(.metal, label: "METAL")
            Text("|")
                .font(.system(size: 9 * self.s, weight: .bold, design: .monospaced))
                .foregroundColor(ClassicSkinColors.led.opacity(0.45))
            self.bodyModeButton(.enthea, label: "ENTHEA")
        }
        .padding(.horizontal, 5 * self.s)
        .padding(.vertical, 2 * self.s)
        .background(Color.black)
        .frame(height: 14 * self.s)
        .clipped()
    }

    private func bodyModeButton(_ mode: EntheaBodyMode, label: String) -> some View {
        Button(action: { self.bodyMode = mode }) {
            Text(label)
                .font(.system(size: 9 * self.s, weight: .bold, design: .monospaced))
                .foregroundColor(
                    self.bodyMode == mode
                        ? ClassicSkinColors.led
                        : ClassicSkinColors.led.opacity(0.4)
                )
        }
        .buttonStyle(.plain)
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
                        let minHeight = WinampMetrics.visualizerMinHeight * self.s
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

    private func nextPreset() {
        self.stopAutoChangeTimer()
        self.changePresetWithFade(direction: 1)
        self.startAutoChangeTimer()
    }

    private func previousPreset() {
        self.stopAutoChangeTimer()
        self.changePresetWithFade(direction: -1)
        self.startAutoChangeTimer()
    }

    private func changePresetWithFade(direction: Int) {
        withAnimation(.easeOut(duration: 0.5)) {
            self.fadeOpacity = 0.0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.currentPreset = self.currentPreset.advanced(by: direction)
            withAnimation(.easeIn(duration: 0.5)) {
                self.fadeOpacity = 1.0
            }
        }
    }

    private func startAutoChangeTimer() {
        self.autoChangeTimer?.invalidate()
        self.autoChangeTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.changePresetWithFade(direction: 1)
            }
        }
    }

    private func stopAutoChangeTimer() {
        self.autoChangeTimer?.invalidate()
        self.autoChangeTimer = nil
    }
}

// MARK: - Title / shade

private struct ClassicMilkdropTitleBar: View {
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.topLeft, scale: self.scale)

                ClassicMilkdropTiledStrip(
                    sprite: WinampSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )

                Text("MILKDROP")
                    .font(.system(size: 9 * self.scale, weight: .bold, design: .monospaced))
                    .foregroundColor(ClassicSkinColors.led)
                    .padding(.horizontal, 6 * self.scale)

                ClassicMilkdropTiledStrip(
                    sprite: WinampSkinSprites.Pledit.topTileSeamless,
                    scale: self.scale,
                    axis: .horizontal
                )

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.topRight, scale: self.scale)
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
        .frame(height: ClassicSkinMetrics.playlistTopBarHeight * self.scale)
        .background(ClassicSkinColors.body)
        .accessibilityLabel("MILKDROP")
    }
}

private struct ClassicMilkdropShadeBar: View {
    @Binding var isMinimized: Bool
    @Binding var showVisualizer: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SkinSpriteView(sprite: WinampSkinSprites.Pledit.shadeLeft, scale: self.scale)

                ClassicMilkdropTiledStrip(
                    sprite: WinampSkinSprites.Pledit.shadeTile,
                    scale: self.scale,
                    axis: .horizontal
                )
                .frame(maxWidth: .infinity)
                .frame(height: ClassicSkinMetrics.playlistShadeHeight * self.scale)

                SkinSpriteView(sprite: WinampSkinSprites.Pledit.shadeRight, scale: self.scale)
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
        .accessibilityLabel("MILKDROP")
    }
}

// MARK: - Tiling

private enum ClassicMilkdropTileAxis {
    case horizontal
    case vertical
}

private struct ClassicMilkdropTiledStrip: View {
    let sprite: Sprite
    var scale: CGFloat = 1.0
    var axis: ClassicMilkdropTileAxis = .horizontal

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
        // Yield to fixed-width pledit corners (matches ClassicPlaylistTiledStrip).
        .layoutPriority(-1)
    }
}
