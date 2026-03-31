// CuratedSource.swift
// Models for the Curated tab's feed sources.

import Foundation

// MARK: - Built-in sources

enum BuiltInCuratedSource: String, CaseIterable, Identifiable {
    case hackerNewsletter
    case personal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hackerNewsletter: return "Hacker Newsletter"
        case .personal:         return "LiquidNews Picks"
        }
    }

    var systemImage: String {
        switch self {
        case .hackerNewsletter: return "envelope.open"
        case .personal:         return "hand.thumbsup"
        }
    }

    /// The remote URL this source is fetched from.
    var url: URL {
        switch self {
        case .hackerNewsletter:
            return URL(string: "https://buttondown.com/hacker-newsletter/rss")!
        case .personal:
            return URL(string: "https://liquidnews.what-the-shuck.com/curated.json")!
        }
    }
}

// MARK: - Custom (user-added) feed

/// A curated feed URL added manually by the user.
/// The feed must return JSON matching the LiquidNews curated format (see `CuratedFeedFormat`).
struct CustomCuratedFeed: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var urlString: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, urlString: String, isEnabled: Bool = true) {
        self.id       = id
        self.name     = name
        self.urlString = urlString
        self.isEnabled = isEnabled
    }
}

// MARK: - JSON feed wire format

/// The shape of any curated JSON feed (built-in personal feed or user-added custom feeds).
struct CuratedJSONFeed: Codable {
    let version: Int
    let items: [CuratedJSONItem]
}

struct CuratedJSONItem: Codable {
    let url: String
    let title: String
    let date: String    // "YYYY-MM-DD"
    let note: String?
}

// MARK: - JSON feed disk cache entry

/// Persisted per-feed cache. Stores entries + HTTP conditional request headers
/// so we can use If-None-Match / If-Modified-Since to avoid re-downloading unchanged feeds.
struct JSONFeedCacheEntry: Codable {
    var feedID: String
    var etag: String?
    var lastModified: String?
    var fetchedAt: Date
    var entries: [CuratedEntry]
}

// MARK: - JSON format example (for display in settings)

/// Documents the expected shape of a custom curated JSON feed.
/// Shown to the user when they add a custom feed URL.
enum CuratedFeedFormat {
    static let exampleJSON = """
    {
      "version": 1,
      "items": [
        {
          "url": "https://example.com/article",
          "title": "Story title",
          "date": "2026-03-29",
          "note": "Why I curated this (optional)"
        }
      ]
    }
    """

    static let fieldDescriptions: [(field: String, detail: String)] = [
        ("url",   "Required. The article URL."),
        ("title", "Required. The article title."),
        ("date",  "Required. ISO format: YYYY-MM-DD."),
        ("note",  "Optional. A short curator comment."),
    ]
}
