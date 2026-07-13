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

    /// Regression (DESLOPPIFY C2): Cancel must actually stop an in-flight download.
    /// The coordinator owns the task it starts, so `cancel()` cancels the real download —
    /// items past the one in flight are never fetched.
    func test_cancel_stopsInFlightDownload() async {
        let fetcher = GateFetcher()
        fetcher.feedIDs = [.top: [1, 2, 3]]
        for id in [1, 2, 3] { fetcher.itemsByID[id] = HNItem(id: id, type: .story, title: "S\(id)") }
        let cache = HNCache(disk: DiskCache(directory: tempDir, sizeCap: 10_000_000), fetcher: fetcher)
        let coordinator = OfflineDownloadCoordinator(fetcher: fetcher, cache: cache, prefetchArticle: { _ in })

        let download = coordinator.start(plan: OfflinePlan(categories: [.top], depth: 3))
        await fetcher.gate.waitUntilReached()   // first item fetch is now in flight
        coordinator.cancel()
        await fetcher.gate.open()
        await download.value

        let two = await cache.cachedItem(id: 2)
        let three = await cache.cachedItem(id: 3)
        XCTAssertNil(two, "items after the in-flight one must not be fetched after cancel")
        XCTAssertNil(three, "items after the in-flight one must not be fetched after cancel")
        XCTAssertFalse(coordinator.isDownloading)
        XCTAssertNil(coordinator.progress)
    }

    /// A fetcher whose first `item(id:)` call parks at a gate so the test can cancel
    /// mid-download deterministically, then release the fetch.
    private final class GateFetcher: HNFetching, @unchecked Sendable {
        var itemsByID: [Int: HNItem] = [:]
        var feedIDs: [StoryCategory: [Int]] = [:]
        let gate = Gate()
        func item(id: Int) async throws -> HNItem {
            await gate.waitAtGate()
            guard let i = itemsByID[id] else { throw URLError(.fileDoesNotExist) }
            return i
        }
        func items(ids: [Int]) async throws -> [HNItem] {
            var result: [HNItem] = []
            for id in ids { result.append(try await item(id: id)) }
            return result
        }
        func storyIDs(for category: StoryCategory) async throws -> [Int] { feedIDs[category] ?? [] }
    }

    private actor Gate {
        private var opened = false
        private var reached = false
        private var gateWaiters: [CheckedContinuation<Void, Never>] = []
        private var reachedWaiters: [CheckedContinuation<Void, Never>] = []

        /// Called by the fetcher: signals arrival, then parks until `open()`.
        func waitAtGate() async {
            reached = true
            for c in reachedWaiters { c.resume() }
            reachedWaiters.removeAll()
            if opened { return }
            await withCheckedContinuation { gateWaiters.append($0) }
        }

        /// Called by the test: suspends until the fetcher has arrived at the gate.
        func waitUntilReached() async {
            if reached { return }
            await withCheckedContinuation { reachedWaiters.append($0) }
        }

        func open() {
            opened = true
            for c in gateWaiters { c.resume() }
            gateWaiters.removeAll()
        }
    }
}
