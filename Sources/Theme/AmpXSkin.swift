import AppKit
import CoreGraphics

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
    /// Sampled from PNG during static composition (Task 6).
    var goldDeferred: NSColor { get }
    /// Sampled from PNG during static composition (Task 6).
    var goldLightDeferred: NSColor { get }

    func font(size: CGFloat, weight: NSFont.Weight) -> NSFont

    func bevel(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func inset(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func accentLine(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
    func displayWell(_ rect: CGRect, in context: CGContext, backingScale: CGFloat)
}
