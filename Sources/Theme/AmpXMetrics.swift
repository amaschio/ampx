import CoreGraphics

enum AmpXMetrics {
    static let compositionWidth: CGFloat = 490
    static let playerHeight: CGFloat = 223.5
    static let equalizerHeight: CGFloat = 225.5
    static let playlistHeight: CGFloat = 305
    static let entheaHeight: CGFloat = 290
    static let moduleGap: CGFloat = 6

    /// Starting value; Task 6 refines from ReferenceMeasurementsV1.
    static let headerHeight: CGFloat = 22
    /// Footer, scrollbar track, and other non-row chrome below the playlist header.
    static let playlistNonRowChrome: CGFloat = 103
    static let playlistRowHeight: CGFloat = 22
    static let minimumPlaylistViewportHeight: CGFloat = playlistRowHeight * 3
    static let defaultPlaylistViewportHeight: CGFloat = playlistHeight - headerHeight - playlistNonRowChrome

    static let primaryButtonSize = CGSize(width: 44, height: 40)
    static let secondaryButtonSize = CGSize(width: 64, height: 32)
    static let utilityButtonSize = CGSize(width: 28, height: 28)
}
