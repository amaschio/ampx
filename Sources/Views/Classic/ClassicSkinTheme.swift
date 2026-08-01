import SwiftUI

// MARK: - Metrics (Webamp 275 px grid)

/// Classic Winamp 2.x geometry, matching Webamp's `constants.ts` / `main-window.css`.
enum ClassicSkinMetrics {
    static let windowWidth: CGFloat = 275
    static let windowHeight: CGFloat = 116
    static let titleBarHeight: CGFloat = 14
    static let shadeHeight: CGFloat = 14
    static let playlistTopBarHeight: CGFloat = 20
    static let playlistShadeHeight: CGFloat = 14
    static let playlistBottomBarHeight: CGFloat = 38
    static let playlistRowHeight: CGFloat = 13
    static let playlistMinHeight: CGFloat = 116

    /// Scale a classic-grid length to the active Zoom level with stable pixel rounding.
    static func scaled(_ value: CGFloat, by scale: CGFloat) -> CGFloat {
        (value * scale).rounded(.toNearestOrAwayFromZero)
    }
}

// MARK: - Palette (live Classic callers only)

enum ClassicSkinColors {
    static let body = Color(red: 0x24 / 255, green: 0x25 / 255, blue: 0x33 / 255)
    static let displayBg = Color.black
    static let led = Color(red: 0, green: 0xEE / 255, blue: 0)
    static let ledDim = Color(red: 0, green: 0x4E / 255, blue: 0)

    // Playlist (PLEDIT.TXT defaults)
    static let playlistText = Color(red: 0, green: 1, blue: 0)
    static let playlistCurrent = Color.white
    static let playlistSelectedBg = Color(red: 0, green: 0, blue: 0xC6 / 255)
}

// MARK: - Absolute placement helper

extension View {
    /// Place a view at classic-skin pixel coordinates inside a top-leading ZStack,
    /// multiplied by the UI scale.
    func classicPlaced(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, scale: CGFloat) -> some View {
        self
            .frame(width: width * scale, height: height * scale)
            .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
    }
}

// MARK: - LCD text

/// Small green LED-style label used for kbps / kHz readouts.
struct ClassicLEDLabel: View {
    let text: String
    var lit: Bool = true
    var fontSize: CGFloat = 7
    var scale: CGFloat = 1.0

    var body: some View {
        Text(self.text)
            .winampFont(size: self.fontSize, weight: .bold, scale: self.scale)
            .foregroundColor(self.lit ? ClassicSkinColors.led : ClassicSkinColors.ledDim)
            .lineLimit(1)
            .fixedSize()
    }
}
