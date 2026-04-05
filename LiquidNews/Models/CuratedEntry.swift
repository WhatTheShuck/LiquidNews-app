// CuratedEntry.swift
// The unified display model for all curated content, regardless of source.
//
// Deduplication is done by normalised URL: if the newsletter and a JSON feed
// both link to the same article, they collapse into one CuratedEntry that
// carries both source attributions.

import Foundation

// MARK: - Entry

struct CuratedEntry: Identifiable, Codable, Hashable {
    /// Stable dedup key: the normalised article URL (UTM-stripped, www-stripped,
    /// lowercased, trailing-slash removed, query params sorted).
    let id: String
    let title: String
    let url: URL
    /// Used for chronological sort. Newsletter entries use the issue's pubDate;
    /// JSON feed entries use the `date` field from the JSON.
    let date: Date
    /// Which source(s) this entry has appeared in. Grows when entries are merged.
    var sources: [CuratedEntrySource]
    let votes: Int?
    let commentCount: Int?
    let hnItemID: Int?
    /// Short curator comment (only present on JSON feed entries).
    let note: String?
    /// Bare domain shown under the title, e.g. "whoami.wiki".
    let sourceDomain: String?
    /// The actual article publication date, resolved lazily from the HN API for
    /// newsletter entries. JSON feed entries populate this directly from the feed.
    /// Nil until fetched; CuratedStore fills it in and persists it to disk.
    var articleDate: Date?

    /// The date to show in the UI — the article's own date once resolved.
    /// Uses `articleDate` when available; falls back to nil so the row shows
    /// nothing rather than the misleading newsletter issue pubDate.
    var displayDate: Date? { articleDate }

    /// Absorbs another sighting of the same article: appends any new sources,
    /// and promotes votes/commentCount to whichever value is higher.
    mutating func merge(with other: CuratedEntry) {
        for source in other.sources where !sources.contains(source) {
            sources.append(source)
        }
    }
}

// MARK: - Source attribution

enum CuratedEntrySource: Codable, Hashable, Equatable {
    /// From the Hacker Newsletter RSS feed.
    case newsletter(issueNumber: Int, section: String)
    /// From a curated JSON feed. feedID is either a BuiltInCuratedSource.rawValue
    /// or a CustomCuratedFeed.id.uuidString.
    case json(feedID: String)
}

// MARK: - URL normalisation

extension CuratedEntry {

    /// Returns a canonical string for the URL, used as the dedup key.
    /// Two URLs that resolve to the same article should produce the same key.
    static func normalise(_ url: URL) -> String {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString.lowercased()
        }
        c.scheme = c.scheme?.lowercased()
        c.host   = c.host?.lowercased()
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        // Strip tracking params; sort remaining for stable comparison.
        c.queryItems = c.queryItems?
            .filter { !$0.name.hasPrefix("utm_") && $0.name != "ref" }
            .sorted { $0.name < $1.name }
        if c.queryItems?.isEmpty == true { c.queryItems = nil }
        // Remove trailing slash (but keep "/" for root paths).
        while c.path.hasSuffix("/") && c.path.count > 1 { c.path = String(c.path.dropLast()) }
        return c.url?.absoluteString ?? url.absoluteString.lowercased()
    }

    // MARK: - Factories

    /// Converts a parsed newsletter entry into a CuratedEntry.
    static func from(_ entry: NewsletterEntry, issueNumber: Int, date: Date) -> CuratedEntry {
        CuratedEntry(
            id: normalise(entry.articleURL),
            title: entry.title,
            url: entry.articleURL,
            date: date,
            sources: [.newsletter(issueNumber: issueNumber, section: entry.section.rawValue)],
            votes: entry.votes,
            commentCount: entry.commentCount,
            hnItemID: entry.hnItemID,
            note: nil,
            sourceDomain: entry.sourceDomain,
            articleDate: nil
        )
    }

    /// Converts a JSON feed item into a CuratedEntry. Returns nil if the URL is invalid.
    static func from(_ item: CuratedJSONItem, feedID: String) -> CuratedEntry? {
        guard let url = URL(string: item.url) else { return nil }
        let domain = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        let articleDate = parseISODate(item.date)
        return CuratedEntry(
            id: normalise(url),
            title: item.title,
            url: url,
            date: articleDate ?? .now,
            sources: [.json(feedID: feedID)],
            votes: nil,
            commentCount: nil,
            hnItemID: nil,
            note: item.note,
            sourceDomain: domain,
            articleDate: articleDate
        )
    }

    private static func parseISODate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)
    }
}
