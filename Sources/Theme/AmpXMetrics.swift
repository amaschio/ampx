import CoreGraphics

/// Layout constants in logical points. Player values come from ReferenceMeasurementsV2 (2× source);
/// Equalizer/Playlist values remain unvalidated V1 until their reconstruction tasks.
enum AmpXMetrics {
    static let compositionWidth: CGFloat = 490
    static let playerHeight: CGFloat = 223.5
    static let equalizerHeight: CGFloat = 225.5
    static let playlistHeight: CGFloat = 305
    static let entheaHeight: CGFloat = 290
    static let moduleGap: CGFloat = 6

    static let headerHeight: CGFloat = 28.5
    static let playlistNonRowChrome: CGFloat = 103
    static let playlistRowHeight: CGFloat = 22
    static let minimumPlaylistViewportHeight: CGFloat = playlistRowHeight * 3
    static let defaultPlaylistViewportHeight: CGFloat = playlistHeight - headerHeight - playlistNonRowChrome

    static let primaryButtonSize = CGSize(width: 44, height: 40)
    static let secondaryButtonSize = CGSize(width: 64, height: 32)
    static let utilityButtonSize = CGSize(width: 28, height: 28)

    // MARK: - Module chrome (module coordinates, V2 records 2–12)

    /// Recessed content frame: `content.frame` (7, 27.5, 476, 189.5) within the 490 × 223.5 Player.
    static let contentFrameInsets = (top: CGFloat(27.5), left: CGFloat(7), bottom: CGFloat(6.5), right: CGFloat(7))
    static let headerGripGlyph = CGRect(x: 9.5, y: 7, width: 18, height: 16)
    static let headerRuleMinX: CGFloat = 37.5
    static let headerRuleMaxX: CGFloat = 405
    static let headerRuleY: CGFloat = 9.5
    static let headerRuleHeight: CGFloat = 9.5
    static let headerRuleGapBeforeTitle: CGFloat = 19.5
    static let headerRuleGapAfterTitle: CGFloat = 16.5
    static let headerTitleCenterX: CGFloat = 245
    static let headerBrandInkTop: CGFloat = 6
    static let headerMinimizeButton = CGRect(x: 412, y: 5, width: 20, height: 20)
    static let headerCollapseButton = CGRect(x: 438, y: 5, width: 20, height: 20)
    static let headerCloseButton = CGRect(x: 463.5, y: 5, width: 20, height: 20)
    /// Glyph ink boxes relative to their header button.
    static let headerMinimizeGlyph = CGRect(x: 5.25, y: 11, width: 8.75, height: 2.75)
    static let headerCollapseGlyph = CGRect(x: 4.75, y: 4.5, width: 10.5, height: 10.5)
    static let headerCloseGlyph = CGRect(x: 5, y: 5, width: 10, height: 10)

    // MARK: - Player (content coordinates, scale 1.0)

    static let metadataDigitStyle: MetadataDigitStyle = .mono

    static let playerDisplayWell = CGRect(x: 13.5, y: 10.0, width: 168.0, height: 95.0)
    static let playerDisplayInterior = CGRect(x: 15.5, y: 12.5, width: 164.0, height: 90.5)
    static let playerTrackWell = CGRect(x: 187.5, y: 10.0, width: 288.5, height: 31.5)
    static let playerTrackTextInk = CGRect(x: 193.5, y: 18.0, width: 214.5, height: 14.0)
    static let playerTimer = CGRect(x: 84.5, y: 18.0, width: 82.0, height: 25.5)
    static let playerPlayGlyph = CGRect(x: 35.0, y: 21.0, width: 14.0, height: 18.0)
    static let playerSpectrum = CGRect(x: 33.0, y: 57.0, width: 137.5, height: 41.0)
    static let playerChannelLabelL = CGRect(x: 19.0, y: 64.0, width: 9.0, height: 13.5)
    static let playerChannelLabelR = CGRect(x: 19.0, y: 85.0, width: 9.0, height: 13.5)

    static let playerBitrateWell = CGRect(x: 187.5, y: 46.0, width: 39.5, height: 25.0)
    static let playerBitrateInk = CGRect(x: 193.5, y: 52.0, width: 25.5, height: 12.5)
    static let playerKbpsInk = CGRect(x: 232.0, y: 53.5, width: 26.5, height: 13.5)
    static let playerSampleRateWell = CGRect(x: 274.0, y: 46.5, width: 33.0, height: 24.5)
    static let playerSampleRateInk = CGRect(x: 282.0, y: 52.0, width: 16.5, height: 12.5)
    static let playerKHzInk = CGRect(x: 312.5, y: 53.5, width: 20.5, height: 11.5)
    static let playerMonoInk = CGRect(x: 390.5, y: 55.5, width: 30.0, height: 9.0)
    static let playerStereoInk = CGRect(x: 430.5, y: 53.5, width: 41.0, height: 11.0)

    /// Slider frames enclose the visible track and thumb; hit areas expand from these.
    static let playerVolume = CGRect(x: 188.5, y: 79, width: 105.5, height: 24)
    static let playerBalance = CGRect(x: 302.5, y: 79, width: 67, height: 24)
    static let playerSliderTrackHeight: CGFloat = 11
    static let playerSliderThumbSize = CGSize(width: 21.5, height: 20)
    /// Thumb center sits below the track center (thumb 83–103 vs track 85.5–96.5).
    static let playerSliderThumbOffset: CGFloat = 2
    static let playerPosition = CGRect(x: 13.5, y: 111.5, width: 462.5, height: 19.5)
    static let playerPositionTrackSize = CGSize(width: 454, height: 11)
    static let playerPositionThumbSize = CGSize(width: 47.5, height: 16)
    static let playerPositionThumbOffset: CGFloat = 0.5

    static let playerEQToggle = CGRect(x: 376.5, y: 77.0, width: 46.5, height: 28.5)
    static let playerPLToggle = CGRect(x: 428.0, y: 77.0, width: 47.5, height: 28.5)
    /// Button-local indicator lamps and label ink (left edge, baseline).
    static let playerEQIndicator = CGRect(x: 6.75, y: 8.5, width: 9.5, height: 11)
    static let playerPLIndicator = CGRect(x: 6.25, y: 8.5, width: 10, height: 11)
    /// Baselines sit on the letter bottoms; the Q tail reaches the 20.5 pt ink bottom.
    static let playerEQLabelInk = CGPoint(x: 22, y: 19.5)
    static let playerPLLabelInk = CGPoint(x: 22.5, y: 19.5)
    static let playerShuffleIndicator = CGRect(x: 8.75, y: 12, width: 10, height: 11.5)
    static let playerShuffleLabelInk = CGPoint(x: 25.5, y: 24.5)

    static let playerTransport: [CGRect] = [
        CGRect(x: 14.0, y: 139.5, width: 44.0, height: 38.5),
        CGRect(x: 61.0, y: 139.5, width: 46.0, height: 38.5),
        CGRect(x: 109.5, y: 139.5, width: 42.0, height: 38.5),
        CGRect(x: 155.5, y: 139.5, width: 43.5, height: 38.5),
        CGRect(x: 203.5, y: 139.5, width: 43.5, height: 38.5),
        CGRect(x: 252.5, y: 139.5, width: 47.0, height: 38.5),
        CGRect(x: 303.5, y: 139.5, width: 84.0, height: 38.5),
        CGRect(x: 390.5, y: 139.5, width: 42.5, height: 38.5),
        CGRect(x: 441.5, y: 142.0, width: 33.5, height: 35.5),
    ]

    /// Transport glyph ink boxes (content coordinates); Shuffle uses indicator + label instead.
    static let playerTransportGlyphs: [CGRect?] = [
        CGRect(x: 28.5, y: 150.5, width: 14.5, height: 16.0),
        CGRect(x: 78.0, y: 151.0, width: 13.5, height: 15.5),
        CGRect(x: 124.5, y: 151.5, width: 12.0, height: 14.5),
        CGRect(x: 171.5, y: 152.5, width: 12.5, height: 12.5),
        CGRect(x: 219.0, y: 150.5, width: 14.0, height: 16.0),
        CGRect(x: 268.5, y: 152.0, width: 15.0, height: 14.5),
        nil,
        CGRect(x: 402.5, y: 150.5, width: 18.5, height: 16.0),
        CGRect(x: 450.5, y: 152.5, width: 15.5, height: 14.0),
    ]

    /// Spectrum: 16 columns × 6 segments sampled from the reference display.
    static let spectrumColumnCount = 16
    static let spectrumSegmentCount = 6
    static let spectrumColumnWidth: CGFloat = 5.5
    static let spectrumColumnPitch: CGFloat = 8.75
    static let spectrumSegmentHeight: CGFloat = 5.0
    static let spectrumSegmentPitch: CGFloat = 6.9

    // MARK: - Equalizer (content coordinates, ReferenceMeasurementsV2 eq-measurements-v2)

    static let eqOnToggle = CGRect(x: 14, y: 9.5, width: 55.5, height: 33)
    static let eqAutoToggle = CGRect(x: 75.5, y: 9.5, width: 70.5, height: 33)
    static let eqPresetsButton = CGRect(x: 382, y: 9.5, width: 93.5, height: 33)
    /// Button-local lamps, label ink (left edge, baseline) and dropdown triangle.
    /// Lamp outline sits just outside the measured 8.5 × 9 pt green core.
    static let eqOnIndicator = CGRect(x: 10, y: 10.5, width: 10.5, height: 11)
    static let eqAutoIndicator = CGRect(x: 10, y: 10, width: 10.5, height: 11)
    static let eqOnLabelInk = CGPoint(x: 28.5, y: 21)
    static let eqAutoLabelInk = CGPoint(x: 30, y: 21)
    static let eqPresetsLabelInk = CGPoint(x: 13.5, y: 21)
    static let eqPresetsTriangle = CGRect(x: 74.5, y: 13, width: 8, height: 7)

    /// Curve drawn on the panel (no well): edge knots at the frame edges, band knots from +20 pt at 18.39 pt pitch.
    static let eqCurveFrame = CGRect(x: 161, y: 5, width: 201, height: 42)
    static let eqCurveFirstBandOffset: CGFloat = 20
    static let eqCurveBandPitch: CGFloat = 18.39
    static let eqGridMinY: CGFloat = 10
    static let eqGridMaxY: CGFloat = 47

    /// Measured thumb centers; the reference spacing is uneven (67–72 px).
    static let eqPreampCenterX: CGFloat = 36
    static let eqBandCenterX: [CGFloat] = [135, 169.75, 203.25, 237.25, 271.75, 306.25, 339.75, 374.25, 408, 444]
    static let eqSliderSlotSize = CGSize(width: 13, height: 109.5)
    static let eqSliderSlotCenterY: CGFloat = 108.25
    static let eqSliderThumbSize = CGSize(width: 20, height: 24)
    /// Thumb-center travel: +12 dB at the 58.5 pt tick row, −12 dB at 157.25 pt.
    static let eqSliderTravel: CGFloat = 98.75
    static let eqTickWidth: CGFloat = 6.5
    static let eqPreampTickOffset: CGFloat = 15.75
    static let eqOuterBandTickOffset: CGFloat = 17.25
    static let eqDecibelLabelCenterX: CGFloat = 80
    static let eqDecibelLabelBaselines: [CGFloat] = [64, 111.5, 159.5]
    static let eqPreampLabelInkX: CGFloat = 20
    static let eqBandLabelBaseline: CGFloat = 180.5

    // MARK: - Playlist (ReferenceMeasurementsV1, unvalidated)

    static let playlistRows = CGRect(x: 15.5, y: 9.5, width: 424.0, height: 180.0)
    static let playlistScrollbar = CGRect(x: 440.5, y: 9.5, width: 16.0, height: 180.0)
    static let playlistFooter = CGRect(x: 15.5, y: 193.5, width: 441.0, height: 89.5)
    static let playlistDurationColumnWidth: CGFloat = 42

    enum MetadataDigitStyle: String {
        case mono
        case segments
    }
}
