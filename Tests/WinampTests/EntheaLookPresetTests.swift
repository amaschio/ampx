@testable import Winamp
import XCTest

final class EntheaLookPresetTests: XCTestCase {
    func testCatalogHasUniqueIdsMatchingExpectedCount() {
        let ids = EntheaLookPreset.all.map(\.id)
        XCTAssertEqual(ids.count, 14)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testTitlesAvoidRawSubstanceClaimsAsPrimaryLabel() {
        // Menu titles must be phenomenological — not the upstream drug brand/name strings.
        let banned = ["LSD", "DMT", "PSILOCYBIN", "KETAMINE", "MDMA", "AYAHUASCA"]
        for preset in EntheaLookPreset.all {
            for word in banned {
                XCTAssertFalse(
                    preset.title.uppercased().contains(word),
                    "look title \(preset.title) must not contain \(word)"
                )
            }
        }
    }

    func testDisclaimerStatesNotMedical() {
        let text = EntheaLookPreset.disclaimer.lowercased()
        XCTAssertTrue(text.contains("not dosing") || text.contains("not medical"))
        XCTAssertTrue(text.contains("simulator"))
    }

    func testPresetLookup() {
        XCTAssertEqual(EntheaLookPreset.preset(id: "psilo")?.title, "Breathing Organic")
        XCTAssertNil(EntheaLookPreset.preset(id: "nope"))
    }
}
