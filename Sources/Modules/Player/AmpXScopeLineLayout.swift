import CoreGraphics

/// Geometry for the oscilloscope mode: one polyline across the scope area, zero amplitude on the
/// vertical centre line. Pure, so the mapping is testable without drawing.
enum AmpXScopeLineLayout {
    /// Sample columns for a scope of this width (one per point, clamped like the Metal scope).
    static func columnCount(forWidth width: CGFloat) -> Int {
        AudioFeatures.scopeColumnCount(forWidth: width)
    }

    /// Maps levels in -1…1 (+1 = top) to points in `rect`, which uses flipped AppKit coordinates.
    static func points(levels: [Float], in rect: CGRect) -> [CGPoint] {
        guard !levels.isEmpty else { return [] }
        let halfHeight = rect.height / 2
        let step = levels.count > 1 ? rect.width / CGFloat(levels.count - 1) : 0

        return levels.enumerated().map { index, level in
            let clamped = CGFloat(min(max(level, -1), 1))
            return CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.midY - clamped * halfHeight)
        }
    }
}
