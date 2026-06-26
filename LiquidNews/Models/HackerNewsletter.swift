// HackerNewsletter.swift
// Data models for parsed Hacker Newsletter issues.

import Foundation

// MARK: - Issue

nonisolated struct NewsletterIssue: Identifiable {
    let id: String          // RSS guid
    let issueNumber: Int
    let title: String
    let pubDate: Date
    /// All entries, already filtered (classifieds removed).
    let entries: [NewsletterEntry]
}

// MARK: - Entry

nonisolated struct NewsletterEntry: Identifiable, Hashable {
    let id: UUID
    let title: String
    let articleURL: URL
    /// Parsed from the "comments" anchor: news.ycombinator.com/item?id=XXXXX
    let hnItemID: Int?
    let section: NewsletterSection
    let votes: Int?
    let commentCount: Int?
    /// Bare domain shown under the title, e.g. "whoami.wiki"
    let sourceDomain: String?

    init(
        id: UUID = UUID(),
        title: String,
        articleURL: URL,
        hnItemID: Int?,
        section: NewsletterSection,
        votes: Int?,
        commentCount: Int?,
        sourceDomain: String?
    ) {
        self.id           = id
        self.title        = title
        self.articleURL   = articleURL
        self.hnItemID     = hnItemID
        self.section      = section
        self.votes        = votes
        self.commentCount = commentCount
        self.sourceDomain = sourceDomain
    }
}

// MARK: - Section

nonisolated enum NewsletterSection: String, CaseIterable {
    case favorites   = "fav"
    case askHN       = "ask_hn"
    case showHN      = "show_hn"
    case code        = "code"
    case data        = "data"
    case design      = "design"
    case books       = "books"
    case working     = "working"
    case learn       = "learn"
    case watching    = "watching"
    case startups    = "startups"
    case fun         = "fun"
    case classifieds = "classifieds"
    case unknown     = ""

    static func from(utmTerm: String) -> NewsletterSection {
        allCases.first { $0.rawValue == utmTerm } ?? .unknown
    }

    var displayName: String {
        switch self {
        case .favorites:   return "Favorites"
        case .askHN:       return "Ask HN"
        case .showHN:      return "Show HN"
        case .code:        return "Code"
        case .data:        return "Data"
        case .design:      return "Design"
        case .books:       return "Books"
        case .working:     return "Working"
        case .learn:       return "Learn"
        case .watching:    return "Watching"
        case .startups:    return "Startup News"
        case .fun:         return "Fun"
        case .classifieds: return "Classifieds"
        case .unknown:     return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites:   return "star"
        case .askHN:       return "questionmark.bubble"
        case .showHN:      return "eye"
        case .code:        return "chevron.left.forwardslash.chevron.right"
        case .data:        return "chart.bar"
        case .design:      return "paintbrush"
        case .books:       return "book"
        case .working:     return "briefcase"
        case .learn:       return "graduationcap"
        case .watching:    return "play.circle"
        case .startups:    return "building.2"
        case .fun:         return "face.smiling"
        case .classifieds: return "megaphone"
        case .unknown:     return "link"
        }
    }

    /// Sections excluded from display.
    var isFiltered: Bool { self == .classifieds }
}
