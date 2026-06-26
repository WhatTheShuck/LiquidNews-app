import XCTest
@testable import LiquidNews

final class DiskCacheTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_storeThenRead_roundTrips() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        let payload = Data("hello".utf8)
        try await cache.store(payload, for: .item(1), fillSource: .readThrough, pinned: false)
        let read = await cache.data(for: .item(1))
        XCTAssertEqual(read, payload)
    }

    func test_data_returnsNilForMissingKey() async {
        let cache = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        let read = await cache.data(for: .item(99))
        XCTAssertNil(read)
    }

    func test_store_evictsLeastRecentlyAccessedUnpinnedWhenOverCap() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 250)
        try await cache.store(Data(count: 100), for: .item(1), fillSource: .readThrough, pinned: false)
        try await cache.store(Data(count: 100), for: .item(2), fillSource: .readThrough, pinned: false)
        // Touch item 1 so item 2 becomes the least-recently-accessed.
        _ = await cache.data(for: .item(1))
        // Third store pushes total to 300 > 250 → item 2 (oldest access) evicted.
        try await cache.store(Data(count: 100), for: .item(3), fillSource: .readThrough, pinned: false)

        let a = await cache.data(for: .item(1))
        let b = await cache.data(for: .item(2))
        let c = await cache.data(for: .item(3))
        XCTAssertNotNil(a)
        XCTAssertNil(b)
        XCTAssertNotNil(c)
    }

    func test_pinnedEntries_surviveEvictionEvenOverCap() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 150)
        try await cache.store(Data(count: 200), for: .item(1), fillSource: .offlineDownload, pinned: true)
        try await cache.store(Data(count: 200), for: .item(2), fillSource: .readThrough, pinned: false)
        let pinned = await cache.data(for: .item(1))
        let unpinned = await cache.data(for: .item(2))
        XCTAssertNotNil(pinned, "pinned content must never be evicted")
        XCTAssertNil(unpinned)
    }

    func test_clearUnpinned_removesOnlyUnpinned() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        try await cache.store(Data(count: 10), for: .item(1), fillSource: .offlineDownload, pinned: true)
        try await cache.store(Data(count: 10), for: .item(2), fillSource: .readThrough, pinned: false)
        await cache.clearUnpinned()
        let pinned = await cache.data(for: .item(1))
        let unpinned = await cache.data(for: .item(2))
        XCTAssertNotNil(pinned)
        XCTAssertNil(unpinned)
    }

    func test_setPinnedFalse_makesEntryEvictable() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 150)
        try await cache.store(Data(count: 200), for: .item(1), fillSource: .offlineDownload, pinned: true)
        await cache.setPinned(false, for: .item(1))
        // Now over cap with no pin → next store triggers its eviction.
        try await cache.store(Data(count: 10), for: .item(2), fillSource: .readThrough, pinned: false)
        let formerlyPinned = await cache.data(for: .item(1))
        XCTAssertNil(formerlyPinned)
    }

    func test_usage_reportsBreakdown() async throws {
        let cache = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        try await cache.store(Data(count: 100), for: .item(1), fillSource: .readThrough, pinned: false)
        try await cache.store(Data(count: 300), for: .article(1), fillSource: .offlineDownload, pinned: true)
        let usage = await cache.usage()
        XCTAssertEqual(usage.totalBytes, 400)
        XCTAssertEqual(usage.itemBytes, 100)
        XCTAssertEqual(usage.articleBytes, 300)
        XCTAssertEqual(usage.pinnedBytes, 300)
    }

    func test_indexSurvivesReinitFromSameDirectory() async throws {
        let first = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        try await first.store(Data("persist".utf8), for: .item(7), fillSource: .readThrough, pinned: false)
        // A fresh instance over the same directory must load the persisted index + blob.
        let second = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        let read = await second.data(for: .item(7))
        XCTAssertEqual(read, Data("persist".utf8))
    }

    func test_corruptIndexIsRebuiltFromDiskWithoutDataLoss() async throws {
        let first = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        try await first.store(Data("keepme".utf8), for: .item(8), fillSource: .readThrough, pinned: false)
        // Corrupt the index file.
        let indexURL = tempDir.appendingPathComponent("index.json")
        try Data("not json".utf8).write(to: indexURL)
        // New instance must rebuild by scanning, not wipe the blob.
        let second = DiskCache(directory: tempDir, sizeCap: 1_000_000)
        let read = await second.data(for: .item(8))
        XCTAssertEqual(read, Data("keepme".utf8))
    }
}
