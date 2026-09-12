import AppKit
import CoreGraphics

struct AmpXLabel {
    var text: String
    var color: NSColor
    var fontSize: CGFloat
    var weight: NSFont.Weight
    var alignment: NSTextAlignment

    init(
        text: String,
        color: NSColor,
        fontSize: CGFloat,
        weight: NSFont.Weight = .regular,
        alignment: NSTextAlignment = .left
    ) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.weight = weight
        self.alignment = alignment
    }

    func draw(in rect: CGRect, context: CGContext, skin: any AmpXSkin) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        let attributes: [NSAttributedString.Key: Any] = [
            .font: skin.font(size: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]

        let attributed = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = rect.insetBy(dx: 0, dy: 1)
        let size = attributed.boundingRect(
            with: CGSize(width: boundingRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        let originY = boundingRect.minY + (boundingRect.height - size.height) / 2
        let drawRect = CGRect(x: boundingRect.minX, y: originY, width: boundingRect.width, height: size.height)
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}
