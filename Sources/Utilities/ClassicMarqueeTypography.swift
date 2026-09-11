import CoreGraphics
import Foundation

/// Pure layout logic for the classic bitmap marquee (TEXT.BMP, 5×6 cells).
///
/// Kept free of SwiftUI so the glyph mapping and scroll math stay testable.
enum ClassicMarqueeTypography {
    /// AmpX TEXT.BMP cell coordinates, keyed by lowercased character.
    static let fontLookup: [Character: (row: Int, col: Int)] = [
        "a": (0, 0), "b": (0, 1), "c": (0, 2), "d": (0, 3), "e": (0, 4),
        "f": (0, 5), "g": (0, 6), "h": (0, 7), "i": (0, 8), "j": (0, 9),
        "k": (0, 10), "l": (0, 11), "m": (0, 12), "n": (0, 13), "o": (0, 14),
        "p": (0, 15), "q": (0, 16), "r": (0, 17), "s": (0, 18), "t": (0, 19),
        "u": (0, 20), "v": (0, 21), "w": (0, 22), "x": (0, 23), "y": (0, 24),
        "z": (0, 25), "\"": (0, 26), "@": (0, 27), " ": (0, 30),
        "0": (1, 0), "1": (1, 1), "2": (1, 2), "3": (1, 3), "4": (1, 4),
        "5": (1, 5), "6": (1, 6), "7": (1, 7), "8": (1, 8), "9": (1, 9),
        ".": (1, 10), "*": (1, 11), ":": (1, 12), "(": (1, 13), ")": (1, 14),
        "-": (1, 15), "'": (1, 16), "!": (1, 17), "_": (1, 18), "+": (1, 19),
        "\\": (1, 20), "/": (1, 21), "[": (1, 22), "]": (1, 23),
    ]

    /// The separator glyph repeated between marquee repetitions.
    static let separator: Character = "*"

    /// Lowercases `text` and substitutes a space for any character the sheet can't render, so the
    /// rendered width always matches `text.count`.
    static func glyphs(for text: String) -> [Character] {
        text.lowercased().map { self.fontLookup[$0] == nil ? " " : $0 }
    }

    /// Width of one scroll repetition: the text plus its trailing separator run.
    static func scrollPeriodWidth(
        glyphCount: Int,
        scale: CGFloat,
        cellWidth: CGFloat = 5,
        separatorCells: Int = 3
    ) -> CGFloat {
        CGFloat(glyphCount + separatorCells) * cellWidth * scale
    }

    /// Horizontal offset of the marquee content at `elapsed` seconds. Returns `0` when the text
    /// fits, so short titles stay pinned to the leading edge.
    ///
    /// `periodWidth` is already scaled; `speed` is in logical points per second, so it is scaled
    /// here to match.
    static func scrollOffset(
        elapsed: TimeInterval,
        periodWidth: CGFloat,
        viewWidth: CGFloat,
        scale: CGFloat,
        speed: CGFloat = 20
    ) -> CGFloat {
        guard periodWidth > viewWidth, periodWidth > 0 else { return 0 }
        let travelled = CGFloat(elapsed) * speed * scale
        return -travelled.truncatingRemainder(dividingBy: periodWidth)
    }
}
