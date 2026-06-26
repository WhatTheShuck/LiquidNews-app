// OfflineDownloadCoordinator.swift
// Drives the "Prepare for offline" bulk download: for each selected feed, fetch the
// top-N story IDs and pin their items (+ comments + article) into the cache, publishing
// progress. Article extraction is injected so the testable core stays UI-free.

import Foundation
import Observation

struct OfflinePlan: Equatable, Sendable {
    var categories: [StoryCategory]
    var depth: Int
}

@Observable
@MainActor
final class OfflineDownloadCoordinator {

    static let shared = OfflineDownloadCoordinator(
        fetcher: HNAPIService.shared,
        cache: .shared,
        prefetchArticle: { item in
            // Production article extraction is wired in Task 14 (UI). Default no-op keeps
            // the coordinator usable before that wiring exists.
            _ = item
        }
    )

    /// Comment layers cached per story (top-level + reply layers). Layer 1 is the
    /// top-level comments, so 3 keeps the top level plus two reply layers offline.
    static let commentLayers = 3

    var progress: (done: Int, total: Int)?
    var isDownloading = false

    private let fetcher: HNFetching
    private let cache: HNCache
    private let prefetchArticle: @Sendable (HNItem) async -> Void
    private var task: Task<Void, Never>?

    init(fetcher: HNFetching, cache: HNCache, prefetchArticle: @escaping @Sendable (HNItem) async -> Void) {
        self.fetcher = fetcher
        self.cache = cache
        self.prefetchArticle = prefetchArticle
    }

    func cancel() {
        task?.cancel()
        task = nil
        isDownloading = false
        progress = nil
    }

    func download(plan: OfflinePlan) async {
        isDownloading = true
        defer { isDownloading = false; progress = nil }

        // Resolve the ID set for each feed up front so we know the total. Persist each
        // feed's (depth-capped) ID-list snapshot, pinned, so the list view can enumerate
        // the pinned items offline — without this, a downloaded feed has cached items but
        // no list to render them from.
        var allIDs: [Int] = []
        for category in plan.categories {
            let ids = (try? await fetcher.storyIDs(for: category)) ?? []
            let capped = Array(ids.prefix(plan.depth))
            await cache.storeFeed(capped, category: category, fillSource: .offlineDownload, pinned: true)
            allIDs.append(contentsOf: capped)
        }
        // De-dupe while preserving order (a story can appear in multiple feeds).
        var seen = Set<Int>()
        let uniqueIDs = allIDs.filter { seen.insert($0).inserted }

        progress = (done: 0, total: uniqueIDs.count)

        for (offset, id) in uniqueIDs.enumerated() {
            if Task.isCancelled { return }
            await cache.prefetch(ids: [id], pinned: true, fillSource: .offlineDownload)
            if let story = await cache.cachedItem(id: id) {
                if let kids = story.kids {
                    await cache.prefetchThread(
                        rootKidIDs: Array(kids.prefix(20)),
                        levels: Self.commentLayers,
                        pinned: true,
                        fillSource: .offlineDownload
                    )
                }
                await prefetchArticle(story)
            }
            progress = (done: offset + 1, total: uniqueIDs.count)
        }
    }
}
