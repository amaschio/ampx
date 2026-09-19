import AppKit

/// Source coordinates from shrunk-modules/reference/measurements.json, uniformly normalized.
enum AmpXCompactMetrics {
    static let factor: CGFloat = 490 / 1361
    static let playerHeight: CGFloat = 84 * factor
    static let equalizerHeight: CGFloat = 84 * factor
    static let playlistHeight: CGFloat = 76 * factor

    struct Chrome {
        let grip: CGRect
        let brand: CGRect
        let separators: [CGRect]
        let minimize: CGRect?
        let expand: CGRect
        let close: CGRect
    }

    struct PlayerLayout {
        let chrome: Chrome
        let well: CGRect
        let visualizer: CGRect
        let timer: CGRect
        let transport: [CGRect]
        let transportGlyphs: [CGRect]
    }

    struct EqualizerLayout {
        let chrome: Chrome
        let volume: CGRect
        let balance: CGRect
        let volumeTrack: CGRect
        let balanceTrack: CGRect
        let volumeThumbSize: CGSize
        let balanceThumbSize: CGSize
        let separator: CGRect
    }

    static func equalizerLayout() -> EqualizerLayout {
        let volume = source(285, 591 - 281, 422, 22)
        let balance = source(757, 591 - 281, 465, 22)
        return EqualizerLayout(
            chrome: chrome(moduleID: .equalizer),
            volume: volume.insetBy(dx: 0, dy: -5),
            balance: balance.insetBy(dx: 0, dy: -5),
            volumeTrack: volume,
            balanceTrack: balance,
            volumeThumbSize: CGSize(width: 45 * factor, height: 42 * factor),
            balanceThumbSize: CGSize(width: 50 * factor, height: 42 * factor),
            separator: source(728, 582 - 281, 7, 38)
        )
    }

    static func source(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: (x - 28) * factor, y: (y - 276) * factor, width: width * factor, height: height * factor)
    }

    static func chrome(moduleID: AmpXModuleID, width: CGFloat = 490) -> Chrome {
        let offset = max(490, width) - 490
        let isPlayer = moduleID == .player
        return Chrome(
            grip: source(45, 293, 60, 54),
            brand: source(123, 306, 97, 35),
            separators: [source(254, 302, 6, 38),
                         source(isPlayer ? 1175 : 1238, 285, 7, 69).offsetBy(dx: offset, dy: 0)],
            minimize: isPlayer ? source(1200, 294, 50, 51) : nil,
            expand: source(1263, 294, 51, 51).offsetBy(dx: offset, dy: 0),
            close: source(1325, 294, 50, 51).offsetBy(dx: offset, dy: 0)
        )
    }

    static func playerLayout() -> PlayerLayout {
        PlayerLayout(
            chrome: chrome(moduleID: .player),
            well: source(276, 292, 512, 56),
            visualizer: source(292, 302, 279, 38),
            timer: source(617, 298, 150, 46),
            transport: [source(814, 291, 64, 58), source(885, 291, 63, 58), source(956, 291, 62, 58),
                        source(1026, 291, 63, 58), source(1097, 291, 64, 58)],
            transportGlyphs: [source(834, 308, 23, 25), source(907, 308, 22, 25), source(978, 310, 19, 22),
                              source(1047, 311, 20, 20), source(1117, 308, 24, 25)]
        )
    }
}
