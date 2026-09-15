import AppKit

/// Borderless host window that can still become key, so keyboard shortcuts and focus reach it.
/// Plain borderless `NSWindow`s refuse key and main status.
final class AmpXHostWindow: NSWindow {
    /// True while a mouse-down is being dispatched; clicked controls use it to refuse keyboard focus.
    private(set) var isDispatchingMouseDown = false

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            self.isDispatchingMouseDown = true
            defer { self.isDispatchingMouseDown = false }
            super.sendEvent(event)
        default:
            super.sendEvent(event)
        }
    }
}
