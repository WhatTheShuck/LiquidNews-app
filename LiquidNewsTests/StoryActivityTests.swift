import XCTest
@testable import LiquidNews

final class StoryActivityTests: XCTestCase {

    private func story(id: Int) -> HNItem {
        HNItem(id: id, type: .story, title: "Title \(id)")
    }

    func test_make_setsTypeUserInfoWebpageURLAndEligibility() {
        let activity = StoryActivity.make(for: story(id: 1234))
        XCTAssertEqual(activity.activityType, StoryActivity.activityType)
        XCTAssertEqual(activity.userInfo?["id"] as? Int, 1234)
        XCTAssertEqual(
            activity.webpageURL,
            URL(string: "https://news.ycombinator.com/item?id=1234")
        )
        XCTAssertEqual(activity.title, "Title 1234")
        XCTAssertTrue(activity.isEligibleForHandoff)
        XCTAssertFalse(activity.isEligibleForSearch)
    }

    func test_itemID_extractsIdBack() {
        let activity = StoryActivity.make(for: story(id: 555))
        XCTAssertEqual(StoryActivity.itemID(from: activity), 555)
    }

    func test_itemID_nilWhenIdMissing() {
        let activity = NSUserActivity(activityType: StoryActivity.activityType)
        XCTAssertNil(StoryActivity.itemID(from: activity))
    }

    func test_update_refreshesPayloadForNewStory() {
        let activity = StoryActivity.make(for: story(id: 1))
        StoryActivity.update(activity, with: story(id: 2))
        XCTAssertEqual(StoryActivity.itemID(from: activity), 2)
        XCTAssertEqual(
            activity.webpageURL,
            URL(string: "https://news.ycombinator.com/item?id=2")
        )
    }
}
