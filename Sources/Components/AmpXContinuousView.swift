import AppKit
import QuartzCore

@MainActor
final class AmpXDisplayLinkForwarder: NSObject {
    weak var view: AmpXContinuousView?

    @objc func displayLinkFired(_ link: CADisplayLink) {
        view?.displayLinkTick(at: link.timestamp)
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

    func setEffectivelyVisible(_ value: Bool) {
        guard value != isEffectivelyVisible else { return }
        isEffectivelyVisible = value
        if value {
            startContinuousRendering()
        } else {
            stopContinuousRendering()
        }
    }

    func tick(at time: TimeInterval) {
        setNeedsDisplay(bounds)
    }

    fileprivate func displayLinkTick(at time: TimeInterval) {
        tick(at: time)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, isEffectivelyVisible {
            setEffectivelyVisible(false)
        }
    }

    private func startContinuousRendering() {
        stopContinuousRendering()

        let forwarder = AmpXDisplayLinkForwarder()
        forwarder.view = self
        displayLinkForwarder = forwarder

        guard let link = displayLinkFactory(
            self,
            forwarder,
            #selector(AmpXDisplayLinkForwarder.displayLinkFired(_:))
        ) else { return }

        activeDisplayLink = link
        displayLinkStarter(link)
    }

    private func stopContinuousRendering() {
        guard let link = activeDisplayLink else { return }
        displayLinkStopper(link)
        activeDisplayLink = nil
        displayLinkForwarder = nil
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            if let link = activeDisplayLink {
                displayLinkStopper(link)
            }
        }
    }
}
