// CuratedStore.swift
// Orchestrates all curated feed sources: fetching, caching, dedup, and pagination.
//
// ┌─────────────────────────────────────────────────────────────────┐
// │ Refresh rates                                                   │
// │   Newsletter RSS  : at most every 6 hours (it's weekly)        │
// │   JSON feeds      : at most every 15 minutes + HTTP ETag/304   │
// │                                                                 │
// │ Cache files (in Caches/LN_Curated/)                            │
// │   entries.json          — all merged CuratedEntry[], sorted    │
// │   rss_items.json        — raw HNLRSSParser.RSSItem[] for paging│
// │   json_feeds/{id}.json  — per-feed JSONFeedCacheEntry          │
// │                                                                 │
// │ Dedup                                                           │
// │   entriesByID: [String: CuratedEntry] is the source of truth.  │
// │   `entries` is a derived sorted view rebuilt after each merge. │
// │   Two entries with the same normalised URL are the same story. │
// └─────────────────────────────────────────────────────────────────┘

import Foundation

@MainActor
@Observable
final class CuratedStore {

    static let shared = CuratedStore()
    private init() { setupCacheDirectories() }

    // MARK: - Observable state

    private(set) var entries: [CuratedEntry] = []
    private(set) var isLoadingInitial = false
    private(set) var isRefreshing     = false
    private(set) var isLoadingMore    = false
    private(set) var canLoadMore      = false
    private(set) var error: String?   = nil

    // MARK: - Internal state

    /// Dedup index. All mutations go through `mergeEntries(_:)`.
    private var entriesByID: [String: CuratedEntry] = [:]

    /// Raw RSS items from the last fetch, persisted for cross-session lazy pagination.
    private var rssItems: [HNLRSSParser.RSSItem] = []

    /// Index into `rssItems` for the next "load more" page.
    private var nextRSSPage = 0

    /// Issue numbers whose entries are already merged into `entriesByID`.
    private var parsedIssueNumbers: Set<Int> = []

    // MARK: - Public API

    /// Called once when the Curated view appears. Loads cache first, then refreshes stale sources.
    func initialLoad(settings: UserSettings) async {
        guard !isLoadingInitial else { return }
        isLoadingInitial = true
        defer { isLoadingInitial = false }

        // Step 1: restore from disk immediately (gives instant display).
        restoreFromDisk(settings: settings)

        // Step 2: refresh anything stale in the background.
        await performRefresh(settings: settings, force: false)
    }

    /// Pull-to-refresh: forces a re-check of all sources.
    func refresh(settings: UserSettings) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        error = nil
        await performRefresh(settings: settings, force: true)
    }

    /// Loads the next older newsletter issue. Called when user scrolls to the bottom.
    func loadMore() async {
        guard !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadNextNewsletterPage()
    }

    // MARK: - Refresh orchestration

    private func performRefresh(settings: UserSettings, force: Bool) async {
        // Run newsletter + JSON feed refreshes concurrently.
        await withTaskGroup(of: Void.self) { group in
            if settings.enabledBuiltInCuratedSources.contains(BuiltInCuratedSource.hackerNewsletter.rawValue) {
                group.addTask { await self.refreshNewsletter(force: force) }
            }
            group.addTask { await self.refreshJSONFeeds(settings: settings, force: force) }
        }
    }

    // MARK: - Newsletter

    private func refreshNewsletter(force: Bool) async {
        guard force || newsletterIsStale() else { return }

        do {
            let items = try await HackerNewsletterService.shared.fetchRSSItems()
            rssItems = items
            saveRSSItemsCache(items)
            markNewsletterChecked()

            // Find the newest issue not yet parsed and display it.
            // We only parse one new issue at a time; the user triggers further loads.
            for (i, item) in items.enumerated() {
                let number = HackerNewsletterService.shared.extractIssueNumber(from: item.title)
                guard !parsedIssueNumbers.contains(number) else { continue }

                // HTML parsing is the expensive step — do it off-main then update state.
                let issue = await Task.detached(priority: .userInitiated) {
                    HackerNewsletterService.shared.parseIssue(from: item)
                }.value

                let newEntries = issue.entries.map {
                    CuratedEntry.from($0, issueNumber: issue.issueNumber, date: issue.pubDate)
                }
                mergeEntries(newEntries)
                parsedIssueNumbers.insert(number)
                nextRSSPage = i + 1
                break   // Stop after first new issue; user triggers the rest via loadMore().
            }

            canLoadMore = nextRSSPage < items.count

        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadNextNewsletterPage() async {
        guard nextRSSPage < rssItems.count else {
            canLoadMore = false
            return
        }

        let item = rssItems[nextRSSPage]
        let issue = await Task.detached(priority: .userInitiated) {
            HackerNewsletterService.shared.parseIssue(from: item)
        }.value

        let newEntries = issue.entries.map {
            CuratedEntry.from($0, issueNumber: issue.issueNumber, date: issue.pubDate)
        }
        mergeEntries(newEntries)
        parsedIssueNumbers.insert(issue.issueNumber)
        nextRSSPage += 1
        canLoadMore = nextRSSPage < rssItems.count
    }

    // MARK: - JSON feeds

    private func refreshJSONFeeds(settings: UserSettings, force: Bool) async {
        var jobs: [(url: URL, feedID: String)] = []

        if settings.enabledBuiltInCuratedSources.contains(BuiltInCuratedSource.personal.rawValue) {
            jobs.append((BuiltInCuratedSource.personal.url, BuiltInCuratedSource.personal.rawValue))
        }
        for feed in settings.customCuratedFeeds where feed.isEnabled {
            if let url = URL(string: feed.urlString) {
                jobs.append((url, feed.id.uuidString))
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                group.addTask { await self.fetchJSONFeed(url: job.url, feedID: job.feedID, force: force) }
            }
        }
    }

    private func fetchJSONFeed(url: URL, feedID: String, force: Bool) async {
        let cached = loadJSONFeedCache(feedID: feedID)

        // Show cached entries immediately — don't wait for network.
        if let cached { mergeEntries(cached.entries) }

        // Check staleness (15 min window).
        let age = cached.map { Date.now.timeIntervalSince($0.fetchedAt) } ?? .infinity
        guard force || age > 15 * 60 else { return }

        var request = URLRequest(url: url)
        if let etag = cached?.etag         { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lm   = cached?.lastModified { request.setValue(lm,   forHTTPHeaderField: "If-Modified-Since") }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 304 {
                // Server confirmed no changes — bump timestamp and bail.
                if var c = cached { c.fetchedAt = .now; saveJSONFeedCache(c, feedID: feedID) }
                return
            }

            let feed = try JSONDecoder().decode(CuratedJSONFeed.self, from: data)
            let freshEntries = feed.items.compactMap { CuratedEntry.from($0, feedID: feedID) }

            // Diff: only new URLs are genuinely new. But we merge all anyway — mergeEntries
            // is idempotent for existing entries, so no harm in re-merging unchanged ones.
            mergeEntries(freshEntries)

            saveJSONFeedCache(JSONFeedCacheEntry(
                feedID: feedID,
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified"),
                fetchedAt: .now,
                entries: freshEntries
            ), feedID: feedID)

        } catch {
            // Network/parse failure: silently keep the cached data we already merged.
        }
    }

    // MARK: - Deduplication & sorting

    private func mergeEntries(_ new: [CuratedEntry]) {
        var changed = false
        for entry in new {
            if entriesByID[entry.id] != nil {
                entriesByID[entry.id]!.merge(with: entry)
                // Source merge doesn't change sort order, so we don't set changed = true.
            } else {
                entriesByID[entry.id] = entry
                changed = true
            }
        }
        guard changed else { return }

        // Newest date first; ties broken by votes (newsletter entries have them, JSON ones don't).
        entries = entriesByID.values.sorted {
            $0.date != $1.date ? $0.date > $1.date : ($0.votes ?? 0) > ($1.votes ?? 0)
        }
        persistEntriesCache()
    }

    // MARK: - Newsletter staleness

    private let newsletterCheckedKey = "LN_CuratedNewsletterChecked"

    private func newsletterIsStale() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: newsletterCheckedKey) as? Date else { return true }
        return Date.now.timeIntervalSince(last) > 6 * 3600
    }

    private func markNewsletterChecked() {
        UserDefaults.standard.set(Date.now, forKey: newsletterCheckedKey)
    }

    // MARK: - Disk restore

    private func restoreFromDisk(settings: UserSettings) {
        // Restore merged entries — filter to only those from currently enabled sources.
        if let data = try? Data(contentsOf: entriesCacheURL),
           let cached = try? JSONDecoder().decode([CuratedEntry].self, from: data) {
            let filtered = cached.filter { entryHasEnabledSource($0, settings: settings) }
            for entry in filtered { entriesByID[entry.id] = entry }
            entries = filtered
        }

        // Restore raw RSS items for pagination.
        if let data = try? Data(contentsOf: rssItemsCacheURL),
           let items = try? JSONDecoder().decode([HNLRSSParser.RSSItem].self, from: data) {
            rssItems = items
            // Infer which issues are already parsed from the restored entry sources.
            parsedIssueNumbers = Set(
                entriesByID.values
                    .flatMap(\.sources)
                    .compactMap { if case .newsletter(let n, _) = $0 { n } else { nil } }
            )
            // Next page = how many issues are already shown.
            nextRSSPage = min(parsedIssueNumbers.count, items.count)
            canLoadMore = nextRSSPage < items.count
        }
    }

    private func entryHasEnabledSource(_ entry: CuratedEntry, settings: UserSettings) -> Bool {
        entry.sources.contains { source in
            switch source {
            case .newsletter:
                return settings.enabledBuiltInCuratedSources.contains(BuiltInCuratedSource.hackerNewsletter.rawValue)
            case .json(let feedID):
                if BuiltInCuratedSource.allCases.map(\.rawValue).contains(feedID) {
                    return settings.enabledBuiltInCuratedSources.contains(feedID)
                }
                return settings.customCuratedFeeds.first { $0.id.uuidString == feedID }?.isEnabled == true
            }
        }
    }

    // MARK: - Cache I/O

    private let cacheRoot: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LN_Curated", isDirectory: true)
    }()

    private func setupCacheDirectories() {
        for dir in [cacheRoot, cacheRoot.appendingPathComponent("json_feeds")] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // --- Merged entries ---

    private var entriesCacheURL: URL { cacheRoot.appendingPathComponent("entries.json") }

    private func persistEntriesCache() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: entriesCacheURL)
    }

    // --- Raw RSS items ---

    private var rssItemsCacheURL: URL { cacheRoot.appendingPathComponent("rss_items.json") }

    private func saveRSSItemsCache(_ items: [HNLRSSParser.RSSItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: rssItemsCacheURL)
    }

    // --- Per-feed JSON cache ---

    private func jsonFeedCacheURL(feedID: String) -> URL {
        // Make the feedID safe for use as a filename.
        let safe = feedID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return cacheRoot.appendingPathComponent("json_feeds/\(safe).json")
    }

    private func loadJSONFeedCache(feedID: String) -> JSONFeedCacheEntry? {
        guard let data = try? Data(contentsOf: jsonFeedCacheURL(feedID: feedID)) else { return nil }
        return try? JSONDecoder().decode(JSONFeedCacheEntry.self, from: data)
    }

    private func saveJSONFeedCache(_ cache: JSONFeedCacheEntry, feedID: String) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: jsonFeedCacheURL(feedID: feedID))
    }
}
