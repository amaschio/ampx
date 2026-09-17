@testable import AmpX
import XCTest

/// A continuous view must be able to stop its display link while staying effectively visible, so an
/// idle visualizer costs nothing once audio and its decay tails go quiet.
@MainActor
final class AmpXContinuousViewPauseTests: XCTestCase {
    func testPausingWhileVisibleStopsTheDisplayLink() {
        let view = CountingContinuousView(skin: ClassicModernSkin())
        view.setEffectivelyVisible(true)
        XCTAssertEqual(view.startCount, 1)

        view.setContinuousRenderingPaused(true)

        XCTAssertEqual(view.stopCount, 1)
        XCTAssertTrue(view.isContinuousRenderingPaused)
    }

    func testResumingRestartsTheDisplayLink() {
        let view = CountingContinuousView(skin: ClassicModernSkin())
        view.setEffectivelyVisible(true)
        view.setContinuousRenderingPaused(true)

        view.setContinuousRenderingPaused(false)

        XCTAssertEqual(view.startCount, 2)
        XCTAssertFalse(view.isContinuousRenderingPaused)
    }

    func testPausedViewDoesNotRenderWhenItBecomesVisible() {
        let view = CountingContinuousView(skin: ClassicModernSkin())
        view.setContinuousRenderingPaused(true)
        XCTAssertEqual(view.stopCount, 0, "nothing to stop while the view is not visible")

        view.setEffectivelyVisible(true)

        XCTAssertEqual(view.startCount, 0)
    }
}

private final class CountingContinuousView: AmpXContinuousView {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        displayLinkFactory = { view, target, selector in
            view.displayLink(target: target, selector: selector)
        }
        displayLinkStarter = { [weak self] _ in
            self?.startCount += 1
        }
        displayLinkStopper = { [weak self] _ in
            self?.stopCount += 1
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
