import AppKit
import SwiftUI

enum AmpXTitleBarMetrics {
    /// Default trailing exclusion for main-window controls when callers don't pass a width.
    static let buttonAreaWidth: CGFloat = 60
}

/// Pure hit-test geometry so `DraggableWindowView.hitTest` can stay `nonisolated`
/// (macOS 26 Swift 6: AppKit calls `hitTest` without a Swift task, and a MainActor
/// thunk SIGTRAPs in `swift_task_isCurrentExecutor`).
enum TitleBarHitTesting {
    static func localPoint(superviewPoint: CGPoint, frameInSuperview: CGRect) -> CGPoint {
        CGPoint(
            x: superviewPoint.x - frameInSuperview.minX,
            y: superviewPoint.y - frameInSuperview.minY
        )
    }

    static func shouldReceiveHit(
        localPoint: CGPoint,
        bounds: CGRect,
        excludedLeadingWidth: CGFloat,
        excludedTrailingWidth: CGFloat
    ) -> Bool {
        guard bounds.width > 0, bounds.height > 0, bounds.contains(localPoint) else {
            return false
        }
        if excludedLeadingWidth > 0, localPoint.x < excludedLeadingWidth {
            return false
        }
        if excludedTrailingWidth > 0, localPoint.x > bounds.width - excludedTrailingWidth {
            return false
        }
        return true
    }
}

/// Drag surface for a panel title bar. Double-click toggles windowshade; drag moves the window.
///
/// `excludedLeadingWidth` / `excludedTrailingWidth` are holes in hit-testing so SwiftUI buttons
/// drawn in the same title bar still receive clicks (`NSView` hit-testing otherwise steals them).
final class DraggableWindowView: NSView {
    nonisolated(unsafe) var excludedLeadingWidth: CGFloat = 0
    nonisolated(unsafe) var excludedTrailingWidth: CGFloat = 0
    nonisolated(unsafe) private var cachedFrame: CGRect = .zero
    nonisolated(unsafe) private var cachedBounds: CGRect = .zero

    override func layout() {
        super.layout()
        self.cacheHitGeometry()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.cacheHitGeometry()
    }

    private func cacheHitGeometry() {
        self.cachedFrame = self.frame
        self.cachedBounds = self.bounds
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        if event.clickCount == 2 {
            AmpXPanelWindowManager.shared.handleTitleBarDoubleClick(for: window)
            return
        }
        AmpXPanelWindowManager.shared.startDrag(leading: window, event: event)
    }

    nonisolated override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    nonisolated override func hitTest(_ point: NSPoint) -> NSView? {
        let local = TitleBarHitTesting.localPoint(
            superviewPoint: point,
            frameInSuperview: self.cachedFrame
        )
        guard TitleBarHitTesting.shouldReceiveHit(
            localPoint: local,
            bounds: self.cachedBounds,
            excludedLeadingWidth: self.excludedLeadingWidth,
            excludedTrailingWidth: self.excludedTrailingWidth
        ) else {
            return nil
        }
        return self
    }
}

struct DraggableWindowViewRepresentable: NSViewRepresentable {
    var excludedLeadingWidth: CGFloat = 0
    var excludedTrailingWidth: CGFloat = 0

    func makeNSView(context _: Context) -> DraggableWindowView {
        let view = DraggableWindowView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.excludedLeadingWidth = self.excludedLeadingWidth
        view.excludedTrailingWidth = self.excludedTrailingWidth
        return view
    }

    func updateNSView(_ nsView: DraggableWindowView, context _: Context) {
        nsView.excludedLeadingWidth = self.excludedLeadingWidth
        nsView.excludedTrailingWidth = self.excludedTrailingWidth
    }
}

/// Full-bleed title-bar drag handle with leading/trailing hit-test holes for window controls.
struct PanelTitleBarDragOverlay: View {
    var excludedLeadingWidth: CGFloat = 0
    var excludedTrailingWidth: CGFloat = 0

    var body: some View {
        DraggableWindowViewRepresentable(
            excludedLeadingWidth: self.excludedLeadingWidth,
            excludedTrailingWidth: self.excludedTrailingWidth
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }
}
