import AppKit
import CoreGraphics

enum AmpXFaceStyle {
    /// Steel button face (Winamp's grey transport look); glyphs use `faceInk`.
    case normal
    case hovered
    case pressed
    /// Orange menu button; glyphs stay light (`text`).
    case menu
    /// Non-interactive raised navy surface (scrollbar track, legacy slider thumb).
    case surface
}

enum AmpXThumbMaterial {
    /// Steel handle with three vertical grooves (horizontal sliders).
    case steel
    /// Steel handle with two horizontal grooves (vertical EQ sliders).
    case steelLevel
    case gold
    /// Plain bevelled gold tab (Playlist scrollbar).
    case goldTab
}

enum AmpXTrackFill {
    case volume
    case balance
}

protocol AmpXSkin {
    var background: NSColor { get }
    var panel: NSColor { get }
    var panelLight: NSColor { get }
    var border: NSColor { get }
    var borderHighlight: NSColor { get }
    var borderDark: NSColor { get }
    var text: NSColor { get }
    var textDim: NSColor { get }
    var selection: NSColor { get }
    var green: NSColor { get }
    var yellow: NSColor { get }
    var orange: NSColor { get }
    var display: NSColor { get }
    /// Sampled from PNG scrollbar thumb (ReferenceMeasurementsV1).
    var gold: NSColor { get }
    /// Sampled from PNG scrollbar thumb highlight (ReferenceMeasurementsV1).
    var goldLight: NSColor { get }
    /// Glyph and label ink on steel button faces.
    var faceInk: NSColor { get }
    /// Disabled glyph and label ink on steel button faces.
    var faceInkDim: NSColor { get }

    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont

    /// Raised control face in its normal state.
    func bevel(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func inset(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func accentLine(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    /// Recessed black well with a steel lip.
    func displayWell(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)

    /// Module panel with layered outer edges and an optional recessed content frame.
    func panelFrame(_ rect: CGRect, contentFrame: CGRect?, in context: CGContext, backingScale: CGFloat)
    func raisedFace(_ rect: CGRect, style: AmpXFaceStyle, in context: CGContext, backingScale: CGFloat)
    /// Paired gold header rules filling `rect` (two 3.5 pt lines, 2.5 pt apart at scale 1).
    func headerRule(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func dotGrid(_ rect: CGRect, in context: CGContext)
    /// Pill track filled end to end with the `AmpXSliderColorRamp` color at the value `fraction` (0…1).
    func sliderTrack(
        _ rect: CGRect,
        fill: AmpXTrackFill,
        fraction: Double,
        in context: CGContext,
        backingScale: CGFloat
    )
    func seekWell(_ well: CGRect, track: CGRect, in context: CGContext, backingScale: CGFloat)
    /// Vertical EQ slot with a glowing bar tinted by the displayed gain.
    func levelTrack(_ slot: CGRect, decibels: Double, in context: CGContext, backingScale: CGFloat)
    func metallicThumb(_ rect: CGRect, material: AmpXThumbMaterial, in context: CGContext, backingScale: CGFloat)
}
