import XCTest
@testable import LiquidNews

final class CoachMarkEligibilityTests: XCTestCase {

    func test_returnsFirstUnseenAnchoredMark_inOrder() {
        let result = firstEligibleCoachMark(
            in: [.readArticleLongPress, .commentLongPress],
            seen: [],
            anchored: [.readArticleLongPress, .commentLongPress])
        XCTAssertEqual(result, .readArticleLongPress)
    }

    func test_skipsSeenMarks() {
        let result = firstEligibleCoachMark(
            in: [.readArticleLongPress, .commentLongPress],
            seen: [.readArticleLongPress],
            anchored: [.readArticleLongPress, .commentLongPress])
        XCTAssertEqual(result, .commentLongPress)
    }

    func test_skipsMarksWithoutAnchor() {
        // First mark unseen but not anchored (scrolled off / not yet rendered).
        let result = firstEligibleCoachMark(
            in: [.readArticleLongPress, .commentLongPress],
            seen: [],
            anchored: [.commentLongPress])
        XCTAssertEqual(result, .commentLongPress)
    }

    func test_returnsNil_whenNoneEligible() {
        let result = firstEligibleCoachMark(
            in: [.readArticleLongPress],
            seen: [.readArticleLongPress],
            anchored: [.readArticleLongPress])
        XCTAssertNil(result)
    }
}
