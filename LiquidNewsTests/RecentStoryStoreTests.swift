import XCTest
@testable import LiquidNews

final class RecentStoryStoreTests: XCTestCase {

    /// A fresh, isolated UserDefaults suite per test so we never touch real prefs.
    private func makeDefaults() -> UserDefaults {
        let name = "RecentStoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func story(id: Int, title: String?) -> HNItem {
        HNItem(id: id, type: .story, title: title, url: "https://example.com")
    }

    func test_record_storesIdTitleAndDate() {
        let store = RecentStoryStore(defaults: makeDefaults())
        store.record(story(id: 42, title: "Hello"))
        XCTAssertEqual(store.lastStory?.id, 42)
        XCTAssertEqual(store.lastStory?.title, "Hello")
        XCTAssertNotNil(store.lastStory?.savedAt)
    }

    func test_record_overwritesPrevious() {
        let store = RecentStoryStore(defaults: makeDefaults())
        store.record(story(id: 1, title: "First"))
        store.record(story(id: 2, title: "Second"))
        XCTAssertEqual(store.lastStory?.id, 2)
        XCTAssertEqual(store.lastStory?.title, "Second")
    }

    func test_record_noOpWhenTitleMissingOrBlank() {
        let store = RecentStoryStore(defaults: makeDefaults())
        store.record(story(id: 3, title: nil))
        XCTAssertNil(store.lastStory)
        store.record(story(id: 4, title: "   "))
        XCTAssertNil(store.lastStory)
    }

    func test_clear_emptiesStoredStory() {
        let store = RecentStoryStore(defaults: makeDefaults())
        store.record(story(id: 5, title: "Bye"))
        store.clear()
        XCTAssertNil(store.lastStory)
    }

    func test_persistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = RecentStoryStore(defaults: defaults)
        first.record(story(id: 7, title: "Persisted"))
        let second = RecentStoryStore(defaults: defaults)
        XCTAssertEqual(second.lastStory?.id, 7)
        XCTAssertEqual(second.lastStory?.title, "Persisted")
    }

    func test_clearHistory_alsoClearsRecentStory() {
        // RecentStoryStore.shared and SavedPostsStore.shared both back onto the
        // standard defaults; assert the wiring clears the shared recent story.
        RecentStoryStore.shared.record(story(id: 321, title: "To be cleared"))
        XCTAssertNotNil(RecentStoryStore.shared.lastStory)
        SavedPostsStore.shared.clearHistory()
        XCTAssertNil(RecentStoryStore.shared.lastStory)
    }
}
