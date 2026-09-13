import AppKit
import QuartzCore

final class AmpXStackViewport: NSView {
    let stackView = AmpXModuleStackView()

    var onVisibleRectChanged: ((CGRect) -> Void)?

    private(set) var scrollOffset: CGFloat = 0

    var pendingAutoScrollSpeed: CGFloat = 0

    private let scrollbar: AmpXScrollbar
    private var contentHeight: CGFloat = 0
    private var viewportHeight: CGFloat = 0
    private var scrolls = false

    var visibleContentRect: CGRect {
        CGRect(
            x: 0,
            y: self.scrollOffset,
            width: bounds.width,
            height: min(self.viewportHeight, max(0, self.contentHeight - self.scrollOffset))
        )
    }

    init(skin: any AmpXSkin) {
        self.scrollbar = AmpXScrollbar(skin: skin)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(self.stackView)
        addSubview(self.scrollbar)

        self.scrollbar.onScroll = { [weak self] offset in
            self?.setScrollOffset(offset)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        self.layoutScrollbar()
        self.applyScrollTranslation()
    }

    func applyLayoutMetrics(contentHeight: CGFloat, viewportHeight: CGFloat) {
        let previousOffset = self.scrollOffset
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
        self.scrolls = contentHeight > viewportHeight

        self.stackView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: contentHeight)
        self.setScrollOffset(previousOffset)
        self.updateScrollbarMetrics(viewportHeight: viewportHeight)
        self.layoutScrollbar()
    }

    func applyLayout(_ result: AmpXLayoutResult, state: AmpXModuleOrder) {
        let previousOffset = self.scrollOffset
        self.contentHeight = result.contentHeight
        self.viewportHeight = result.viewportHeight
        self.scrolls = result.scrolls

        self.stackView.applyLayout(result, state: state, playlistViewportHeight: result.playlistViewportHeight)
        self.stackView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: self.contentHeight)

        self.setScrollOffset(previousOffset)
        self.updateScrollbarMetrics(viewportHeight: result.viewportHeight)
        self.layoutScrollbar()
    }

    func setScrollOffset(_ offset: CGFloat) {
        let clamped = AmpXControlMath.clampedScrollOffset(
            offset,
            contentLength: self.contentHeight,
            viewportLength: self.viewportHeight > 0 ? self.viewportHeight : bounds.height
        )
        guard clamped != self.scrollOffset else { return }
        self.scrollOffset = clamped
        self.applyScrollTranslation()
        self.scrollbar.offset = self.scrollOffset
        self.onVisibleRectChanged?(self.visibleContentRect)
    }

    func reveal(_ rect: CGRect) {
        let viewportLength = self.viewportHeight > 0 ? self.viewportHeight : bounds.height
        var target = self.scrollOffset
        let visibleTop = self.scrollOffset
        let visibleBottom = self.scrollOffset + viewportLength

        if rect.minY < visibleTop {
            target = rect.minY
        } else if rect.maxY > visibleBottom {
            target = rect.maxY - viewportLength
        }

        self.setScrollOffset(target)
    }

    func viewportPoint(fromScreenPoint screenPoint: NSPoint) -> NSPoint {
        guard let stackWindow = window else { return .zero }
        let windowPoint = stackWindow.convertPoint(fromScreen: screenPoint)
        return convert(windowPoint, from: nil)
    }

    func contains(screenPoint: NSPoint) -> Bool {
        bounds.contains(self.viewportPoint(fromScreenPoint: screenPoint))
    }

    func stackContentPoint(fromScreenPoint screenPoint: NSPoint) -> CGPoint {
        let viewportPoint = viewportPoint(fromScreenPoint: screenPoint)
        return CGPoint(x: viewportPoint.x, y: viewportPoint.y + self.scrollOffset)
    }

    func autoScrollSpeed(for viewportPoint: NSPoint) -> CGFloat {
        guard self.scrolls else { return 0 }

        let topZone = bounds.minY + AmpXModuleDragController.autoScrollEdgeInset
        let bottomZone = bounds.maxY - AmpXModuleDragController.autoScrollEdgeInset

        if viewportPoint.y < topZone {
            let amount = (topZone - viewportPoint.y) / AmpXModuleDragController.autoScrollEdgeInset
            return -AmpXModuleDragController.autoScrollMaxSpeed * min(1, amount)
        }

        if viewportPoint.y > bottomZone {
            let amount = (viewportPoint.y - bottomZone) / AmpXModuleDragController.autoScrollEdgeInset
            return AmpXModuleDragController.autoScrollMaxSpeed * min(1, amount)
        }

        return 0
    }

    override func scrollWheel(with event: NSEvent) {
        if let playlistView = stackView.moduleView(for: .playlist),
           let playlist = playlistView.content as? PlaylistModuleContent,
           playlist.canScrollVertically
        {
            playlist.scrollWheel(with: event)
            return
        }

        guard self.scrolls else { return }
        self.setScrollOffset(self.scrollOffset - event.deltaY * 8)
    }

    private func applyScrollTranslation() {
        self.stackView.frame.origin.y = -self.scrollOffset
    }

    private func updateScrollbarMetrics(viewportHeight: CGFloat) {
        self.scrollbar.contentLength = self.contentHeight
        self.scrollbar.viewportLength = viewportHeight
        self.scrollbar.isEnabled = self.scrolls
        self.scrollbar.isHidden = !self.scrolls
    }

    private func layoutScrollbar() {
        guard self.scrolls else {
            self.scrollbar.isHidden = true
            return
        }

        let width = AmpXMetrics.playlistScrollbar.width
        self.scrollbar.frame = CGRect(
            x: bounds.width - width,
            y: 0,
            width: width,
            height: bounds.height
        )
    }
}
