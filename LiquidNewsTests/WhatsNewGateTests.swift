import XCTest
@testable import LiquidNews

final class WhatsNewGateTests: XCTestCase {

    func test_olderStoredVersion_shows() {
        XCTAssertTrue(WhatsNewGate.shouldShow(
            storedVersion: "1.0", currentVersion: "1.1", hasSeenOnboarding: true))
    }

    func test_equalVersion_skips() {
        XCTAssertFalse(WhatsNewGate.shouldShow(
            storedVersion: "1.10", currentVersion: "1.10", hasSeenOnboarding: true))
    }

    func test_newerStoredVersion_skips() {
        XCTAssertFalse(WhatsNewGate.shouldShow(
            storedVersion: "2.0", currentVersion: "1.9", hasSeenOnboarding: true))
    }

    func test_numericComparison_1_9_to_1_10_shows() {
        // Lexically "1.9" > "1.10"; numerically "1.9" < "1.10". Must show.
        XCTAssertTrue(WhatsNewGate.shouldShow(
            storedVersion: "1.9", currentVersion: "1.10", hasSeenOnboarding: true))
    }

    func test_emptyStoredVersion_shows() {
        XCTAssertTrue(WhatsNewGate.shouldShow(
            storedVersion: "", currentVersion: "1.0", hasSeenOnboarding: true))
    }

    func test_brandNewUser_onboardingNotYetSeen_skips() {
        XCTAssertFalse(WhatsNewGate.shouldShow(
            storedVersion: "", currentVersion: "1.0", hasSeenOnboarding: false))
    }
}
