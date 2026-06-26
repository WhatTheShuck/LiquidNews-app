// HNCache.swift
// HN-aware repository over DiskCache. Owns encoding (HNItem/ReadabilityArticle/feed
// ID-lists as JSON), the write-through path, and the single prefetch fill hook used by
// read-through, Read Later, background prefetch, and offline downloads.

import Foundation

actor HNCache {

    static let shared = HNCache(disk: .shared, fetcher: HNAPIService.shared)

    private let disk: DiskCache
    private let fetcher: any HNFetching
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(disk: DiskCache, fetcher: any HNFetching) {
        self.disk = disk
        self.fetcher = fetcher
    }

    // MARK: - Reads (cache-first)

    func cachedItem(id: Int) async -> HNItem? {
        guard let data = await disk.data(for: .item(id)) else { return nil }
        return try? decoder.decode(HNItem.self, from: data)
    }

    func cachedArticle(id: Int) async -> ReadabilityArticle? {
        guard let data = await disk.data(for: .article(id)) else { return nil }
        return try? decoder.decode(ReadabilityArticle.self, from: data)
    }

    func cachedFeed(_ category: StoryCategory) async -> [Int]? {
        guard let data = await disk.data(for: .feed(category)) else { return nil }
        return try? decoder.decode([Int].self, from: data)
    }

    // MARK: - Write-through

    func storeItem(_ item: HNItem, fillSource: FillSource, pinned: Bool) async {
        guard let data = try? encoder.encode(item) else { return }
        try? await disk.store(data, for: .item(item.id), fillSource: fillSource, pinned: pinned)
    }

    func storeArticle(_ article: ReadabilityArticle, id: Int, fillSource: FillSource, pinned: Bool) async {
        guard let data = try? encoder.encode(article) else { return }
        try? await disk.store(data, for: .article(id), fillSource: fillSource, pinned: pinned)
    }

    func storeFeed(_ ids: [Int], category: StoryCategory, fillSource: FillSource, pinned: Bool = false) async {
        guard let data = try? encoder.encode(ids) else { return }
        try? await disk.store(data, for: .feed(category), fillSource: fillSource, pinned: pinned)
    }

    // MARK: - Pinning

    func setPinnedItem(_ pinned: Bool, id: Int) async {
        await disk.setPinned(pinned, for: .item(id))
    }

    func setPinnedArticle(_ pinned: Bool, id: Int) async {
        await disk.setPinned(pinned, for: .article(id))
    }

    // MARK: - Prefetch hook (the smart-cache integration point)

    /// Fetches each ID over the network and writes it through to the cache with the
    /// given pin/source. Failures are skipped silently (per-ID) so one bad ID never
    /// aborts a batch — fetches run concurrently, then each success is stored.
    func prefetch(ids: [Int], pinned: Bool, fillSource: FillSource) async {
        await fetchAndStore(ids: ids, pinned: pinned, fillSource: fillSource)
    }

    /// Prefetches a comment subtree breadth-first. `rootKidIDs` are the top-level
    /// comment IDs (layer 1); `levels` is the total number of comment layers to fetch
    /// (so `levels: 1` is top-level only, `levels: 3` is top-level + two reply layers).
    /// Every comment is written through with the given pin/source; per-ID failures are
    /// skipped so a single dead comment never aborts the walk.
    func prefetchThread(rootKidIDs: [Int], levels: Int, pinned: Bool, fillSource: FillSource) async {
        var frontier = rootKidIDs
        var remaining = levels
        while remaining > 0, !frontier.isEmpty {
            let fetched = await fetchAndStore(ids: frontier, pinned: pinned, fillSource: fillSource)
            frontier = fetched.flatMap { $0.kids ?? [] }
            remaining -= 1
        }
    }

    /// Concurrently fetches `ids`, writes each success through to the cache, and returns
    /// the fetched items (so callers can walk their `kids`). Per-ID failures are skipped.
    @discardableResult
    private func fetchAndStore(ids: [Int], pinned: Bool, fillSource: FillSource) async -> [HNItem] {
        let fetcher = self.fetcher
        let fetched = await withTaskGroup(of: HNItem?.self) { group in
            for id in ids {
                group.addTask { try? await fetcher.item(id: id) }
            }
            var collected: [HNItem] = []
            for await item in group {
                if let item { collected.append(item) }
            }
            return collected
        }
        for item in fetched {
            await storeItem(item, fillSource: fillSource, pinned: pinned)
        }
        return fetched
    }
}
