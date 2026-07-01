// HNAPIService.swift
// HackerNews Firebase REST API wrapper with in-memory caching.
//
// Cache strategy:
//   • Items (stories/comments): cached permanently for the session —
//     HN items are immutable once posted.
//   • Story ID lists: cached for 5 minutes so switching categories
//     feels instant but stays reasonably fresh.

import Foundation

actor HNAPIService {

    nonisolated static let shared = HNAPIService()

    private let baseURL = "https://hacker-news.firebaseio.com/v0"
    private let decoder = JSONDecoder()

    private var maxConcurrentFetches: Int {
        let s = UserSettings.shared
        return NetworkMonitor.shared.currentlyOnWifi() ? s.maxConcurrentFetchesWifi : s.maxConcurrentFetchesCellular
    }

    // MARK: - Caches

    // Items don't change, so we keep them forever in the session.
    private var itemCache: [Int: HNItem] = [:]

    // ID lists do change (new stories get posted), so we expire them.
    private struct CachedList {
        let ids: [Int]
        let fetchedAt: Date
    }
    private var listCache: [String: CachedList] = [:]
    private let listCacheTTL: TimeInterval = 5 * 60  // 5 minutes

    nonisolated private init() {}

    // MARK: - Story ID lists

    func topStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "topstories") }
    func newStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "newstories") }
    func bestStoryIDs() async throws -> [Int] { try await fetchIDs(path: "beststories") }
    func askStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "askstories") }
    func showStoryIDs() async throws -> [Int] { try await fetchIDs(path: "showstories") }
    func jobStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "jobstories") }

    /// Resolves the story-ID list for a feed category. Centralizes the category
    /// → endpoint mapping so callers (view models, cache, offline download) share one path.
    func storyIDs(for category: StoryCategory) async throws -> [Int] {
        switch category {
        case .top:      return try await topStoryIDs()
        case .new:      return try await newStoryIDs()
        case .best:     return try await bestStoryIDs()
        case .ask:      return try await askStoryIDs()
        case .show:     return try await showStoryIDs()
        case .jobs:     return try await jobStoryIDs()
        case .classic:  return try await webStoryIDs(endpoint: "classic")
        case .active:   return try await webStoryIDs(endpoint: "active")
        case .shownew:  return try await webStoryIDs(endpoint: "shownew")
        case .asknew:   return try await webStoryIDs(endpoint: "asknew")
        case .noob:     return try await webStoryIDs(endpoint: "noobstories")
        case .launches: return try await webStoryIDs(endpoint: "launches")
        case .pool:     return try await webStoryIDs(endpoint: "pool")
        }
    }

    /// Fetches story IDs by scraping a public HN web endpoint (e.g. /classic, /active).
    /// HN's HTML contains story rows as <tr class='athing' id='ITEM_ID'> — we extract
    /// those IDs and hydrate them from the Firebase API as normal.
    func webStoryIDs(endpoint: String) async throws -> [Int] {
        let cacheKey = "web_\(endpoint)"
        if let cached = listCache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < listCacheTTL {
            return cached.ids
        }
        let url = URL(string: "https://news.ycombinator.com/\(endpoint)")!
        var request = URLRequest(url: url)
        request.setValue("LiquidNews/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        let ids = parseHNStoryIDs(from: html)
        listCache[cacheKey] = CachedList(ids: ids, fetchedAt: Date())
        return ids
    }

    /// Parses item IDs from HN's HTML. Each story row looks like:
    ///   <tr class='athing' id='12345678'>
    private func parseHNStoryIDs(from html: String) -> [Int] {
        var ids: [Int] = []
        // Split on <tr so each component represents one table row opener
        for component in html.components(separatedBy: "<tr ") {
            guard component.contains("athing") else { continue }
            // Extract id='NUMBER' or id="NUMBER"
            for prefix in ["id='", "id=\""] {
                if let start = component.range(of: prefix) {
                    let digits = component[start.upperBound...].prefix(while: \.isNumber)
                    if !digits.isEmpty, let id = Int(String(digits)) {
                        ids.append(id)
                        break
                    }
                }
            }
        }
        if ids.isEmpty {
            HNScrapeLog.parseReturnedEmpty("parseHNStoryIDs")
        }
        return ids
    }

    // MARK: - Items

    /// Removes a single item from the cache so the next fetch gets fresh data.
    func evict(id: Int) { itemCache.removeValue(forKey: id) }

    /// Fetch a single item. Reads the in-memory L1 first, then the network. On a network
    /// failure (offline, after a relaunch wiped L1, or a transient error) it falls back to
    /// the persistent L2 (`HNCache`) so cached content survives app kills and offline — the
    /// cache-first contract the offline feature depends on.
    func item(id: Int) async throws -> HNItem {
        if let cached = itemCache[id] { return cached }

        do {
            let url = URL(string: "\(baseURL)/item/\(id).json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let item = try decoder.decode(HNItem.self, from: data)
            itemCache[id] = item
            return item
        } catch {
            if let persisted = await HNCache.shared.cachedItem(id: id) { return persisted }
            throw error
        }
    }

    /// Fetch multiple items concurrently (max 6 in-flight), preserving original order.
    ///
    /// Per-item failures are tolerated: each `item(id:)` already falls back to the
    /// persistent cache, and any id that resolves to neither network nor cache is simply
    /// omitted rather than aborting the whole batch. This means a partly-cached offline
    /// batch (e.g. a Favourites list where only some stories were cached) returns what it
    /// can instead of failing wholesale. If *nothing* resolves and there was at least one
    /// error, the representative error is thrown so genuine online failures still surface.
    func items(ids: [Int]) async throws -> [HNItem] {
        guard !ids.isEmpty else { return [] }
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })

        let (results, firstError): ([HNItem], Error?) = await withTaskGroup(of: Result<HNItem, Error>.self) { group in
            // Bound concurrency using the user's WiFi/cellular setting.
            let limit = self.maxConcurrentFetches
            var inFlight = 0
            var pending = ids.makeIterator()

            func addNext() {
                while inFlight < limit, let id = pending.next() {
                    inFlight += 1
                    group.addTask {
                        do { return .success(try await self.item(id: id)) }
                        catch { return .failure(error) }
                    }
                }
            }

            addNext()

            var collected: [HNItem] = []
            var error: Error?
            for await outcome in group {
                switch outcome {
                case .success(let item): collected.append(item)
                case .failure(let e):    if error == nil { error = e }
                }
                inFlight -= 1
                addNext()
            }
            return (collected, error)
        }

        if results.isEmpty, let firstError { throw firstError }

        return results
            .filter { $0.deleted != true && $0.dead != true }
            .sorted { positions[$0.id, default: 0] < positions[$1.id, default: 0] }
    }

    // MARK: - Algolia Search

    private struct AlgoliaResponse: Decodable {
        let hits: [AlgoliaHit]
        let nbPages: Int?
        let page: Int?
    }

    private struct AlgoliaHit: Decodable {
        let objectID: String
        let title: String?
        let url: String?
        let author: String?
        let points: Int?
        let num_comments: Int?
        let created_at_i: TimeInterval?
    }

    func searchStories(query: String, since: Date) async throws -> [HNItem] {
        var components = URLComponents(string: "https://hn.algolia.com/api/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "numericFilters", value: "created_at_i>\(Int(since.timeIntervalSince1970))"),
            URLQueryItem(name: "hitsPerPage", value: "50"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try decoder.decode(AlgoliaResponse.self, from: data)
        return response.hits.compactMap { hit in
            guard let id = Int(hit.objectID) else { return nil }
            return HNItem(
                id: id, type: .story, by: hit.author, time: hit.created_at_i,
                title: hit.title, url: hit.url, score: hit.points,
                descendants: hit.num_comments, text: nil, kids: nil,
                deleted: nil, dead: nil
            )
        }
    }

    /// Fetches HN stories within a specific date range, sorted by points or by date.
    /// Returns the mapped story items and the total number of available pages.
    func topStoriesInRange(
        from: Date,
        to: Date,
        sortByDate: Bool,
        page: Int
    ) async throws -> (stories: [HNItem], totalPages: Int) {
        let endpoint = sortByDate
            ? "https://hn.algolia.com/api/v1/search_by_date"
            : "https://hn.algolia.com/api/v1/search"
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "numericFilters",
                         value: "created_at_i>\(Int(from.timeIntervalSince1970)),created_at_i<\(Int(to.timeIntervalSince1970))"),
            URLQueryItem(name: "hitsPerPage", value: "20"),
            URLQueryItem(name: "page", value: "\(page)"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try decoder.decode(AlgoliaResponse.self, from: data)
        let stories = response.hits.compactMap { hit -> HNItem? in
            guard let id = Int(hit.objectID) else { return nil }
            return HNItem(
                id: id, type: .story, by: hit.author, time: hit.created_at_i,
                title: hit.title, url: hit.url, score: hit.points,
                descendants: hit.num_comments, text: nil, kids: nil,
                deleted: nil, dead: nil
            )
        }
        return (stories, response.nbPages ?? 0)
    }

    /// Finds other HN discussions of the same URL via Algolia's URL-restricted search.
    /// Only valid for link posts — returns [] immediately for text posts (Ask HN, etc.).
    ///
    /// Query is ranked by relevance (points × recency) so the most-engaged historical
    /// discussion surfaces first. UTM/tracking params are stripped before querying so
    /// `?utm_source=twitter` variants don't cause misses.
    func relatedStories(for story: HNItem) async throws -> [HNItem] {
        guard let rawURL = story.url else { return [] }

        // Strip UTM / tracking params so mirror-submitted URLs still match.
        let searchURL: String = {
            guard var c = URLComponents(string: rawURL) else { return rawURL }
            c.queryItems = c.queryItems?
                .filter { !$0.name.hasPrefix("utm_") && $0.name != "ref" }
            if c.queryItems?.isEmpty == true { c.queryItems = nil }
            while c.path.hasSuffix("/"), c.path.count > 1 { c.path = String(c.path.dropLast()) }
            return c.url?.absoluteString ?? rawURL
        }()

        var components = URLComponents(string: "https://hn.algolia.com/api/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "query",                        value: searchURL),
            URLQueryItem(name: "tags",                         value: "(story,poll)"),
            URLQueryItem(name: "restrictSearchableAttributes", value: "url"),
            URLQueryItem(name: "filters",                      value: "NOT objectID:\(story.id)"),
            URLQueryItem(name: "numericFilters",               value: "num_comments>0"),
            URLQueryItem(name: "hitsPerPage",                  value: "5"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try decoder.decode(AlgoliaResponse.self, from: data)
        return response.hits.compactMap { hit in
            guard let id = Int(hit.objectID) else { return nil }
            return HNItem(
                id: id, type: .story, by: hit.author, time: hit.created_at_i,
                title: hit.title, url: hit.url, score: hit.points,
                descendants: hit.num_comments, text: nil, kids: nil,
                deleted: nil, dead: nil
            )
        }
    }

    // MARK: - Comment navigation

    /// Walks the parent chain from `id` until reaching a non-comment item (story, job, poll).
    /// Uses the item cache, so repeat calls within a session are free.
    func rootStory(forItemID id: Int) async throws -> HNItem {
        let start = try await item(id: id)
        return try await HNAPIService.walkToRoot(from: start) { [weak self] parentID in
            guard let self else { throw RootStoryError.noParent }
            return try await self.item(id: parentID)
        }
    }

    /// Walks the parent chain using an injected fetcher. Exposed as static for unit testing.
    static func walkToRoot(
        from item: HNItem,
        fetch: (Int) async throws -> HNItem
    ) async throws -> HNItem {
        var current = item
        while current.type == .comment {
            guard let parentID = current.parent else {
                throw RootStoryError.noParent
            }
            current = try await fetch(parentID)
        }
        return current
    }

    // MARK: - Private

    private func fetchIDs(path: String) async throws -> [Int] {
        // Return cached list if it's still fresh
        if let cached = listCache[path],
           Date().timeIntervalSince(cached.fetchedAt) < listCacheTTL {
            return cached.ids
        }

        let url = URL(string: "\(baseURL)/\(path).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let ids = try decoder.decode([Int].self, from: data)
        listCache[path] = CachedList(ids: ids, fetchedAt: Date())
        return ids
    }
}

// MARK: - Root story error

enum RootStoryError: Error {
    case noParent
}
