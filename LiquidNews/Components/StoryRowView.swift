// StoryRowView.swift
// A single row in the stories feed — rank badge, title, domain chip, metadata.

import SwiftUI

struct StoryRowView: View {
    let story: HNItem
    let rank: Int

    @ScaledMetric(relativeTo: .body)     private var titleSize:  CGFloat = 15
    @ScaledMetric(relativeTo: .caption2) private var domainSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var metaSize:   CGFloat = 11

    private let store = SavedPostsStore.shared
    private let settings = UserSettings.shared

    private var shouldDim: Bool {
        settings.readBehaviour == .dim && store.isRead(story.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Top row: title ──────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {


                VStack(alignment: .leading, spacing: 6) {

                    // Domain badge — only shown for link posts
                    if let domain = story.displayURL {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: domainSize * 0.91, weight: .semibold))
                            Text(domain)
                                .font(.system(size: domainSize, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentMuted, in: Capsule())
                    }

                    // Story title — optionally dimmed once the user has opened it
                    Text(story.title ?? "Untitled")
                        .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(shouldDim ? 0.4 : 1.0))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ── Bottom row: score / comments / author / time ───────────────
            HStack(spacing: 14) {
           

                MetaBadge(icon: "arrow.up", value: "\(story.score ?? 0)")

                if let count = story.descendants {
                    MetaBadge(icon: "bubble.left", value: "\(count)")
                }

                if let by = story.by {
                    MetaBadge(icon: "person", value: by)
                }

                Spacer()

                Text(story.timeAgo)
                    .font(.system(size: metaSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let title = story.title { parts.append(title) }
        if let by = story.by { parts.append("by \(by)") }
        if let score = story.score { parts.append("\(score) points") }
        if let count = story.descendants { parts.append("\(count) comments") }
        return parts.joined(separator: ", ")
    }
}

// Small icon + text pair used in the metadata row
struct MetaBadge: View {
    let icon: String
    let value: String

    @ScaledMetric(relativeTo: .caption2) private var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: size * 0.91, weight: .semibold))
            Text(value)
                .font(.system(size: size, weight: .medium, design: .rounded))
        }
        .foregroundStyle(AppTheme.secondaryText)
    }
}

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        StoryRowView(
            story: HNItem(
                id: 1,
                type: .story,
                by: "pg",
                time: Date().timeIntervalSince1970 - 3600,
                title: "My YC application: Dropbox — throw away your USB drive",
                url: "https://dropbox.com",
                score: 342,
                descendants: 87,
                text: nil,
                kids: nil,
                deleted: nil,
                dead: nil
            ),
            rank: 1
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
