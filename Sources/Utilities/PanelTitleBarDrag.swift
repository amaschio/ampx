import AppKit
import SwiftUI

enum AmpXTitleBarMetrics {
    /// Default trailing exclusion for main-window controls when callers don't pass a width.
    static let buttonAreaWidth: CGFloat = 60
}

/// Drag surface for a panel title bar. Double-click toggles windowshade; drag moves the window.
///
/// `excludedLeadingWidth` / `excludedTrailingWidth` are holes in hit-testing so SwiftUI buttons
/// drawn in the same title bar still receive clicks (`NSView` hit-testing otherwise steals them).
final class DraggableWindowView: NSView {
    var excludedLeadingWidth: CGFloat = 0
    var excludedTrailingWidth: CGFloat = 0

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        if event.clickCount == 2 {
            AmpXPanelWindowManager.shared.handleTitleBarDoubleClick(for: window)
            return
        }
        AmpXPanelWindowManager.shared.startDrag(leading: window, event: event)
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // `point` is in the superview's coordinate system.
        let local = self.convert(point, from: self.superview)
        guard self.bounds.width > 0, self.bounds.height > 0, self.bounds.contains(local) else {
            return nil
        }
        if self.excludedLeadingWidth > 0, local.x < self.excludedLeadingWidth {
            return nil
        }
        if self.excludedTrailingWidth > 0, local.x > self.bounds.width - self.excludedTrailingWidth {
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
