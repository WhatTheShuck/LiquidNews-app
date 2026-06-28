import XCTest
@testable import LiquidNews

final class CoachMarkStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "CoachMarkStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func test_unseenByDefault() {
        let store = CoachMarkStore(defaults: defaults)
        XCTAssertFalse(store.hasSeen(.storySwipe))
    }

    func test_markSeen_persists() {
        let store = CoachMarkStore(defaults: defaults)
        store.markSeen(.storySwipe)
        XCTAssertTrue(store.hasSeen(.storySwipe))
        XCTAssertTrue(CoachMarkStore(defaults: defaults).hasSeen(.storySwipe))
    }

    func test_seenMarks_reflectsState() {
        let store = CoachMarkStore(defaults: defaults)
        store.markSeen(.storySwipe)
        store.markSeen(.commentLongPress)
        XCTAssertEqual(store.seenMarks(), [.storySwipe, .commentLongPress])
    }

    func test_replayAll_clearsEveryFlag() {
        let store = CoachMarkStore(defaults: defaults)
        for mark in CoachMark.allCases { store.markSeen(mark) }
        store.replayAll()
        for mark in CoachMark.allCases {
            XCTAssertFalse(store.hasSeen(mark), "\(mark) should be cleared")
        }
    }
}
