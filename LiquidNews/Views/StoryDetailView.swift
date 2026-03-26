// StoryDetailView.swift
// Story detail presented as a modal sheet.
//
// Layout decisions (Apple HIG, iOS 26 Liquid Glass):
//
//   Dismiss: X button in top-leading, rendered as a glass circle (no opaque
//   fill). Apple HIG: "For non-editable modal presentations, use a close
//   button in the leading position."
//
//   Actions: Overflow menu (ellipsis.circle) in top-trailing. This keeps the
//   reading area completely clear — the primary purpose of this view is to
//   read the comments, so actions should be discoverable but unobtrusive.
//   Apple HIG recommends toolbar menus for secondary actions in detail views.
//
//   Grabber pill: Set via .presentationDragIndicator on the sheet in
//   StoriesListView (not here — it's a sheet-level modifier).

import SwiftUI

// MARK: - Sheet routing

enum DetailSheet: Identifiable {
    case webReader(URL)
    case share(URL)

    var id: String {
        switch self {
        case .webReader(let url): return "reader-\(url.absoluteString)"
        case .share(let url):     return "share-\(url.absoluteString)"
        }
    }
}

// MARK: - View

struct StoryDetailView: View {
    let story: HNItem

    @State private var viewModel: StoryDetailViewModel
    @State private var activeSheet: DetailSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var saved: SavedPostsStore { .shared }
    private let isLoggedIn = false

    init(story: HNItem) {
        self.story = story
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                storyHeaderCard
                commentsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Gradient applied here rather than in a ZStack that fills the
        // entire view including the toolbar area. An opaque layer behind
        // the toolbar prevents the system from sampling content and
        // rendering Liquid Glass — per WWDC25 guidance to remove
        // backgrounds sitting behind toolbars.
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Hide the nav bar's own background fill so the app gradient is
        // continuous behind the toolbar. iOS 26 then renders each toolbar
        // item group with its own automatic Liquid Glass backing — no manual
        // glassEffect needed here (and adding one would double-layer glass
        // on top of the system material, causing the dark band in image 1).
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // ── Leading: close ──
            // .cancellationAction gets the system "close" glass group treatment.
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
            }

            // ── Trailing: overflow menu ──
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    storyActionsMenu
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .task {
            await viewModel.loadComments()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .webReader(let url):
                NavigationStack { WebReaderView(url: url) }
            case .share(let url):
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Actions menu

    @ViewBuilder
    private var storyActionsMenu: some View {
        // ── Core actions ──
        Section {
            Button {
                saved.toggleFavourite(story.id)
            } label: {
                Label(
                    saved.isFavourite(story.id) ? "Unfavourite" : "Favourite",
                    systemImage: saved.isFavourite(story.id) ? "heart.fill" : "heart"
                )
            }

            // Share sub-menu
            Menu {
                if let urlString = story.url, let url = URL(string: urlString) {
                    Button {
                        activeSheet = .share(url)
                    } label: {
                        Label("Share Article Link", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    activeSheet = .share(hnURL)
                } label: {
                    Label("Share HN Link", systemImage: "square.and.arrow.up")
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")

            }

            if story.url != nil {
                Button { activeSheet = .webReader(URL(string: story.url!)!) } label: {
                    Label("Read Article", systemImage: "doc.text")
                }
            }
        }

        // ── Engagement (auth-gated) ──
        Section {
            Button(action: {}) {
                Label("Upvote", systemImage: "arrow.up")
            }
            .disabled(!isLoggedIn)

            Button(action: {}) {
                Label("Downvote", systemImage: "arrow.down")
            }
            .disabled(!isLoggedIn)

            Button(action: {}) {
                Label("Reply", systemImage: "bubble.left")
            }
            .disabled(!isLoggedIn)
        }

        // ── Organisation ──
        Section {
            Button {
                saved.togglePin(story.id)
            } label: {
                Label(
                    saved.isPinned(story.id) ? "Unpin" : "Pin",
                    systemImage: saved.isPinned(story.id) ? "pin.slash.fill" : "pin.fill"
                )
            }

            Button(role: nil, action: {}) {
                Label("Flag", systemImage: "flag")
            }
            .disabled(!isLoggedIn)
        }

        // ── External ──
        Section {
            Button {
                openURL(hnURL)
            } label: {
                Label("Open in Hacker News", systemImage: "safari")
            }

        }
    }

    // MARK: - Helpers

    private var hnURL: URL {
        URL(string: "https://news.ycombinator.com/item?id=\(story.id)")!
    }

    // MARK: - Story header

    private var storyHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let domain = story.displayURL {
                Label(domain, systemImage: "link")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentMuted, in: Capsule())
            }

            Text(story.title ?? "")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Label("\(story.score ?? 0) points", systemImage: "arrow.up")
                Label("\(story.descendants ?? 0) comments", systemImage: "bubble.left")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let by = story.by {
                    Label(by, systemImage: "person.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(story.timeAgo)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }

            // Read Article CTA
            if let urlString = story.url, let url = URL(string: urlString) {
                Button { activeSheet = .webReader(url) } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Read Article")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            // Self-post body
            if let text = story.text, !text.isEmpty {
                Divider().overlay(AppTheme.glassBorder)
                Text(text.htmlStripped)
                    .font(AppTheme.bodyFont(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Comments section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comments")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 2)

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(.white).padding(.vertical, 32)
                    Spacer()
                }
            } else if viewModel.comments.isEmpty {
                Text("No comments yet.")
                    .font(AppTheme.bodyFont())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassCard()
            } else {
                ForEach(viewModel.comments) { comment in
                    CommentView(comment: comment, depth: 0)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Link story") {
    NavigationStack {
        StoryDetailView(story: PreviewData.stories[0])
    }
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
}

#Preview("Ask HN self-post") {
    NavigationStack {
        StoryDetailView(story: PreviewData.stories[2])
    }
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
}
