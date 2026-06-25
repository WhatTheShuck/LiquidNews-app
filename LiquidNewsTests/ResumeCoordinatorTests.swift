import XCTest
@testable import LiquidNews

final class ResumeCoordinatorTests: XCTestCase {

    private func recent(id: Int = 99) -> RecentStory {
        RecentStory(id: id, title: "Last", savedAt: .now)
    }

    func test_off_returnsNone_evenWithLastStory() {
        let c = ResumeCoordinator()
        XCTAssertEqual(c.decide(mode: .off, lastStory: recent()), .none)
    }

    func test_prompt_withLastStory_returnsBanner() {
        let c = ResumeCoordinator()
        let story = recent()
        XCTAssertEqual(c.decide(mode: .prompt, lastStory: story), .banner(story))
    }

    func test_prompt_withoutLastStory_returnsNone() {
        let c = ResumeCoordinator()
        XCTAssertEqual(c.decide(mode: .prompt, lastStory: nil), .none)
    }

    func test_auto_withLastStory_returnsAutoOpen() {
        let c = ResumeCoordinator()
        XCTAssertEqual(c.decide(mode: .auto, lastStory: recent(id: 7)), .autoOpen(id: 7))
    }

    func test_suppression_deepLinkConsumed_returnsNoneForEveryMode() {
        for mode in ResumeMode.allCases {
            let c = ResumeCoordinator()
            c.markDeepLinkConsumed()
            XCTAssertEqual(c.decide(mode: mode, lastStory: recent()), .none)
        }
    }

    func test_oneShot_secondDecideReturnsNone_evenForAuto() {
        let c = ResumeCoordinator()
        _ = c.decide(mode: .auto, lastStory: recent(id: 5))
        XCTAssertEqual(c.decide(mode: .auto, lastStory: recent(id: 5)), .none)
    }
}
