// HNItem.swift
// The core data model for everything returned by the HackerNews API.
// A single `item` endpoint covers stories, comments, jobs, polls — they
// share the same shape, distinguished by the `type` field.

import Foundation

struct HNItem: Identifiable, Codable, Hashable {

    // MARK: - Properties

    let id: Int

    /// "story", "comment", "job", "poll", or "pollopt"
    let type: ItemType?

    /// Username of the submitter/author
    let by: String?

    /// Unix timestamp of submission
    let time: TimeInterval?

    // Story-specific
    let title: String?
    let url: String?
    let score: Int?
    let descendants: Int?   // total comment count

    // Comment/text body (HTML encoded)
    let text: String?

    /// IDs of child comments (top-level for stories, replies for comments)
    let kids: [Int]?

    let deleted: Bool?
    let dead: Bool?

    /// ID of the parent comment or story (present on comment items)
    let parent: Int?

    // MARK: - Custom init

    init(
        id: Int,
        type: ItemType? = nil,
        by: String? = nil,
        time: TimeInterval? = nil,
        title: String? = nil,
        url: String? = nil,
        score: Int? = nil,
        descendants: Int? = nil,
        text: String? = nil,
        kids: [Int]? = nil,
        deleted: Bool? = nil,
        dead: Bool? = nil,
        parent: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.by = by
        self.time = time
        self.title = title
        self.url = url
        self.score = score
        self.descendants = descendants
        self.text = text
        self.kids = kids
        self.deleted = deleted
        self.dead = dead
        self.parent = parent
    }

    // MARK: - Computed helpers

    /// Human-readable relative time, e.g. "3 hr. ago"
    var timeAgo: String {
        guard let time else { return "" }
        let date = Date(timeIntervalSince1970: time)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Strips "www." and returns just the hostname, e.g. "github.com"
    var displayURL: String? {
        guard let url, let host = URL(string: url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - Nested types

    enum ItemType: String, Codable {
        case story, comment, job, poll, pollopt
    }
}

// MARK: - HN staff

extension HNItem {
    /// Usernames of official HN moderators.
    static let moderators: Set<String> = ["dang", "tomhow"]
}

// MARK: - HTML stripping
// HN returns comment/post text as HTML. This strips tags for plain display.
extension String {
    var htmlStripped: String {
        var result = self
        // Extract the full URL from anchor hrefs before stripping.
        // HN truncates long URLs in anchor display text (e.g. "https://example.com/ver…")
        // but the href always contains the full URL. Replacing the whole anchor with
        // its href preserves the untruncated URL in plain-text mode.
        result = result.replacingOccurrences(
            of: #"<a\s[^>]*href="([^"]*)"[^>]*>[^<]*</a>"#,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )
        // Replace paragraph breaks with newlines
        result = result.replacingOccurrences(of: "<p>", with: "\n\n")
        // Strip remaining tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
