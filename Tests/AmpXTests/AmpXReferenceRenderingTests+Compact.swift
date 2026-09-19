@testable import AmpX
import AppKit
import XCTest

extension AmpXReferenceRenderingTests {
    func testCompactEqualizerCapturesAtAllScales() throws {
        let audio = AudioPlayer(installRemoteCommands: false)
        let equalizer = EqualizerCompactContent(skin: ClassicModernSkin(), audioPlayer: audio)
        equalizer.frame = CGRect(x: 0, y: 0, width: 490, height: AmpXCompactMetrics.equalizerHeight)
        equalizer.volumeSlider.displayValueOverride = 0.7
        equalizer.balanceSlider.displayValueOverride = 0.7
        for scale: CGFloat in [1, 2, 3] {
            let png = try AmpXCompactCaptureSupport.capture(equalizer, scale: scale)
            XCTAssertEqual(png, try AmpXCompactCaptureSupport.capture(equalizer, scale: scale))
            try self.export(png, named: "compact-equalizer-\(Int(scale))x.png", backingScale: scale)
        }
    }

    func testCompactPlayerProductionCapturesAreDeterministic() throws {
        let suite = "AmpXCompactCapture.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AmpXPlayerPresentationState(store: .init(defaults: defaults))
        let audio = AudioPlayer(installRemoteCommands: false)
        let playlist = PlaylistManager(audioPlayer: MockAudioPlayer(), restoreBookmarks: false,
                                       restorePlaylist: false, alertPresenter: SilentPlaylistAlertPresenter())
        let player = PlayerCompactContent(skin: ClassicModernSkin(), audioPlayer: audio, playlistManager: playlist,
                                          presentationState: state, onToggleModule: { _ in })
        player.frame = CGRect(x: 0, y: 0, width: 490, height: AmpXCompactMetrics.playerHeight)
        player.timeDisplay.referenceText = "01:51"
        player.transportButtons[1].displayActiveOverride = true
        let settings = AmpXMiniVisualizerSettings(style: .dotSpectrum, palette: .classic)
        for scale: CGFloat in [1, 2, 3] {
            let first = try AmpXCompactCaptureSupport.capture(player, scale: scale, visualizer: player.spectrumWell,
                                                              frame: AmpXCompactCaptureSupport.signal, settings: settings)
            let second = try AmpXCompactCaptureSupport.capture(player, scale: scale, visualizer: player.spectrumWell,
                                                               frame: AmpXCompactCaptureSupport.signal, settings: settings)
            XCTAssertEqual(first, second)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: first))
            let rect = player.spectrumWell.frame
            var greenPixels = 0
            for y in Int(rect.minY * scale) ..< Int(rect.maxY * scale) {
                for x in Int(rect.minX * scale) ..< Int(rect.maxX * scale) {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    if color.greenComponent > 0.4 && color.blueComponent < 0.2 { greenPixels += 1 }
                }
            }
            XCTAssertGreaterThan(greenPixels, 20, "Composited spectrum must contain the supplied signal")
            try self.export(first, named: "compact-player-\(Int(scale))x.png", backingScale: scale)
        }
        XCTAssertNil(defaults.string(forKey: "miniVisualizer.style"), "Capture choices must not persist")
    }
}
