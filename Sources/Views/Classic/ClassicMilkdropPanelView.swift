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

    private var s: CGFloat {
        self.uiScale
    }

    private let sideLeft: CGFloat = 12
    private let sideRight: CGFloat = 20
    private let bottomBarHeight: CGFloat = 14
    private let presetStripHeight: CGFloat = 14

    private var metalWidth: CGFloat {
        max(0, self.visualizerSize.width - (self.sideLeft + self.sideRight) * self.s)
    }

    private var metalHeight: CGFloat {
        let chrome = (ClassicSkinMetrics.playlistTopBarHeight + self.presetStripHeight + self.bottomBarHeight) * self.s
        return max(0, self.visualizerSize.height - chrome)
    }

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

                    HStack(spacing: 0) {
                        Color.clear.frame(width: self.sideLeft * self.s)
                        VStack(spacing: 0) {
                            self.presetStrip
                            MilkdropMetalVisualizationView(
                                preset: self.currentPreset,
                                size: CGSize(width: self.metalWidth, height: self.metalHeight)
                            )
                            .opacity(self.fadeOpacity)
                            .frame(width: self.metalWidth, height: self.metalHeight)
                        }
                        Color.clear.frame(width: self.sideRight * self.s)
                    }

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
        .onAppear { self.startAutoChangeTimer() }
        .onDisappear { self.stopAutoChangeTimer() }
    }

    private var presetStrip: some View {
        HStack {
            Button(action: self.previousPreset) {
                Text("◀")
                    .font(.system(size: 9 * self.s, weight: .bold))
                    .foregroundColor(ClassicSkinColors.led)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4 * self.s)

            Text("MILKDROP • \(self.currentPreset.name.uppercased())")
                .font(.system(size: 8 * self.s, weight: .bold, design: .monospaced))
                .foregroundColor(ClassicSkinColors.led)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: self.nextPreset) {
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

    private var bottomBar: some View {
        ZStack(alignment: .bottomTrailing) {
            ClassicSkinColors.body
            self.resizeGrip
                .padding(.trailing, 2 * self.s)
                .padding(.bottom, 2 * self.s)
        }
        .frame(height: self.bottomBarHeight * self.s)
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
            case .vertical:
                let tileH = max(self.sprite.height * self.scale, 1)
                let count = max(1, Int(ceil(geo.size.height / tileH)))
                VStack(spacing: 0) {
                    ForEach(0 ..< count, id: \.self) { _ in
                        SkinSpriteView(sprite: self.sprite, scale: self.scale)
                    }
                }
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
    }
}
