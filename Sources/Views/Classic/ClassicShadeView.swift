import SwiftUI

/// Classic windowshade: the main window collapsed to a single 275×14 title strip.
///
/// Faces (marquee chrome, transport, window controls) are baked into `shadeBarSelected`.
/// Only clear hit targets sit on top so we don't redraw 9×9 / 23×18 sprites into the 14 px strip.
struct ClassicShadeView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.winampUIScale) private var uiScale
    @Binding var isShadeMode: Bool
    @Binding var showRemainingTime: Bool
    @Binding var showVisualization: Bool

    private var s: CGFloat {
        self.uiScale
    }

    private var displayTrack: Track? {
        self.playlistManager.currentTrack ?? self.audioPlayer.currentTrack
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SkinSpriteView(sprite: AmpXSkinSprites.Titlebar.shadeBarSelected, scale: self.s)
                .allowsHitTesting(false)

            // Drag / double-click only over the marquee — transport + window icons stay clickable.
            // Double-click while shaded intentionally does nothing (unshade via middle icon).
            PanelTitleBarDragOverlay()
                .frame(width: 105 * self.s, height: 14 * self.s)
                .offset(x: 16 * self.s, y: 0)

            Menu {
                Button(self.showVisualization ? "Hide Visualizer" : "Show Visualizer") {
                    self.showVisualization.toggle()
                }
            } label: {
                Color.clear
                    .frame(width: 9 * self.s, height: 9 * self.s)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .offset(x: 6 * self.s, y: 3 * self.s)

            ClassicBitmapMarquee(
                text: "\(self.displayTrack?.artist ?? "DJ Mike Llama") - \(self.displayTrack?.title ?? "Llama Whippin' Intro")",
                scale: self.s
            )
            .allowsHitTesting(false)
            .frame(width: 105 * self.s, height: 8 * self.s)
            .offset(x: 16 * self.s, y: 3 * self.s)

            ClassicShadeTime(showRemainingTime: self.$showRemainingTime, scale: self.s)
                .frame(width: 40 * self.s, height: 8 * self.s)
                .offset(x: 127 * self.s, y: 3 * self.s)

            // Shade transport faces are painted into TITLEBAR.BMP — clear 9×9 hit targets only.
            ClassicShadeHitTarget(scale: self.s) { self.playlistManager.previous() }
                .offset(x: 169 * self.s, y: 2.5 * self.s)
            ClassicShadeHitTarget(scale: self.s) { self.audioPlayer.playOrResume() }
                .offset(x: 179 * self.s, y: 2.5 * self.s)
            ClassicShadeHitTarget(scale: self.s) { self.audioPlayer.pause() }
                .offset(x: 189 * self.s, y: 2.5 * self.s)
            ClassicShadeHitTarget(scale: self.s) { self.audioPlayer.stop() }
                .offset(x: 199 * self.s, y: 2.5 * self.s)
            ClassicShadeHitTarget(scale: self.s) { self.playlistManager.next() }
                .offset(x: 209 * self.s, y: 2.5 * self.s)

            ClassicShadeSeek(scale: self.s)
                .frame(width: 17 * self.s, height: 7 * self.s)
                .offset(x: 222 * self.s, y: 3.5 * self.s)

            ClassicShadeHitTarget(scale: self.s) {
                ClassicMainTitleBar.activeWindow()?.miniaturize(nil)
            }
            .offset(x: 244 * self.s, y: 2.5 * self.s)

            // Middle windowshade icon — the only way to expand from shade mode.
            ClassicShadeHitTarget(scale: self.s) {
                self.isShadeMode = false
            }
            .offset(x: 254 * self.s, y: 2.5 * self.s)

            ClassicShadeHitTarget(scale: self.s) {
                NSApplication.shared.terminate(nil)
            }
            .offset(x: 264 * self.s, y: 2.5 * self.s)
        }
        .frame(
            width: ClassicSkinMetrics.windowWidth * self.s,
            height: ClassicSkinMetrics.shadeHeight * self.s
        )
    }
}

private struct ClassicShadeHitTarget: View {
    var scale: CGFloat = 1.0
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Color.clear
                .frame(width: 9 * self.scale, height: 9 * self.scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ClassicShadeTime: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    @Binding var showRemainingTime: Bool
    var scale: CGFloat = 1.0

    private var timeText: String {
        AmpXTimeFormatting.format(
            self.showRemainingTime
                ? -(self.audioPlayer.duration - self.clock.currentTime)
                : self.clock.currentTime,
            showNegative: self.showRemainingTime
        )
    }

    var body: some View {
        // Shade strip is 14 px — use 5×6 TEXT.BMP glyphs, not 9×13 NUMBERS.
        HStack(spacing: 0) {
            ForEach(Array(self.timeText.lowercased().enumerated()), id: \.offset) { _, char in
                if let pos = ClassicMarqueeTypography.fontLookup[char] {
                    SkinSpriteView(
                        sprite: Sprite(sheet: .text, x: CGFloat(pos.col) * 5, y: CGFloat(pos.row) * 6, width: 5, height: 6),
                        scale: self.scale
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { self.showRemainingTime.toggle() }
    }
}

private struct ClassicShadeSeek: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let percent = CGFloat(self.audioPlayer.duration > 0
                ? self.clock.currentTime / self.audioPlayer.duration : 0)
            let thumbW = AmpXSkinSprites.Titlebar.shadePositionThumb.width * self.scale
            ZStack(alignment: .leading) {
                SkinSpriteView(sprite: AmpXSkinSprites.Titlebar.shadePositionBackground, scale: self.scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                SkinSpriteView(sprite: AmpXSkinSprites.Titlebar.shadePositionThumb, scale: self.scale)
                    .offset(x: (geo.size.width - thumbW) * percent)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { drag in
                        guard geo.size.width > 0, self.audioPlayer.duration > 0 else { return }
                        let percent = min(max(Double(drag.location.x / geo.size.width), 0), 1)
                        self.audioPlayer.seek(to: self.audioPlayer.duration * percent)
                    }
            )
        }
    }
}
