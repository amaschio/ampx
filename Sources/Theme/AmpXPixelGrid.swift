import CoreGraphics

enum AmpXPixelGrid {
    static func align(_ value: CGFloat, backingScale: CGFloat) -> CGFloat {
        guard backingScale > 0 else { return value }
        return (value * backingScale).rounded() / backingScale
    }

    static func strokeRect(_ rect: CGRect, lineWidth: CGFloat, backingScale: CGFloat) -> CGRect {
        let alignedMinX = align(rect.minX, backingScale: backingScale)
        let alignedMinY = align(rect.minY, backingScale: backingScale)
        let alignedMaxX = align(rect.maxX, backingScale: backingScale)
        let alignedMaxY = align(rect.maxY, backingScale: backingScale)
        return CGRect(
            x: alignedMinX + lineWidth / 2,
            y: alignedMinY + lineWidth / 2,
            width: alignedMaxX - alignedMinX - lineWidth,
            height: alignedMaxY - alignedMinY - lineWidth
        )
    }
}
