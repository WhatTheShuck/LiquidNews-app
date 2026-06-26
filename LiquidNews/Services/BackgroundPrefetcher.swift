// BackgroundPrefetcher.swift
// Opt-in: refreshes enabled feeds and prefetches their top stories when on WiFi, so
// feeds/discussions stay offline-ready. Unpinned — ordinary LRU keeps it bounded.

import Foundation

enum BackgroundPrefetcher {

    /// Stories per feed to keep warm.
    private static let depth = 30

    static func runIfEnabled() async {
        let settings = UserSettings.shared
        guard settings.backgroundFeedPrefetch,
              NetworkMonitor.shared.currentlyOnWifi() else { return }

        for category in settings.orderedEnabledCategories {
            guard let ids = try? await HNAPIService.shared.storyIDs(for: category) else { continue }
            await HNCache.shared.storeFeed(ids, category: category, fillSource: .backgroundPrefetch)
            let top = Array(ids.prefix(depth))
            await HNCache.shared.prefetch(ids: top, pinned: false, fillSource: .backgroundPrefetch)
            // NOTE: Background article-body extraction (the `backgroundPrefetchArticles`
            // opt-in) is deferred along with the rest of article caching — the live
            // reader (ArticleReaderView) uses its own extraction pipeline rather than the
            // standalone ArticleExtractor, so there is no usable bulk-extraction seam yet.
            // Feed + item/comment prefetch above is fully functional.
        }
    }
}
