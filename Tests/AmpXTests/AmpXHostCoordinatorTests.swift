@testable import AmpX
import XCTest

@MainActor
final class AmpXHostCoordinatorTests: XCTestCase {
    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "AmpXHostCoordinatorTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    private func cleanup(_ name: String) {
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }

    func testModuleViewsAreCreatedForEveryModule() {
        let coordinator = self.makeCoordinator()
        for moduleID in AmpXModuleID.allCases {
            XCTAssertNotNil(coordinator.moduleView(for: moduleID))
        }
    }

    func testCloseModuleUpdatesStateAndPersists() {
        let (defaults, name) = self.isolatedDefaults()
        defer { cleanup(name) }

        let store = AmpXLayoutStore(defaults: defaults, screen: testScreen())
        let coordinator = AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            layoutStore: store,
            screen: testScreen()
        )

        coordinator.closeModule(.equalizer)
        XCTAssertTrue(coordinator.state.closed.contains(.equalizer))

        let loaded = store.load()
        XCTAssertTrue(loaded.state.closed.contains(.equalizer))
    }

    func testReopenModuleRestoresVisibilityState() {
        let coordinator = self.makeCoordinator()
        coordinator.closeModule(.playlist)
        coordinator.reopenModule(.playlist)
        XCTAssertFalse(coordinator.state.closed.contains(.playlist))
    }

    func testSetCollapsedUpdatesStateAndPersists() {
        let (defaults, name) = self.isolatedDefaults()
        defer { cleanup(name) }

        let store = AmpXLayoutStore(defaults: defaults, screen: testScreen())
        let coordinator = AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            layoutStore: store,
            screen: testScreen()
        )

        coordinator.setCollapsed(.equalizer, true)
        XCTAssertTrue(coordinator.state.collapsed.contains(.equalizer))

        let loaded = store.load()
        XCTAssertTrue(loaded.state.collapsed.contains(.equalizer))
    }

    func testCloseStackHidesWindowButRetainsControllerAndState() {
        let coordinator = self.makeCoordinator()
        coordinator.showStack()
        XCTAssertTrue(coordinator.isStackVisible)

        coordinator.closeModule(.equalizer)
        coordinator.closeStack()

        XCTAssertFalse(coordinator.isStackVisible)
        XCTAssertNotNil(coordinator.moduleView(for: .player))
        XCTAssertTrue(coordinator.state.closed.contains(.equalizer))

        coordinator.showStack()
        XCTAssertTrue(coordinator.isStackVisible)
    }

    func testShowStackUsesSavedFrame() {
        let (defaults, name) = self.isolatedDefaults()
        defer { cleanup(name) }

        let savedFrame = CGRect(x: 200, y: 300, width: 490, height: 600)
        let store = AmpXLayoutStore(defaults: defaults, screen: testScreen())
        store.save(
            AmpXSavedLayout(
                state: AmpXModuleOrder(),
                stackFrame: savedFrame,
                detachedFrames: [:],
                playlistViewportHeight: AmpXMetrics.defaultPlaylistViewportHeight
            )
        )

        let coordinator = AmpXHostCoordinator(
            state: store.load().state,
            skin: ClassicModernSkin(),
            layoutStore: store,
            screen: self.testScreen()
        )
        coordinator.showStack()

        // Height follows the composition; the saved left edge, top edge and width are restored.
        XCTAssertEqual(coordinator.stackWindowFrame?.minX, savedFrame.minX)
        XCTAssertEqual(coordinator.stackWindowFrame?.maxY ?? 0, savedFrame.maxY, accuracy: 0.5)
        XCTAssertEqual(coordinator.stackWindowFrame?.width, savedFrame.width)
    }

    func testStackWindowFollowsCompositionHeightWithoutScrolling() throws {
        let (defaults, name) = self.isolatedDefaults()
        defer { cleanup(name) }
        let coordinator = AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            layoutStore: AmpXLayoutStore(defaults: defaults, screen: testScreen()),
            screen: testScreen()
        )
        coordinator.showStack()
        let window = try XCTUnwrap(coordinator.stackWindow)
        let visible = try XCTUnwrap(window.screen ?? NSScreen.main).visibleFrame
        let stackModules = [AmpXModuleID.player, .equalizer, .playlist].compactMap { coordinator.moduleView(for: $0) }
        let compositionBottom = try XCTUnwrap(stackModules.map(\.frame.maxY).max())

        XCTAssertEqual(window.frame.height, compositionBottom, accuracy: 0.5, "Stack window must be as tall as its modules")
        XCTAssertLessThanOrEqual(window.frame.height, visible.height + 0.5, "Stack must fit the screen's visible frame")
        func subviews(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + subviews(of: $0) }
        }
        let stackScrollbars = try subviews(of: XCTUnwrap(window.contentView)).filter {
            $0 is AmpXScrollbar && $0.superview is AmpXStackViewport && !$0.isHidden
        }
        XCTAssertTrue(stackScrollbars.isEmpty, "The module stack must not show a scrollbar")
    }

    func testDockReopenShowsStackWhenHidden() {
        let coordinator = self.makeCoordinator()
        coordinator.showStack()
        coordinator.closeStack()
        XCTAssertFalse(coordinator.isStackVisible)

        coordinator.showStack()
        XCTAssertTrue(coordinator.isStackVisible)
    }

    func testOpenEntheaStateMountsHostOnInit() {
        var state = AmpXModuleOrder()
        state.reopen(.enthea)
        let coordinator = AmpXHostCoordinator(
            state: state,
            skin: ClassicModernSkin(),
            screen: testScreen()
        )
        let content = coordinator.moduleView(for: .enthea)?.content as? EntheaModuleContent
        XCTAssertNotNil(content?.hostViewForTesting)
    }

    func testClosedEntheaStateDoesNotMountHostOnInit() {
        let coordinator = self.makeCoordinator()
        let content = coordinator.moduleView(for: .enthea)?.content as? EntheaModuleContent
        XCTAssertNil(content?.hostViewForTesting)
    }

    private func makeCoordinator() -> AmpXHostCoordinator {
        AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            screen: self.testScreen()
        )
    }

    private func testScreen() -> NSScreen {
        NSScreen.main!
    }
}
