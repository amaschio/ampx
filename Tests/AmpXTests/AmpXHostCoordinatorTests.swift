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
        let coordinator = makeCoordinator()
        for moduleID in AmpXModuleID.allCases {
            XCTAssertNotNil(coordinator.moduleView(for: moduleID))
        }
    }

    func testCloseModuleUpdatesStateAndPersists() {
        let (defaults, name) = isolatedDefaults()
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
        let coordinator = makeCoordinator()
        coordinator.closeModule(.playlist)
        coordinator.reopenModule(.playlist)
        XCTAssertFalse(coordinator.state.closed.contains(.playlist))
    }

    func testSetCollapsedUpdatesStateAndPersists() {
        let (defaults, name) = isolatedDefaults()
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
        let coordinator = makeCoordinator()
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
        let (defaults, name) = isolatedDefaults()
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
            screen: testScreen()
        )
        coordinator.showStack()

        XCTAssertEqual(coordinator.stackWindowFrame?.origin, savedFrame.origin)
        XCTAssertEqual(coordinator.stackWindowFrame?.width, savedFrame.width)
    }

    func testDockReopenShowsStackWhenHidden() {
        let coordinator = makeCoordinator()
        coordinator.showStack()
        coordinator.closeStack()
        XCTAssertFalse(coordinator.isStackVisible)

        coordinator.showStack()
        XCTAssertTrue(coordinator.isStackVisible)
    }

    private func makeCoordinator() -> AmpXHostCoordinator {
        AmpXHostCoordinator(
            state: AmpXModuleOrder(),
            skin: ClassicModernSkin(),
            screen: testScreen()
        )
    }

    private func testScreen() -> NSScreen {
        NSScreen.main!
    }
}
