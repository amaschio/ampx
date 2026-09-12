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
            y: scrollOffset,
            width: bounds.width,
            height: min(viewportHeight, max(0, contentHeight - scrollOffset))
        )
    }

    init(skin: any AmpXSkin) {
        self.scrollbar = AmpXScrollbar(skin: skin)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(stackView)
        addSubview(scrollbar)

        scrollbar.onScroll = { [weak self] offset in
            self?.setScrollOffset(offset)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        layoutScrollbar()
        applyScrollTranslation()
    }

    func applyLayoutMetrics(contentHeight: CGFloat, viewportHeight: CGFloat) {
        let previousOffset = scrollOffset
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
        self.scrolls = contentHeight > viewportHeight

        stackView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: contentHeight)
        setScrollOffset(previousOffset)
        updateScrollbarMetrics(viewportHeight: viewportHeight)
        layoutScrollbar()
    }

    func applyLayout(_ result: AmpXLayoutResult, state: AmpXModuleOrder) {
        let previousOffset = scrollOffset
        contentHeight = result.contentHeight
        viewportHeight = result.viewportHeight
        scrolls = result.scrolls

        stackView.applyLayout(result, state: state, playlistViewportHeight: result.playlistViewportHeight)
        stackView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: contentHeight)

        setScrollOffset(previousOffset)
        updateScrollbarMetrics(viewportHeight: result.viewportHeight)
        layoutScrollbar()
    }

    func setScrollOffset(_ offset: CGFloat) {
        let clamped = AmpXControlMath.clampedScrollOffset(
            offset,
            contentLength: contentHeight,
            viewportLength: viewportHeight > 0 ? viewportHeight : bounds.height
        )
        guard clamped != scrollOffset else { return }
        scrollOffset = clamped
        applyScrollTranslation()
        scrollbar.offset = scrollOffset
        onVisibleRectChanged?(visibleContentRect)
    }

    func reveal(_ rect: CGRect) {
        let viewportLength = viewportHeight > 0 ? viewportHeight : bounds.height
        var target = scrollOffset
        let visibleTop = scrollOffset
        let visibleBottom = scrollOffset + viewportLength

        if rect.minY < visibleTop {
            target = rect.minY
        } else if rect.maxY > visibleBottom {
            target = rect.maxY - viewportLength
        }

        setScrollOffset(target)
    }

    func viewportPoint(fromScreenPoint screenPoint: NSPoint) -> NSPoint {
        guard let stackWindow = window else { return .zero }
        let windowPoint = stackWindow.convertPoint(fromScreen: screenPoint)
        return convert(windowPoint, from: nil)
    }

    func contains(screenPoint: NSPoint) -> Bool {
        bounds.contains(viewportPoint(fromScreenPoint: screenPoint))
    }

    func stackContentPoint(fromScreenPoint screenPoint: NSPoint) -> CGPoint {
        let viewportPoint = viewportPoint(fromScreenPoint: screenPoint)
        return CGPoint(x: viewportPoint.x, y: viewportPoint.y + scrollOffset)
    }

    func autoScrollSpeed(for viewportPoint: NSPoint) -> CGFloat {
        guard scrolls else { return 0 }

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

        guard scrolls else { return }
        setScrollOffset(scrollOffset - event.deltaY * 8)
    }

    private func applyScrollTranslation() {
        stackView.frame.origin.y = -scrollOffset
    }

    private func updateScrollbarMetrics(viewportHeight: CGFloat) {
        scrollbar.contentLength = contentHeight
        scrollbar.viewportLength = viewportHeight
        scrollbar.isEnabled = scrolls
        scrollbar.isHidden = !scrolls
    }

    private func layoutScrollbar() {
        guard scrolls else {
            scrollbar.isHidden = true
            return
        }

        let width = AmpXMetrics.playlistScrollbar.width
        scrollbar.frame = CGRect(
            x: bounds.width - width,
            y: 0,
            width: width,
            height: bounds.height
        )
    }
}
