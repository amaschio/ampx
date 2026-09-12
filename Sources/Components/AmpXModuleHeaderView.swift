import AppKit

final class AmpXModuleHeaderView: AmpXDrawingView {
    let moduleID: AmpXModuleID
    var onCollapse: (() -> Void)?
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?

    init(moduleID: AmpXModuleID, skin: any AmpXSkin) {
        self.moduleID = moduleID
        super.init(skin: skin)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        skin.bevel(bounds, in: context, backingScale: backingScale)

        let accentHeight = max(1 / backingScale, 2 / backingScale)
        skin.accentLine(
            CGRect(x: bounds.minX, y: bounds.maxY - accentHeight, width: bounds.width, height: accentHeight),
            in: context,
            backingScale: backingScale
        )

        drawGrip(in: context, backingScale: backingScale)
        drawTitle(in: context)
        drawButtons(in: context, backingScale: backingScale)
    }

    private func drawGrip(in context: CGContext, backingScale: CGFloat) {
        let gripWidth = 12
        let gripRect = CGRect(
            x: bounds.minX + 6,
            y: bounds.midY - 8,
            width: CGFloat(gripWidth),
            height: 16
        )
        context.setFillColor(skin.border.cgColor)
        for row in 0..<3 {
            let y = gripRect.minY + CGFloat(row) * 5
            context.fill(CGRect(x: gripRect.minX, y: y, width: gripRect.width, height: 1 / backingScale))
        }
    }

    private func drawTitle(in context: CGContext) {
        let title = moduleTitle(for: moduleID)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: skin.font(size: 11, weight: .semibold),
            .foregroundColor: skin.text,
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: bounds.minX + 24,
            y: bounds.midY - size.height / 2
        )
        (title as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func drawButtons(in context: CGContext, backingScale: CGFloat) {
        let buttonSize = CGSize(width: 16, height: 14)
        var x = bounds.maxX - 8 - buttonSize.width

        if moduleID == .player {
            drawButton(
                label: "—",
                frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
                in: context,
                backingScale: backingScale
            )
            x -= buttonSize.width + 4
        }

        drawButton(
            label: "▢",
            frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
            in: context,
            backingScale: backingScale
        )
        x -= buttonSize.width + 4

        drawButton(
            label: "✕",
            frame: CGRect(x: x, y: bounds.midY - buttonSize.height / 2, width: buttonSize.width, height: buttonSize.height),
            in: context,
            backingScale: backingScale
        )
    }

    private func drawButton(
        label: String,
        frame: CGRect,
        in context: CGContext,
        backingScale: CGFloat
    ) {
        skin.inset(frame, in: context, backingScale: backingScale)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: skin.font(size: 9, weight: .medium),
            .foregroundColor: skin.textDim,
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        (label as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func moduleTitle(for moduleID: AmpXModuleID) -> String {
        switch moduleID {
        case .player:
            return "AmpX"
        case .equalizer:
            return "Equalizer"
        case .playlist:
            return "Playlist"
        case .enthea:
            return "ENTHEA"
        }
    }
}
