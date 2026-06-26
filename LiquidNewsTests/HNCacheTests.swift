import XCTest
@testable import LiquidNews

final class HNCacheTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HNCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Records calls and returns canned items.
    private final class FakeFetcher: HNFetching, @unchecked Sendable {
        var itemsByID: [Int: HNItem] = [:]
        var feedIDs: [StoryCategory: [Int]] = [:]
        private(set) var fetchedIDs: [Int] = []

        func item(id: Int) async throws -> HNItem {
            fetchedIDs.append(id)
            guard let item = itemsByID[id] else { throw URLError(.fileDoesNotExist) }
            return item
        }
        func items(ids: [Int]) async throws -> [HNItem] {
            var result: [HNItem] = []
            for id in ids { result.append(try await item(id: id)) }
            return result
        }
        func storyIDs(for category: StoryCategory) async throws -> [Int] {
            feedIDs[category] ?? []
        }
    }

    private func makeCache(_ fetcher: FakeFetcher) -> HNCache {
        HNCache(disk: DiskCache(directory: tempDir, sizeCap: 1_000_000), fetcher: fetcher)
    }

    func test_cachedItem_returnsNilBeforeStore() async {
        let cache = makeCache(FakeFetcher())
        let item = await cache.cachedItem(id: 1)
        XCTAssertNil(item)
    }

    func test_storeItem_thenCachedItem_roundTrips() async {
        let cache = makeCache(FakeFetcher())
        let story = HNItem(id: 1, type: .story, title: "Hello", score: 10)
        await cache.storeItem(story, fillSource: .readThrough, pinned: false)
        let read = await cache.cachedItem(id: 1)
        XCTAssertEqual(read?.id, 1)
        XCTAssertEqual(read?.title, "Hello")
        XCTAssertEqual(read?.score, 10)
    }

    func test_storeArticle_thenCachedArticle_roundTrips() async {
        let cache = makeCache(FakeFetcher())
        let article = ReadabilityArticle(
            title: "T", byline: "me", content: "<p>body</p>",
            excerpt: "x", siteName: "site", url: URL(string: "https://example.com")!
        )
        await cache.storeArticle(article, id: 5, fillSource: .readLater, pinned: true)
        let read = await cache.cachedArticle(id: 5)
        XCTAssertEqual(read?.title, "T")
        XCTAssertEqual(read?.content, "<p>body</p>")
    }

    func test_storeFeed_thenCachedFeed_roundTrips() async {
        let cache = makeCache(FakeFetcher())
        await cache.storeFeed([3, 1, 2], category: .top, fillSource: .readThrough)
        let read = await cache.cachedFeed(.top)
        XCTAssertEqual(read, [3, 1, 2])
    }

    func test_prefetch_fetchesAndStoresAllIDs() async {
        let fetcher = FakeFetcher()
        fetcher.itemsByID = [
            1: HNItem(id: 1, type: .story, title: "A"),
            2: HNItem(id: 2, type: .story, title: "B"),
        ]
        let cache = makeCache(fetcher)
        await cache.prefetch(ids: [1, 2], pinned: true, fillSource: .offlineDownload)
        let a = await cache.cachedItem(id: 1)
        let b = await cache.cachedItem(id: 2)
        XCTAssertEqual(a?.title, "A")
        XCTAssertEqual(b?.title, "B")
    }

    func test_prefetch_skipsFailuresWithoutThrowing() async {
        let fetcher = FakeFetcher()
        fetcher.itemsByID = [1: HNItem(id: 1, type: .story, title: "A")]  // id 2 absent → throws
        let cache = makeCache(fetcher)
        await cache.prefetch(ids: [1, 2], pinned: false, fillSource: .backgroundPrefetch)
        let a = await cache.cachedItem(id: 1)
        let b = await cache.cachedItem(id: 2)
        XCTAssertNotNil(a)
        XCTAssertNil(b)
    }

    func test_prefetchThread_fetchesDownToRequestedLevels() async {
        let fetcher = FakeFetcher()
        // Tree: top-level [10, 11]; 10 → [100]; 100 → [1000]; 11 has no replies.
        fetcher.itemsByID = [
            10:   HNItem(id: 10,   type: .comment, kids: [100]),
            11:   HNItem(id: 11,   type: .comment),
            100:  HNItem(id: 100,  type: .comment, kids: [1000]),
            1000: HNItem(id: 1000, type: .comment),
        ]
        let cache = makeCache(fetcher)
        // levels: 2 → fetch top-level (10, 11) and their direct replies (100), but NOT 1000.
        await cache.prefetchThread(rootKidIDs: [10, 11], levels: 2, pinned: true, fillSource: .offlineDownload)
        let ten = await cache.cachedItem(id: 10)
        let eleven = await cache.cachedItem(id: 11)
        let hundred = await cache.cachedItem(id: 100)
        let thousand = await cache.cachedItem(id: 1000)
        XCTAssertNotNil(ten)
        XCTAssertNotNil(eleven)
        XCTAssertNotNil(hundred, "direct replies (level 2) must be cached")
        XCTAssertNil(thousand, "level 3 must NOT be fetched when levels == 2")
    }

    func test_prefetchThread_skipsMissingWithoutAbortingWalk() async {
        let fetcher = FakeFetcher()
        // 10 succeeds and has a reply 100; 11 is absent (throws) but must not stop the walk.
        fetcher.itemsByID = [
            10:  HNItem(id: 10,  type: .comment, kids: [100]),
            100: HNItem(id: 100, type: .comment),
        ]
        let cache = makeCache(fetcher)
        await cache.prefetchThread(rootKidIDs: [10, 11], levels: 3, pinned: true, fillSource: .offlineDownload)
        let ten = await cache.cachedItem(id: 10)
        let eleven = await cache.cachedItem(id: 11)
        let hundred = await cache.cachedItem(id: 100)
        XCTAssertNotNil(ten)
        XCTAssertNil(eleven)
        XCTAssertNotNil(hundred, "reply of a surviving comment is still fetched")
    }
}
