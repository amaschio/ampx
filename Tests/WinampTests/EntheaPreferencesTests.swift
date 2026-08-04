import XCTest
@testable import Winamp

final class EntheaPreferencesTests: XCTestCase {
    func testPhotosensitiveWarningDefaultsFalse() {
        let suiteName = "EntheaPreferencesTests.\(#function)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        XCTAssertFalse(EntheaPreferences(defaults: suite).photosensitiveWarningAccepted)
    }

    func testPhotosensitiveWarningPersists() {
        let suiteName = "EntheaPreferencesTests.\(#function)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let prefs = EntheaPreferences(defaults: suite)
        prefs.photosensitiveWarningAccepted = true
        XCTAssertTrue(EntheaPreferences(defaults: suite).photosensitiveWarningAccepted)
    }

    func testBackingScaleClampsToBudget() {
        // Theater-sized panel at Retina would exceed 2.0 Mpx at full DPR.
        let scale = EntheaBackingScale.scale(
            forSize: CGSize(width: 1728, height: 1080),
            screenScale: 2
        )
        XCTAssertLessThan(scale, 1.2)
        XCTAssertGreaterThanOrEqual(scale, 1.0)
    }

    func testBackingScaleAllowsFullDPRAtPanelSize() {
        let scale = EntheaBackingScale.scale(
            forSize: CGSize(width: 600, height: 450),
            screenScale: 2
        )
        XCTAssertEqual(scale, 2, accuracy: 0.01)
    }
}
