import CoreGraphics

enum PlaylistRowLayout {
    static let rowHeight: CGFloat = AmpXMetrics.playlistRowHeight
    static let durationColumnWidth: CGFloat = AmpXMetrics.playlistDurationColumnWidth

    static func visibleRange(offset: CGFloat, viewport: CGFloat, count: Int) -> Range<Int> {
        guard count > 0 else { return 0 ..< 0 }
        let first = max(0, Int(floor(offset / rowHeight)))
        let last = min(count, Int(ceil((offset + viewport) / rowHeight)))
        return first ..< last
    }

    static func rowRect(index: Int, width: CGFloat) -> CGRect {
        CGRect(
            x: 0,
            y: CGFloat(index) * rowHeight,
            width: width,
            height: rowHeight
        )
    }

    static func titleRect(in row: CGRect) -> CGRect {
        CGRect(
            x: row.minX + 4,
            y: row.minY,
            width: row.width - durationColumnWidth - 8,
            height: row.height
        )
    }

    static func durationRect(in row: CGRect) -> CGRect {
        CGRect(
            x: row.maxX - durationColumnWidth,
            y: row.minY,
            width: durationColumnWidth,
            height: row.height
        )
    }
}
