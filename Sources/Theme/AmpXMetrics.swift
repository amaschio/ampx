import CoreGraphics

/// Frozen layout constants measured from `screenshots/AmpX.png` at 2× (ReferenceMeasurementsV1).
enum AmpXMetrics {
    static let compositionWidth: CGFloat = 490
    static let playerHeight: CGFloat = 223.5
    static let equalizerHeight: CGFloat = 225.5
    static let playlistHeight: CGFloat = 305
    static let entheaHeight: CGFloat = 290
    static let moduleGap: CGFloat = 6

    static let headerHeight: CGFloat = 22
    static let playlistNonRowChrome: CGFloat = 103
    static let playlistRowHeight: CGFloat = 22
    static let minimumPlaylistViewportHeight: CGFloat = playlistRowHeight * 3
    static let defaultPlaylistViewportHeight: CGFloat = playlistHeight - headerHeight - playlistNonRowChrome

    static let primaryButtonSize = CGSize(width: 44, height: 40)
    static let secondaryButtonSize = CGSize(width: 64, height: 32)
    static let utilityButtonSize = CGSize(width: 28, height: 28)

    // MARK: - ReferenceMeasurementsV1 (content coordinates, scale 1.0)

    static let metadataDigitStyle: MetadataDigitStyle = .mono

    static let playerDisplayWell = CGRect(x: 15.0, y: 10.5, width: 165.5, height: 92.0)
    static let playerTrackWell = CGRect(x: 189.5, y: 11.0, width: 285.5, height: 28.0)
    /// Measured within `player.displayWell` (module-local content coordinates).
    static let playerTimer = CGRect(x: 36.0, y: 18.0, width: 129.0, height: 23.5)
    static let playerPlayGlyph = CGRect(x: 21.0, y: 20.5, width: 12.5, height: 16.5)
    static let playerMetadata = CGRect(x: 189.5, y: 46.5, width: 116.5, height: 21.5)
    static let playerVolume = CGRect(x: 189.0, y: 81.5, width: 100.5, height: 20.5)
    static let playerVolumeThumbCenterX: CGFloat = 261.0
    static let playerBalance = CGRect(x: 305.0, y: 81.5, width: 61.0, height: 20.5)
    static let playerBalanceThumbCenterX: CGFloat = 335.5
    static let playerEQToggle = CGRect(x: 418.0, y: 81.5, width: 28.0, height: 20.5)
    static let playerPLToggle = CGRect(x: 451.0, y: 81.5, width: 28.0, height: 20.5)
    static let playerPosition = CGRect(x: 15.5, y: 111.5, width: 458.5, height: 4.0)
    static let spectrumLeftColumnX: CGFloat = 15.0
    static let spectrumRightColumnX: CGFloat = 40.0
    static let spectrumColumnPitch: CGFloat = 5.5
    static let playerTransport: [CGRect] = [
        CGRect(x: 14.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 57.0, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 110.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 156.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 204.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 253.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 305.5, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 343.0, y: 139.0, width: 44.0, height: 38.0),
        CGRect(x: 392.5, y: 139.0, width: 44.0, height: 38.0),
    ]

    static let eqCurve = CGRect(x: 68.0, y: 18.0, width: 314.0, height: 24.0)
    static let eqPreamp = CGRect(x: 15.0, y: 56.0, width: 18.0, height: 120.0)
    static let eqBandRow = CGRect(x: 34.0, y: 56.0, width: 440.0, height: 120.0)

    static let playlistRows = CGRect(x: 15.5, y: 9.5, width: 424.0, height: 180.0)
    static let playlistScrollbar = CGRect(x: 440.5, y: 9.5, width: 16.0, height: 180.0)
    static let playlistFooter = CGRect(x: 15.5, y: 193.5, width: 441.0, height: 89.5)
    static let playlistDurationColumnWidth: CGFloat = 42

    static let spectrumSegmentHeight: CGFloat = 3.0
    static let spectrumSegmentGap: CGFloat = 1.0

    enum MetadataDigitStyle: String {
        case mono
        case segments
    }
}
