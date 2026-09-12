import AppKit

final class AmpXModuleView: NSView {
    let moduleID: AmpXModuleID
    let content: AmpXModuleContent
    let header: AmpXModuleHeaderView

    private let skin: any AmpXSkin

    init(moduleID: AmpXModuleID, content: AmpXModuleContent, skin: any AmpXSkin) {
        self.moduleID = moduleID
        self.content = content
        self.skin = skin
        self.header = AmpXModuleHeaderView(moduleID: moduleID, skin: skin)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(header)
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func applyLayout(frame: CGRect) {
        let backingScale = window?.backingScaleFactor ?? 1
        let snappedFrame = CGRect(
            x: AmpXPixelGrid.align(frame.minX, backingScale: backingScale),
            y: AmpXPixelGrid.align(frame.minY, backingScale: backingScale),
            width: AmpXPixelGrid.align(frame.width, backingScale: backingScale),
            height: AmpXPixelGrid.align(frame.height, backingScale: backingScale)
        )
        self.frame = snappedFrame

        let headerHeight = AmpXMetrics.headerHeight * (frame.width / AmpXMetrics.compositionWidth)
        header.frame = CGRect(x: 0, y: 0, width: snappedFrame.width, height: headerHeight)
        content.frame = CGRect(
            x: 0,
            y: headerHeight,
            width: snappedFrame.width,
            height: max(0, snappedFrame.height - headerHeight)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1
        skin.bevel(bounds, in: context, backingScale: backingScale)
    }
}
