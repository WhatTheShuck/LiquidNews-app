// HackerNewsletterService.swift
// Fetches and parses the Hacker Newsletter RSS feed.
//
// Pipeline:
//   1. Fetch RSS XML  →  HNLRSSParser  →  raw [RSSItem]
//   2. For each RSSItem: pass its HTML description  →  NewsletterHTMLParser  →  [NewsletterEntry]
//   3. Wrap into NewsletterIssue, filtering out classifieds automatically.

import Foundation

// MARK: - Errors

enum NewsletterError: LocalizedError {
    case noIssues
    case networkFailure(Error)

    var errorDescription: String? {
        switch self {
        case .noIssues:               return "No newsletter issues found in the feed."
        case .networkFailure(let e):  return e.localizedDescription
        }
    }
}

// MARK: - Service

final class HackerNewsletterService: @unchecked Sendable {

    static let shared = HackerNewsletterService()
    private init() {}

    private let feedURL = URL(string: "https://buttondown.com/hacker-newsletter/rss")!

    // MARK: - Split API (used by CuratedStore)

    /// Downloads and XML-parses the RSS feed, returning raw items (most recent first).
    /// This is the network-heavy step. Parsing the HTML inside each item is separate.
    func fetchRSSItems() async throws -> [HNLRSSParser.RSSItem] {
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: feedURL)
        } catch {
            throw NewsletterError.networkFailure(error)
        }
        let items = HNLRSSParser().parse(data: data)
        guard !items.isEmpty else { throw NewsletterError.noIssues }
        return items
    }

    /// HTML-parses a single raw RSS item into a structured NewsletterIssue.
    /// This is the CPU-heavy step — kept separate so CuratedStore can do it lazily.
    func parseIssue(from item: HNLRSSParser.RSSItem) -> NewsletterIssue {
        let issueNumber = extractIssueNumber(from: item.title)
        let pubDate = parseRFC822(item.pubDate) ?? .now
        let entries = NewsletterHTMLParser.extractEntries(from: item.description)
        return NewsletterIssue(
            id: item.guid.isEmpty ? item.link : item.guid,
            issueNumber: issueNumber,
            title: item.title,
            pubDate: pubDate,
            entries: entries
        )
    }

    // MARK: - Convenience

    /// Fetches and fully parses all issues in the RSS feed. Useful for one-shot use.
    func fetchIssues() async throws -> [NewsletterIssue] {
        let items = try await fetchRSSItems()
        return items.map { parseIssue(from: $0) }
    }

    // MARK: - Private helpers

    /// Pulls the number from titles like "Hacker Newsletter #787".
    func extractIssueNumber(from title: String) -> Int {
        guard let match = title.firstMatch(of: /#(\d+)/) else { return 0 }
        return Int(match.1) ?? 0
    }

    /// Parses RFC 822 date strings used in RSS feeds.
    private func parseRFC822(_ string: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f.date(from: string)
    }
}

// MARK: - RSS XML Parser
//
// Foundation's XMLParser is SAX-style: it calls delegate methods as it walks
// through the document. We accumulate text in `currentText` and assign it to
// the right field when the element closes.

final class HNLRSSParser: NSObject, XMLParserDelegate {

    /// A single parsed RSS item. Codable so CuratedStore can persist it to disk
    /// and do lazy per-page HTML parsing across app sessions without re-fetching.
    struct RSSItem: Codable {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var pubDate: String = ""
        var guid: String = ""
    }

    private var items: [RSSItem] = []
    private var current: RSSItem?
    private var currentElement = ""
    private var currentText = ""

    func parse(data: Data) -> [RSSItem] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = name
        currentText = ""
        if name == "item" { current = RSSItem() }
    }

    // Plain text inside an element (XML entities already decoded by XMLParser).
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    // CDATA blocks are passed raw — this is how Buttondown delivers the HTML body.
    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        currentText += String(data: block, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard var item = current else { return }
        switch name {
        case "title":       item.title       = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "link":        item.link        = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "description": item.description = currentText          // keep raw HTML
        case "pubDate":     item.pubDate     = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "guid":        item.guid        = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "item":        items.append(item); current = nil; return
        default:            break
        }
        current = item
        currentText = ""
    }
}

// MARK: - HTML Content Parser
//
// Each article in the newsletter lives inside a <p> block that looks like:
//
//   <p style="...">
//     <a href="ARTICLE_URL?utm_source=hackernewsletter&amp;utm_term=SECTION"
//        style="..."
//        title="Votes: 816 Comments: 175">Article Title</a>
//     <br/>
//     <span style="...">
//       <span>//</span>source.domain
//       <a href="https://news.ycombinator.com/item?id=47522173&amp;utm_term=comment">comments→</a>
//     </span>
//   </p>
//
// Classifieds/sponsored entries have a visible "sponsored" badge and
// utm_term=classifieds in their URL — we drop both.

enum NewsletterHTMLParser {

    // The article link always contains utm_source=hackernewsletter and a
    // title attribute with "Votes: X Comments: Y" — this combination uniquely
    // identifies curated entries vs. headers, footers, and sponsor links.
    private static let articleRegex = /href="([^"]*utm_source=hackernewsletter[^"]*)"[^>]*title="Votes:\s*(\d+)\s*Comments:\s*(\d+)"[^>]*>([^<]+)<\/a>/

    // HN comments link: news.ycombinator.com/item?id=XXXXX
    private static let hnItemRegex  = /href="https?:\/\/news\.ycombinator\.com\/item\?id=(\d+)/

    // Source domain line: <span>//</span>domain.com
    private static let domainRegex  = /\/\/>([^<\s]+)/

    static func extractEntries(from html: String) -> [NewsletterEntry] {
        // Split on <p to get one paragraph per potential article.
        // This avoids loading a full HTML parser for what is a predictably
        // structured email template.
        return html
            .components(separatedBy: "<p")
            .compactMap { parseEntry(from: $0) }
    }

    private static func parseEntry(from paragraph: String) -> NewsletterEntry? {
        // Hard filter: drop anything with "sponsored" text (classifieds badge).
        guard !paragraph.localizedCaseInsensitiveContains("sponsored") else { return nil }

        // Must have an article link with vote metadata.
        guard let linkMatch = paragraph.firstMatch(of: articleRegex) else { return nil }

        let rawHref      = String(linkMatch.1)
        let votes        = Int(linkMatch.2)
        let commentCount = Int(linkMatch.3)
        let title        = decodeHTMLEntities(String(linkMatch.4))

        // Determine section from utm_term; drop classifieds.
        let section = utmTerm(from: rawHref).map(NewsletterSection.from) ?? .unknown
        guard !section.isFiltered else { return nil }

        // Clean the article URL by stripping all utm_* query params.
        let decodedHref = rawHref.replacingOccurrences(of: "&amp;", with: "&")
        guard let articleURL = strippingUTMParams(from: decodedHref) else { return nil }

        // HN item ID from the comments anchor (may not exist for all sections).
        let hnItemID: Int? = paragraph.firstMatch(of: hnItemRegex).flatMap { Int($0.1) }

        // Source domain: try the inline // span first, fall back to the article URL.
        let sourceDomain: String? = paragraph.firstMatch(of: domainRegex).map {
            String($0.1).trimmingCharacters(in: .whitespaces)
        } ?? URLComponents(url: articleURL, resolvingAgainstBaseURL: false)?.host?
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

        return NewsletterEntry(
            title: title,
            articleURL: articleURL,
            hnItemID: hnItemID,
            section: section,
            votes: votes,
            commentCount: commentCount,
            sourceDomain: sourceDomain
        )
    }

    // MARK: - URL utilities

    /// Extracts the utm_term query parameter value from a URL string.
    private static func utmTerm(from urlString: String) -> String? {
        let decoded = urlString.replacingOccurrences(of: "&amp;", with: "&")
        guard let components = URLComponents(string: decoded) else { return nil }
        return components.queryItems?.first(where: { $0.name == "utm_term" })?.value
    }

    /// Returns the URL with all utm_* query parameters removed.
    private static func strippingUTMParams(from urlString: String) -> URL? {
        guard var components = URLComponents(string: urlString) else { return nil }
        let filtered = components.queryItems?.filter { !$0.name.hasPrefix("utm_") }
        components.queryItems = (filtered?.isEmpty == true) ? nil : filtered
        return components.url
    }

    // MARK: - HTML entity decoding (titles only — URLs are handled separately)

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
