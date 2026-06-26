import XCTest
@testable import LiquidNews

@MainActor
final class OfflineDownloadCoordinatorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineDLTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private final class FakeFetcher: HNFetching, @unchecked Sendable {
        var itemsByID: [Int: HNItem] = [:]
        var feedIDs: [StoryCategory: [Int]] = [:]
        func item(id: Int) async throws -> HNItem {
            guard let i = itemsByID[id] else { throw URLError(.fileDoesNotExist) }
            return i
        }
        func items(ids: [Int]) async throws -> [HNItem] {
            try ids.map { id in
                guard let i = itemsByID[id] else { throw URLError(.fileDoesNotExist) }
                return i
            }
        }
        func storyIDs(for category: StoryCategory) async throws -> [Int] { feedIDs[category] ?? [] }
    }

    func test_download_pinsTopNItemsAcrossSelectedFeeds() async {
        let fetcher = FakeFetcher()
        fetcher.feedIDs = [.top: [1, 2, 3, 4], .show: [10, 11]]
        for id in [1, 2, 3, 4, 10, 11] { fetcher.itemsByID[id] = HNItem(id: id, type: .story, title: "S\(id)") }
        let cache = HNCache(disk: DiskCache(directory: tempDir, sizeCap: 10_000_000), fetcher: fetcher)
        let coordinator = OfflineDownloadCoordinator(fetcher: fetcher, cache: cache, prefetchArticle: { _ in })

        await coordinator.download(plan: OfflinePlan(categories: [.top, .show], depth: 2))

        // depth 2 → top:[1,2], show:[10,11] cached.
        let one = await cache.cachedItem(id: 1)
        let three = await cache.cachedItem(id: 3)   // beyond depth → not fetched
        let ten = await cache.cachedItem(id: 10)
        XCTAssertNotNil(one)
        XCTAssertNil(three)
        XCTAssertNotNil(ten)
        XCTAssertFalse(coordinator.isDownloading)
        XCTAssertNil(coordinator.progress)
    }

    func test_download_invokesArticlePrefetchPerStory() async {
        let fetcher = FakeFetcher()
        fetcher.feedIDs = [.top: [1, 2]]
        fetcher.itemsByID = [1: HNItem(id: 1, type: .story), 2: HNItem(id: 2, type: .story)]
        let cache = HNCache(disk: DiskCache(directory: tempDir, sizeCap: 10_000_000), fetcher: fetcher)

        let box = ArticleCallBox()
        let coordinator = OfflineDownloadCoordinator(fetcher: fetcher, cache: cache, prefetchArticle: { item in
            await box.record(item.id)
        })
        await coordinator.download(plan: OfflinePlan(categories: [.top], depth: 2))
        let recorded = await box.ids
        XCTAssertEqual(Set(recorded), [1, 2])
    }

    /// Regression: a downloaded feed must persist its ID-list snapshot, or the list
    /// view has no way to enumerate the pinned items offline — only the feed the user
    /// happened to browse online would render. (Bug: "other downloaded feeds don't load".)
    func test_download_persistsFeedIDListForEachSelectedFeed() async {
        let fetcher = FakeFetcher()
        fetcher.feedIDs = [.top: [1, 2, 3, 4], .show: [10, 11]]
        for id in [1, 2, 3, 4, 10, 11] { fetcher.itemsByID[id] = HNItem(id: id, type: .story, title: "S\(id)") }
        let cache = HNCache(disk: DiskCache(directory: tempDir, sizeCap: 10_000_000), fetcher: fetcher)
        let coordinator = OfflineDownloadCoordinator(fetcher: fetcher, cache: cache, prefetchArticle: { _ in })

        await coordinator.download(plan: OfflinePlan(categories: [.top, .show], depth: 2))

        // Each feed's ID-list is cached, capped to the downloaded depth.
        let topFeed = await cache.cachedFeed(.top)
        let showFeed = await cache.cachedFeed(.show)
        XCTAssertEqual(topFeed, [1, 2])
        XCTAssertEqual(showFeed, [10, 11])
    }

    private actor ArticleCallBox {
        private(set) var ids: [Int] = []
        func record(_ id: Int) { ids.append(id) }
    }
}
