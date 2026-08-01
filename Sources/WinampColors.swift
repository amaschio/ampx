import AppKit
import SwiftUI

enum WinampColors {
    /// RE:AMP skin palette — blue-grey metallic chrome with gold title ornaments and neon-green LCD.
    static let background = Color(red: 0, green: 0, blue: 0)

    // Title bar (steel-blue chrome)
    static let titleBar = Color(red: 58 / 255, green: 66 / 255, blue: 90 / 255)
    static let nsTitleBar = NSColor(red: 58 / 255, green: 66 / 255, blue: 90 / 255, alpha: 1)
    static let titleBarInactive = Color(red: 48 / 255, green: 54 / 255, blue: 72 / 255)
    static let titleBarHighlight = Color(red: 82 / 255, green: 90 / 255, blue: 114 / 255)

    // Gold/olive title-bar ornament stripes (RE:AMP reference)
    static let ornamentGold = Color(red: 196 / 255, green: 168 / 255, blue: 72 / 255)
    static let ornamentGoldDark = Color(red: 120 / 255, green: 100 / 255, blue: 36 / 255)
    static let ornamentGoldLight = Color(red: 228 / 255, green: 204 / 255, blue: 108 / 255)

    // Display/LCD (neon green on near-black)
    static let displayBg = Color(red: 4 / 255, green: 12 / 255, blue: 8 / 255)
    static let displayText = Color(red: 0, green: 1.0, blue: 0.45)
    static let displayInactive = Color(red: 0, green: 0.35, blue: 0.22)
    static let displayLabelGold = Color(red: 210 / 255, green: 188 / 255, blue: 88 / 255)

    // Main window background (blue-grey metallic panel)
    static let mainBg = Color(red: 70 / 255, green: 78 / 255, blue: 104 / 255)
    static let mainBgLight = Color(red: 88 / 255, green: 96 / 255, blue: 122 / 255)
    static let mainBgDark = Color(red: 48 / 255, green: 55 / 255, blue: 78 / 255)

    // Button colors (raised metallic blue-grey)
    static let buttonFace = Color(red: 92 / 255, green: 100 / 255, blue: 124 / 255)
    static let buttonLight = Color(red: 158 / 255, green: 166 / 255, blue: 188 / 255)
    static let buttonDark = Color(red: 38 / 255, green: 44 / 255, blue: 64 / 255)
    static let buttonPressed = Color(red: 56 / 255, green: 62 / 255, blue: 84 / 255)
    static let buttonHover = Color(red: 106 / 255, green: 114 / 255, blue: 138 / 255)
    static let buttonTextDark = Color(red: 0.10, green: 0.11, blue: 0.16)

    // Playlist — classic PLEDIT.TXT values retuned to RE:AMP reference
    static let playlistBg = Color(red: 0, green: 0, blue: 0)
    static let playlistText = Color(red: 0, green: 1.0, blue: 0)
    static let playlistSelected = Color(red: 0, green: 0, blue: 0xC6 / 255)
    static let playlistCurrentTrack = Color.white
    static let playlistCurrentTrackBg = Color(red: 0, green: 0, blue: 0xC6 / 255)
    static let playlistSelectedText = Color.white

    // Equalizer slider gradient
    static let eqSliderBg = Color(red: 16 / 255, green: 20 / 255, blue: 28 / 255)
    static let eqSliderGreen = Color(red: 0, green: 0.58, blue: 0.08)
    static let eqSliderYellow = Color(red: 0.95, green: 0.82, blue: 0.05)
    static let eqSliderOrange = Color(red: 1.0, green: 0.45, blue: 0.0)
    static let eqSliderRed = Color(red: 1.0, green: 0.12, blue: 0.05)
    static let eqSliderTop = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let eqSliderBottom = Color(red: 1.0, green: 0.4, blue: 0.0)
    static let eqCurve = Color(red: 1.0, green: 0.48, blue: 0.05)
    static let eqCurveHighlight = Color(red: 1.0, green: 0.72, blue: 0.18)
    static let eqFrame = Color(red: 56 / 255, green: 62 / 255, blue: 80 / 255)

    /// Maps a normalized level (0 = low/bottom/left, 1 = high/top/right) to the classic Winamp green→red scale.
    static func levelColor(normalized: CGFloat) -> Color {
        let n = max(0, min(1, normalized))
        if n <= 0.45 {
            let t = n / 0.45
            return Color(
                red: t * 0.95,
                green: 0.58 + t * 0.24,
                blue: 0.08 - t * 0.03
            )
        }
        if n <= 0.72 {
            let t = (n - 0.45) / 0.27
            return Color(
                red: 0.95 + t * 0.05,
                green: 0.82 - t * 0.37,
                blue: 0.05 + t * 0.0
            )
        }
        let t = (n - 0.72) / 0.28
        return Color(
            red: 1.0,
            green: 0.45 - t * 0.33,
            blue: 0.0 + t * 0.05
        )
    }

    // Spectrum/Visualizer
    static let spectrumBg = Color(red: 0, green: 0, blue: 0)
    static let spectrumDot = Color(red: 0, green: 1.0, blue: 0.45)
    static let spectrumPeak = Color(red: 1.0, green: 0, blue: 0)

    // Accents
    static let seekThumbGold = Color(red: 210 / 255, green: 188 / 255, blue: 88 / 255)
    static let seekThumbGoldDark = Color(red: 140 / 255, green: 118 / 255, blue: 48 / 255)
    static let vizButtonOrange = Color(red: 1.0, green: 0.50, blue: 0.0)
    static let vizButtonOrangeDark = Color(red: 0.75, green: 0.32, blue: 0.0)

    // Border colors (crisp metallic bevel highlights/shadows)
    static let borderLight = Color(red: 158 / 255, green: 166 / 255, blue: 188 / 255)
    static let borderDark = Color(red: 24 / 255, green: 28 / 255, blue: 42 / 255)
    static let borderAccent = Color(red: 68 / 255, green: 76 / 255, blue: 98 / 255)
}
