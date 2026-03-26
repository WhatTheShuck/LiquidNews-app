// HNAPIService.swift
// HackerNews Firebase REST API wrapper with in-memory caching.
//
// Cache strategy:
//   • Items (stories/comments): cached permanently for the session —
//     HN items are immutable once posted.
//   • Story ID lists: cached for 5 minutes so switching categories
//     feels instant but stays reasonably fresh.

import Foundation

final class HNAPIService {

    static let shared = HNAPIService()

    private let baseURL = "https://hacker-news.firebaseio.com/v0"
    private let decoder = JSONDecoder()

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

    private init() {}

    // MARK: - Story ID lists

    func topStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "topstories") }
    func newStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "newstories") }
    func bestStoryIDs() async throws -> [Int] { try await fetchIDs(path: "beststories") }
    func askStoryIDs()  async throws -> [Int] { try await fetchIDs(path: "askstories") }
    func showStoryIDs() async throws -> [Int] { try await fetchIDs(path: "showstories") }

    // MARK: - Items

    /// Fetch a single item, returning from cache if available.
    func item(id: Int) async throws -> HNItem {
        if let cached = itemCache[id] { return cached }

        let url = URL(string: "\(baseURL)/item/\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let item = try decoder.decode(HNItem.self, from: data)
        itemCache[id] = item
        return item
    }

    /// Fetch multiple items concurrently, preserving original order.
    func items(ids: [Int]) async throws -> [HNItem] {
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })

        return try await withThrowingTaskGroup(of: HNItem.self) { group in
            for id in ids {
                group.addTask { try await self.item(id: id) }
            }

            var results: [HNItem] = []
            results.reserveCapacity(ids.count)
            for try await item in group {
                results.append(item)
            }

            return results
                .filter { $0.deleted != true && $0.dead != true }
                .sorted { positions[$0.id, default: 0] < positions[$1.id, default: 0] }
        }
    }

    // MARK: - Algolia Search

    private struct AlgoliaResponse: Decodable {
        let hits: [AlgoliaHit]
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
