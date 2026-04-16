// CuratedEntryRowView.swift
// A single row in the Curated feed.
// Header: source tag (right-aligned). Below: title, section/note, metadata row.
// Domain sits in the metadata row alongside votes and comments.

import SwiftUI

struct CuratedEntryRowView: View {
    let entry: CuratedEntry

    /// The text shown beneath the title: curator note for JSON entries,
    /// newsletter section name for newsletter entries.
    private var subNote: String? {
        if let note = entry.note { return note }
        for source in entry.sources {
            if case .newsletter(_, let sectionRaw) = source,
               let section = NewsletterSection(rawValue: sectionRaw),
               section != .unknown {
                return section.displayName
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Domain chip ───────────────────────────────────────────────────
            if let domain = entry.sourceDomain {
                Label(domain, systemImage: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accentMuted, in: Capsule())
            }

            // ── Title + section/note ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(AppTheme.titleFont(15))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = subNote {
                    Text("— \(note)")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            // ── Metadata row ──────────────────────────────────────────────────
            HStack(spacing: 14) {
                MetaBadge(icon: "arrow.up", value: "\(entry.votes ?? 0)")
                if let comments = entry.commentCount {
                    MetaBadge(icon: "bubble.left", value: "\(comments)")
                }
                ForEach(entry.sources, id: \.self) { source in
                    sourceTag(for: source)
                }
                Spacer()
                if let d = entry.displayDate {
                    Text(d.curatedRelative)
                        .font(AppTheme.captionFont(11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard()
    }

    // MARK: - Source tag

    @ViewBuilder
    private func sourceTag(for source: CuratedEntrySource) -> some View {
        switch source {
        case .newsletter(let issueNumber, _):
            let label = issueNumber > 0 ? "HN Newsletter #\(issueNumber)" : "HN Newsletter"
            MetaBadge(icon: "newspaper", value: label)

        case .json(let feedID):
            let info = feedInfo(for: feedID)
            MetaBadge(icon: info.icon, value: info.name)
        }
    }

    private func feedInfo(for feedID: String) -> (name: String, icon: String) {
        switch BuiltInCuratedSource(rawValue: feedID) {
        case .personal:         return ("LiquidNews Picks", "hand.thumbsup")
        case .hackerNewsletter: return ("Hacker Newsletter", "newspaper")
        case .none:             return ("Custom Feed", "person.crop.circle")
        }
    }
}

// MARK: - Date helper

extension Date {
    /// "5d ago" for recent; "Mar 15" beyond a month.
    var curatedRelative: String {
        let diff = Date.now.timeIntervalSince(self)
        if diff < 30 * 24 * 3600 {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return f.localizedString(for: self, relativeTo: .now)
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 12) {

                // Newsletter entry — section shown as sub-note
                CuratedEntryRowView(entry: CuratedEntry(
                    id: "1", title: "Personal Encyclopedias",
                    url: URL(string: "https://whoami.wiki/blog/personal-encyclopedias")!,
                    date: Date.now.addingTimeInterval(-5 * 86400),
                    sources: [.newsletter(issueNumber: 787, section: "fav")],
                    votes: 816, commentCount: 175, hnItemID: 47522173,
                    note: nil, sourceDomain: "whoami.wiki"
                ))

                // JSON feed entry with curator note
                CuratedEntryRowView(entry: CuratedEntry(
                    id: "hn:39876543", title: "Some Things Just Take Time",
                    url: URL(string: "https://news.ycombinator.com/item?id=39876543")!,
                    date: Date.now.addingTimeInterval(-2 * 86400),
                    sources: [.json(feedID: "personal")],
                    votes: 612, commentCount: 94, hnItemID: 39876543,
                    note: "Slow progress is still progress. A good reminder.",
                    sourceDomain: "lucumr.pocoo.org"
                ))

                // Deduplicated — both sources
                CuratedEntryRowView(entry: CuratedEntry(
                    id: "3", title: "An Article That Appeared In Both Sources",
                    url: URL(string: "https://example.com/both")!,
                    date: Date.now.addingTimeInterval(-86400),
                    sources: [
                        .newsletter(issueNumber: 787, section: "code"),
                        .json(feedID: "personal")
                    ],
                    votes: 432, commentCount: 88, hnItemID: 12345678,
                    note: nil, sourceDomain: "example.com"
                ))
            }
            .padding(.horizontal, 16)
        }
    }
    .preferredColorScheme(.dark)
}
