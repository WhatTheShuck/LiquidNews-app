import XCTest
@testable import LiquidNews

final class CacheIndexTests: XCTestCase {

    private func t(_ secondsFromNow: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: 1_000_000 + secondsFromNow)
    }

    func test_storageID_isStableAndKindScoped() {
        XCTAssertEqual(CacheKey.item(123).storageID, "item:123")
        XCTAssertEqual(CacheKey.article(123).storageID, "article:123")
        XCTAssertEqual(CacheKey.feed(.top).storageID, "feed:Top")
        // item and article with same numeric id must not collide
        XCTAssertNotEqual(CacheKey.item(123).storageID, CacheKey.article(123).storageID)
    }

    func test_upsert_addsEntryAndTracksTotalBytes() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(0))
        index.upsert(key: .item(2), byteSize: 250, fillSource: .readThrough, pinned: false, now: t(0))
        XCTAssertEqual(index.totalBytes, 350)
    }

    func test_upsert_replacesExistingAdjustingTotal() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(0))
        index.upsert(key: .item(1), byteSize: 400, fillSource: .readThrough, pinned: false, now: t(1))
        XCTAssertEqual(index.totalBytes, 400)
    }

    func test_recordAccess_bumpsCountAndTimestamp() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(0))
        index.recordAccess(.item(1), now: t(50))
        let entry = index.entries["item:1"]
        XCTAssertEqual(entry?.accessCount, 1)
        XCTAssertEqual(entry?.lastAccessed, t(50))
    }

    func test_evictionOrder_returnsLeastRecentlyAccessedUnpinnedFirst() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(10))
        index.upsert(key: .item(2), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(30))
        index.upsert(key: .item(3), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(20))
        // cap 150 → must evict enough to drop under: oldest (item 1, t10) then item 3 (t20)
        let order = index.evictionOrder(cap: 150)
        XCTAssertEqual(order, [.item(1), .item(3)])
    }

    func test_evictionOrder_neverEvictsPinnedEvenWhenOverCap() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 200, fillSource: .offlineDownload, pinned: true, now: t(10))
        index.upsert(key: .item(2), byteSize: 200, fillSource: .readThrough, pinned: false, now: t(20))
        // cap 100, but pinned item 1 (200) cannot be evicted; only item 2 is a candidate.
        XCTAssertEqual(index.evictionOrder(cap: 100), [.item(2)])
    }

    func test_evictionOrder_emptyWhenUnderCap() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 50, fillSource: .readThrough, pinned: false, now: t(0))
        XCTAssertTrue(index.evictionOrder(cap: 150).isEmpty)
    }

    func test_setPinned_protectsEntry() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 200, fillSource: .readThrough, pinned: false, now: t(0))
        index.setPinned(true, for: .item(1))
        XCTAssertTrue(index.evictionOrder(cap: 100).isEmpty)
    }

    func test_remove_dropsEntryAndAdjustsTotal() {
        var index = CacheIndex()
        index.upsert(key: .item(1), byteSize: 100, fillSource: .readThrough, pinned: false, now: t(0))
        index.remove(.item(1))
        XCTAssertNil(index.entries["item:1"])
        XCTAssertEqual(index.totalBytes, 0)
    }
}
