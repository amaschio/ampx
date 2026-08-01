import AppKit
import SwiftUI

/// Classic Winamp 2.x main window on the fixed 275×116 grid (Webamp geometry).
/// Renders the Base 2.91 skin bitmaps with dynamic overlays for time, marquee, and controls.
struct ClassicMainPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.winampUIScale) private var uiScale
    @Binding var showPlaylist: Bool
    @Binding var showEqualizer: Bool
    @Binding var isShadeMode: Bool
    @Binding var shuffleEnabled: Bool
    @Binding var repeatEnabled: Bool
    @Binding var showRemainingTime: Bool
    @Binding var showVisualization: Bool

    private var s: CGFloat {
        self.uiScale
    }

    private var displayTrack: Track? {
        self.playlistManager.currentTrack ?? self.audioPlayer.currentTrack
    }

    private var marqueeText: String {
        let artist = self.displayTrack?.artist ?? "DJ Mike Llama"
        let title = self.displayTrack?.title ?? "Llama Whippin' Intro"
        var text = "\(artist) - \(title)"
        if self.playlistManager.currentIndex >= 0 {
            text = "\(self.playlistManager.currentIndex + 1). " + text
        }
        if let duration = self.displayTrack?.duration, duration > 0 {
            text += " (\(WinampTimeFormatting.format(duration)))"
        }
        return text
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Body only — titlebar corners come solely from TITLEBAR.BMP (no MAIN double-draw).
            SkinSpriteView(sprite: WinampSkinSprites.Main.windowBody, scale: self.s)
                .classicPlaced(x: 0, y: 14, width: 275, height: 102, scale: self.s)

            ClassicMainTitleBar(
                isShadeMode: self.$isShadeMode,
                showVisualization: self.$showVisualization,
                scale: self.s
            )

            ClassicBitmapPlayState(scale: self.s)
                .classicPlaced(x: 18, y: 24, width: 9, height: 9, scale: self.s)

            ClassicBitmapTimeDisplayWrapper(showRemainingTime: self.$showRemainingTime, scale: self.s)
                .classicPlaced(x: 32, y: 22, width: 66, height: 15, scale: self.s)

            ClassicVisualizerView(onDoubleTap: { self.showVisualization.toggle() })
                .classicPlaced(x: 20, y: 41, width: 76, height: 16, scale: self.s)

            ClassicBitmapMarquee(text: self.marqueeText, scale: self.s)
                // MAIN.BMP song-title LCD well is x≈109…265, y=24…35 (12px tall).
                .classicPlaced(x: 111, y: 24, width: 154, height: 12, scale: self.s)

            ClassicLEDLabel(text: "\(self.audioPlayer.currentBitrate)", scale: self.s)
                .classicPlaced(x: 109, y: 42, width: 15, height: 8, scale: self.s)
            ClassicLEDLabel(
                text: AudioFormatInfo.sampleRateDisplayKHz(self.audioPlayer.currentSampleRate),
                scale: self.s
            )
            .classicPlaced(x: 154, y: 42, width: 12, height: 8, scale: self.s)

            ClassicBitmapMonoStereo(scale: self.s)
                .classicPlaced(x: 208, y: 41, width: 56, height: 12, scale: self.s)

            ClassicBitmapHSlider(
                position: Binding(
                    get: { Double(self.audioPlayer.volume) },
                    set: { self.audioPlayer.setVolume(Float($0)) }
                ),
                track: WinampSkinSprites.Volume.background(forNormalized: self.audioPlayer.volume),
                thumb: WinampSkinSprites.Volume.thumb,
                scale: self.s
            )
            .classicPlaced(x: 107, y: 57, width: 68, height: 13, scale: self.s)

            ClassicBitmapHSlider(
                position: Binding(
                    get: { (Double(self.audioPlayer.balance) + 1) / 2 },
                    set: { self.audioPlayer.setBalance(Float($0 * 2 - 1)) }
                ),
                track: WinampSkinSprites.Balance.background(
                    forNormalized: (self.audioPlayer.balance + 1) / 2
                ),
                thumb: WinampSkinSprites.Balance.thumb,
                scale: self.s
            )
            .classicPlaced(x: 177, y: 57, width: 38, height: 13, scale: self.s)

            WinampSkinToggle(
                off: WinampSkinSprites.ShufRep.eqOff,
                on: WinampSkinSprites.ShufRep.eqOn,
                isOn: self.$showEqualizer,
                scale: self.s
            )
            .classicPlaced(x: 219, y: 58, width: 23, height: 12, scale: self.s)

            WinampSkinToggle(
                off: WinampSkinSprites.ShufRep.plOff,
                on: WinampSkinSprites.ShufRep.plOn,
                isOn: self.$showPlaylist,
                scale: self.s
            )
            .classicPlaced(x: 242, y: 58, width: 23, height: 12, scale: self.s)

            ClassicBitmapSeekBarWrapper(scale: self.s) { percent in
                let newTime = self.audioPlayer.duration * percent
                self.audioPlayer.seek(to: max(0, min(newTime, self.audioPlayer.duration - 0.1)))
            }
            .classicPlaced(x: 16, y: 72, width: 248, height: 10, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.previous, pressed: WinampSkinSprites.CButtons.previousActive, scale: self.s) {
                self.playlistManager.previous()
            }
            .classicPlaced(x: 16, y: 88, width: 23, height: 18, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.play, pressed: WinampSkinSprites.CButtons.playActive, scale: self.s) {
                self.audioPlayer.playOrResume()
            }
            .classicPlaced(x: 39, y: 88, width: 23, height: 18, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.pause, pressed: WinampSkinSprites.CButtons.pauseActive, scale: self.s) {
                self.audioPlayer.pause()
            }
            .classicPlaced(x: 62, y: 88, width: 23, height: 18, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.stop, pressed: WinampSkinSprites.CButtons.stopActive, scale: self.s) {
                self.audioPlayer.stop()
            }
            .classicPlaced(x: 85, y: 88, width: 23, height: 18, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.next, pressed: WinampSkinSprites.CButtons.nextActive, scale: self.s) {
                self.playlistManager.next()
            }
            .classicPlaced(x: 108, y: 88, width: 22, height: 18, scale: self.s)

            WinampSkinButton(normal: WinampSkinSprites.CButtons.eject, pressed: WinampSkinSprites.CButtons.ejectActive, scale: self.s) {
                self.playlistManager.showFilePicker()
            }
            .classicPlaced(x: 136, y: 89, width: 22, height: 16, scale: self.s)

            WinampSkinToggle(
                off: WinampSkinSprites.ShufRep.shuffle,
                on: WinampSkinSprites.ShufRep.shuffleOn,
                isOn: self.$shuffleEnabled,
                scale: self.s
            )
            .classicPlaced(x: 164, y: 89, width: 47, height: 15, scale: self.s)

            WinampSkinToggle(
                off: WinampSkinSprites.ShufRep.repeatBtn,
                on: WinampSkinSprites.ShufRep.repeatOn,
                isOn: self.$repeatEnabled,
                scale: self.s
            )
            .classicPlaced(x: 211, y: 89, width: 28, height: 15, scale: self.s)
        }
        .frame(
            width: ClassicSkinMetrics.windowWidth * self.s,
            height: ClassicSkinMetrics.windowHeight * self.s
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Title bar

struct ClassicMainTitleBar: View {
    @Binding var isShadeMode: Bool
    @Binding var showVisualization: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            SkinSpriteView(sprite: WinampSkinSprites.Titlebar.barSelected, scale: self.scale)
                .allowsHitTesting(false)

            // Drag only the center strip — options + window controls stay fully uncovered.
            PanelTitleBarDragOverlay()
                .frame(width: (275 - 20 - 42) * self.scale, height: 14 * self.scale)
                .offset(x: 20 * self.scale, y: 0)

            Menu {
                Button(self.showVisualization ? "Hide Visualizer" : "Show Visualizer") {
                    self.showVisualization.toggle()
                }
            } label: {
                Color.clear
                    .frame(width: 9 * self.scale, height: 9 * self.scale)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .offset(x: 6 * self.scale, y: 3 * self.scale)

            HStack(spacing: 0) {
                Button { Self.activeWindow()?.miniaturize(nil) } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { self.isShadeMode = true } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { NSApplication.shared.terminate(nil) } label: {
                    Color.clear
                        .frame(width: 9 * self.scale, height: 9 * self.scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .offset(x: 244 * self.scale, y: 3 * self.scale)
        }
        .frame(width: 275 * self.scale, height: 14 * self.scale)
    }

    static func activeWindow() -> NSWindow? {
        if let main = WinampPanelWindowManager.shared.mainPlayerWindow {
            return main
        }
        return NSApp.windows.first { window in
            window.isVisible
                && !(window is NSPanel)
                && !WinampPanelWindowManager.shared.isPanelWindow(window)
        }
    }
}

// MARK: - Bitmap time with pause blink

private struct ClassicBitmapTimeDisplayWrapper: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    @Binding var showRemainingTime: Bool
    var scale: CGFloat = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let paused = !self.audioPlayer.isPlaying && self.audioPlayer.duration > 0
            let blinkOff = paused && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 1
            ClassicBitmapTimeDisplay(
                text: WinampTimeFormatting.format(
                    self.showRemainingTime
                        ? -(self.audioPlayer.duration - self.clock.currentTime)
                        : self.clock.currentTime,
                    showNegative: self.showRemainingTime
                ),
                blinkOff: blinkOff,
                scale: self.scale
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { self.showRemainingTime.toggle() }
    }
}

private struct ClassicBitmapSeekBarWrapper: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var clock: PlaybackClock
    var scale: CGFloat = 1.0
    let onSeek: (Double) -> Void

    var body: some View {
        ClassicBitmapSeekBar(
            position: Binding(
                get: {
                    self.audioPlayer.duration > 0
                        ? self.clock.currentTime / self.audioPlayer.duration
                        : 0
                },
                set: { _ in }
            ),
            scale: self.scale,
            onSeek: self.onSeek
        )
    }
}
