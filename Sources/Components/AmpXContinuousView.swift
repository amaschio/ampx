import AppKit
import QuartzCore

/// Deliberately not `@MainActor`, and the work hops through a real `Task`: AppKit calls this `@objc`
/// selector from its display-link callback with no Swift task, and on macOS 26 the executor check
/// then crashes in `swift_task_isCurrentExecutor` — both at an isolated entry point and inside
/// `MainActor.assumeIsolated`. Entering a task gives the check a valid context (see commit 5562af8).
final class AmpXDisplayLinkForwarder: NSObject {
    nonisolated(unsafe) weak var view: AmpXContinuousView?

    @objc func displayLinkFired(_ link: CADisplayLink) {
        // Only the timestamp crosses the boundary; `CADisplayLink` is not Sendable.
        let timestamp = link.timestamp
        let view = self.view
        Task { @MainActor in
            view?.displayLinkTick(at: timestamp)
        }
    }
}

@MainActor
class AmpXContinuousView: AmpXDrawingView {
    typealias DisplayLinkFactory = (NSView, AnyObject, Selector) -> CADisplayLink?
    typealias DisplayLinkStarter = (CADisplayLink) -> Void
    typealias DisplayLinkStopper = (CADisplayLink) -> Void

    var displayLinkFactory: DisplayLinkFactory = { view, target, selector in
        view.displayLink(target: target, selector: selector)
    }

    var displayLinkStarter: DisplayLinkStarter = { link in
        link.add(to: .main, forMode: .common)
    }

    var displayLinkStopper: DisplayLinkStopper = { link in
        link.invalidate()
    }

    private var isEffectivelyVisible = false
    private var activeDisplayLink: CADisplayLink?
    private var displayLinkForwarder: AmpXDisplayLinkForwarder?

    /// True while an idle gate has parked the display link although the view is still visible.
    private(set) var isContinuousRenderingPaused = false

    func setEffectivelyVisible(_ value: Bool) {
        guard value != self.isEffectivelyVisible else { return }
        self.isEffectivelyVisible = value
        if value, !self.isContinuousRenderingPaused {
            self.startContinuousRendering()
        } else if !value {
            self.stopContinuousRendering()
        }
    }

    /// Parks or resumes the display link without changing effective visibility, so an idle gate can
    /// stop redrawing a static image and wake it again when audio returns.
    func setContinuousRenderingPaused(_ paused: Bool) {
        guard paused != self.isContinuousRenderingPaused else { return }
        self.isContinuousRenderingPaused = paused
        guard self.isEffectivelyVisible else { return }
        if paused {
            self.stopContinuousRendering()
        } else {
            self.startContinuousRendering()
        }
    }

    func tick(at _: TimeInterval) {
        setNeedsDisplay(bounds)
    }

    fileprivate func displayLinkTick(at time: TimeInterval) {
        self.tick(at: time)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, self.isEffectivelyVisible {
            self.setEffectivelyVisible(false)
        }
    }

    private func startContinuousRendering() {
        self.stopContinuousRendering()

        let forwarder = AmpXDisplayLinkForwarder()
        forwarder.view = self
        self.displayLinkForwarder = forwarder

        guard let link = displayLinkFactory(
            self,
            forwarder,
            #selector(AmpXDisplayLinkForwarder.displayLinkFired(_:))
        ) else { return }

        self.activeDisplayLink = link
        self.displayLinkStarter(link)
    }

    private func stopContinuousRendering() {
        guard let link = activeDisplayLink else { return }
        self.displayLinkStopper(link)
        self.activeDisplayLink = nil
        self.displayLinkForwarder = nil
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            if let link = activeDisplayLink {
                displayLinkStopper(link)
            }
        }
    }
}
