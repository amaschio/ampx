import AppKit
import CoreGraphics

struct AmpXSegmentDigits {
    let skin: any AmpXSkin

    func draw(_ text: String, in rect: CGRect, context: CGContext) {
        let characters = Array(text)
        guard !characters.isEmpty else { return }

        let colonCount = characters.filter { $0 == ":" }.count
        let digitCount = characters.count - colonCount
        let colonWidth = rect.height * 0.18
        let spacing = rect.height * 0.08
        let totalColonWidth = CGFloat(colonCount) * colonWidth
        let totalSpacing = CGFloat(max(0, characters.count - 1)) * spacing
        let digitWidth = (rect.width - totalColonWidth - totalSpacing) / CGFloat(max(digitCount, 1))

        var x = rect.minX
        for character in characters {
            if character == ":" {
                drawColon(
                    in: CGRect(x: x, y: rect.minY, width: colonWidth, height: rect.height),
                    context: context
                )
                x += colonWidth + spacing
                continue
            }

            drawDigit(
                character,
                in: CGRect(x: x, y: rect.minY, width: digitWidth, height: rect.height),
                context: context
            )
            x += digitWidth + spacing
        }
    }

    private func drawDigit(_ character: Character, in rect: CGRect, context: CGContext) {
        let segments = segments(for: character)
        let thickness = max(1, rect.height * 0.12)
        let gutter = max(1, rect.height * 0.08)
        let horizontalInset = gutter
        let verticalInset = gutter
        let segmentLength = rect.width - horizontalInset * 2
        let verticalLength = (rect.height - thickness * 3 - verticalInset * 2) / 2

        let a = CGRect(x: rect.minX + horizontalInset, y: rect.minY + verticalInset, width: segmentLength, height: thickness)
        let g = CGRect(x: rect.minX + horizontalInset, y: rect.midY - thickness / 2, width: segmentLength, height: thickness)
        let d = CGRect(
            x: rect.minX + horizontalInset,
            y: rect.maxY - verticalInset - thickness,
            width: segmentLength,
            height: thickness
        )
        let f = CGRect(x: rect.minX + horizontalInset, y: a.maxY, width: thickness, height: verticalLength)
        let b = CGRect(x: rect.maxX - horizontalInset - thickness, y: a.maxY, width: thickness, height: verticalLength)
        let e = CGRect(x: rect.minX + horizontalInset, y: g.maxY, width: thickness, height: verticalLength)
        let c = CGRect(x: rect.maxX - horizontalInset - thickness, y: g.maxY, width: thickness, height: verticalLength)

        context.setFillColor(skin.green.cgColor)
        if segments.contains("a") { context.fill(a) }
        if segments.contains("b") { context.fill(b) }
        if segments.contains("c") { context.fill(c) }
        if segments.contains("d") { context.fill(d) }
        if segments.contains("e") { context.fill(e) }
        if segments.contains("f") { context.fill(f) }
        if segments.contains("g") { context.fill(g) }
    }

    private func drawColon(in rect: CGRect, context: CGContext) {
        let dotSize = max(1, rect.width * 0.55)
        let gap = rect.height * 0.22
        let x = rect.midX - dotSize / 2
        context.setFillColor(skin.green.cgColor)
        context.fill(CGRect(x: x, y: rect.minY + gap, width: dotSize, height: dotSize))
        context.fill(CGRect(x: x, y: rect.maxY - gap - dotSize, width: dotSize, height: dotSize))
    }

    private func segments(for character: Character) -> String {
        switch character {
        case "0": "abcdef"
        case "1": "bc"
        case "2": "abdeg"
        case "3": "abcdg"
        case "4": "bcfg"
        case "5": "acdfg"
        case "6": "acdefg"
        case "7": "abc"
        case "8": "abcdefg"
        case "9": "abcdfg"
        default: ""
        }
    }
}
