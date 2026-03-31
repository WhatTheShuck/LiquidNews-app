// CuratedEntryRowView.swift
// A single row in the Curated feed.
// Layout mirrors StoryRowView: domain chip at top, title, metadata row.
// The extra element is a source/section tag strip at the bottom that shows
// where the story came from (newsletter section or JSON feed name).

import SwiftUI

struct CuratedEntryRowView: View {
    let entry: CuratedEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Domain chip (mirrors StoryRowView) ───────────────────────────
            if let domain = entry.sourceDomain {
                Label(domain, systemImage: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accentMuted, in: Capsule())
            }

            // ── Title ────────────────────────────────────────────────────────
            Text(entry.title)
                .font(AppTheme.titleFont(15))
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // ── Curator note (JSON feeds only) ───────────────────────────────
            if let note = entry.note {
                Text("— \(note)")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            // ── Main metadata row (mirrors StoryRowView) ─────────────────────
            HStack(spacing: 14) {
                if let votes = entry.votes {
                    MetaBadge(icon: "arrow.up", value: "\(votes)")
                }
                if let comments = entry.commentCount {
                    MetaBadge(icon: "bubble.left", value: "\(comments)")
                }
                Spacer()
                Text(entry.date.curatedRelative)
                    .font(AppTheme.captionFont(11))
                    .foregroundStyle(.tertiary)
            }

            // ── Source / section tags ─────────────────────────────────────────
            // One badge per source. Newsletter badges include the section name
            // so the user knows which part of the newsletter it came from.
            // Colour coding is retained for now to distinguish source types.
            if !entry.sources.isEmpty {
                Divider()
                    .overlay(AppTheme.glassBorder)

                HStack(spacing: 6) {
                    ForEach(entry.sources, id: \.self) { source in
                        sourceTag(for: source)
                    }
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
        case .newsletter(_, let sectionRaw):
            let label = newsletterLabel(section: sectionRaw)
            Text(label)
                .tagStyle(color: AppTheme.accent)

        case .json(let feedID):
            Text(feedName(for: feedID))
                .tagStyle(color: .cyan)
        }
    }

    /// Builds the label for a newsletter source badge.
    /// If the section is known and not .unknown, appends it: "Hacker Newsletter · Favorites".
    private func newsletterLabel(section sectionRaw: String) -> String {
        let base = "Hacker Newsletter"
        if let s = NewsletterSection(rawValue: sectionRaw), s != .unknown {
            return "\(base) · \(s.displayName)"
        }
        return base
    }

    private func feedName(for feedID: String) -> String {
        BuiltInCuratedSource(rawValue: feedID)?.name ?? "Custom Feed"
    }
}

// MARK: - Tag style

private extension Text {
    func tagStyle(color: Color) -> some View {
        self
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(color.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
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

                // Newsletter entry
                CuratedEntryRowView(entry: CuratedEntry(
                    id: "1", title: "Personal Encyclopedias",
                    url: URL(string: "https://whoami.wiki/blog/personal-encyclopedias")!,
                    date: Date.now.addingTimeInterval(-5 * 86400),
                    sources: [.newsletter(issueNumber: 787, section: "fav")],
                    votes: 816, commentCount: 175, hnItemID: 47522173,
                    note: nil, sourceDomain: "whoami.wiki"
                ))

                // JSON feed entry with note
                CuratedEntryRowView(entry: CuratedEntry(
                    id: "2", title: "Some Things Just Take Time",
                    url: URL(string: "https://lucumr.pocoo.org/2026/3/20/")!,
                    date: Date.now.addingTimeInterval(-2 * 86400),
                    sources: [.json(feedID: "personal")],
                    votes: nil, commentCount: nil, hnItemID: nil,
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
