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
    case nativeReader(URL)
    case webReader(URL)
    case share(URL)

    var id: String {
        switch self {
        case .nativeReader(let url): return "native-reader-\(url.absoluteString)"
        case .webReader(let url):    return "reader-\(url.absoluteString)"
        case .share(let url):        return "share-\(url.absoluteString)"
        }
    }
}

// MARK: - View

struct StoryDetailView: View {
    let story: HNItem

    @ScaledMetric(relativeTo: .title2)   private var titleSize:         CGFloat = 20
    @ScaledMetric(relativeTo: .headline) private var sectionHeaderSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var buttonSize:     CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var metaSize:          CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var smallSize:         CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var domainBadgeSize:   CGFloat = 12

    @State private var viewModel: StoryDetailViewModel
    @State private var activeSheet: DetailSheet?
    @State private var settings = UserSettings.shared
    @State private var relatedStories: [HNItem] = []
    @State private var isLoadingRelated = false
    @State private var selectedRelatedStory: HNItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Custom scroll indicator (replaces system glass indicator to avoid fade artifact)
    @State private var scrollFraction: CGFloat = 0
    @State private var showScrollIndicator = false
    @State private var scrollHideTask: Task<Void, Never>?

    private var saved: SavedPostsStore { .shared }
    @State private var auth = HNAuthService.shared
    @State private var showReply = false
    @State private var actionError: String?
    @State private var hasUpvoted = false
    @State private var localScore: Int

    init(story: HNItem) {
        self.story = story
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
        _localScore = State(initialValue: story.score ?? 0)
    }

    var body: some View {
        ScrollView(.vertical) {
            // LazyVStack so each CommentView is only created as it scrolls
            // into view — essential for threads with 500+ top-level comments.
            LazyVStack(alignment: .leading, spacing: 10) {
                storyHeaderCard
                    .padding(.top, 6)

                relatedStoriesSection

                commentsHeader

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
                        CommentView(comment: comment, depth: 0, opUsername: story.by)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            let maxOffset = geo.contentSize.height - geo.containerSize.height
            guard maxOffset > 1 else { return 0 }
            return geo.contentOffset.y / maxOffset
        } action: { _, fraction in
            scrollFraction = max(0, min(1, fraction))
            // Show instantly (no animation) so position is already correct when it appears.
            showScrollIndicator = true
            scrollHideTask?.cancel()
            scrollHideTask = Task {
                try? await Task.sleep(for: .seconds(1.2))
                // Only the fade-out is animated.
                withAnimation(.easeOut(duration: 0.3)) { showScrollIndicator = false }
            }
        }
        .overlay(alignment: .trailing) {
            GeometryReader { proxy in
                let trackH = proxy.size.height - 40
                let pillH = max(44, trackH * 0.12)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 3, height: pillH)
                    .offset(y: 20 + scrollFraction * max(0, trackH - pillH))
            }
            .frame(width: 3)
            .padding(.trailing, 4)
            .opacity(showScrollIndicator ? 1 : 0)
        }
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

            // ── Trailing: refresh ──
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        async let comments: () = viewModel.loadComments()
                        async let related: () = loadRelatedStories()
                        _ = await (comments, related)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || isLoadingRelated)
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
            let store = SavedPostsStore.shared
            // Record this story in read history as soon as the detail view opens.
            store.recordRead(story)
            // Auto-hide if set, but never touch something the user explicitly saved or favourited.
            if UserSettings.shared.readBehaviour == .hide,
               !store.isFavourite(story.id),
               !store.isSaved(story.id) {
                store.hide(story)
            }
            // Load comments and related discussions in parallel.
            async let comments: () = viewModel.loadComments()
            async let related: () = loadRelatedStories()
            _ = await (comments, related)
        }
        .onReceive(NotificationCenter.default.publisher(for: .replyPosted)) { _ in
            Task { await viewModel.loadComments(bustCache: true) }
        }
        .sheet(item: $selectedRelatedStory) { relatedStory in
            NavigationStack { StoryDetailView(story: relatedStory) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .nativeReader(let url):
                NavigationStack { ArticleReaderView(url: url) }
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(.glassCornerRadius)
            case .webReader(let url):
                SafariView(url: url)
            case .share(let url):
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showReply) {
            NavigationStack { ComposeReplyView(parentId: story.id) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .alert("Action Failed", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
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

            if let urlString = story.url, let url = URL(string: urlString) {
                Button { openArticle(url) } label: {
                    Label("Read Article", systemImage: "doc.text")
                }
                // One-off override sub-menu — lets the user choose a different
                // mode without changing their default setting.
                Menu {
                    Button { activeSheet = .nativeReader(url) } label: {
                        Label("Open in Reader", systemImage: "textformat")
                    }
                    Button { activeSheet = .webReader(url) } label: {
                        Label("Open in Browser", systemImage: "globe")
                    }
                    Button { openURL(url) } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                } label: {
                    Label("Open Article As…", systemImage: "arrow.up.right.square")
                }
            }
        }

        // ── Engagement (auth-gated) ──
        Section {
            Button {
                Task {
                    if hasUpvoted {
                        try? await HNAuthService.shared.vote(itemId: story.id, how: "un")
                        localScore -= 1
                        hasUpvoted = false
                    } else {
                        try? await HNAuthService.shared.vote(itemId: story.id, how: "up")
                        localScore += 1
                        hasUpvoted = true
                    }
                }
            } label: {
                Label(hasUpvoted ? "Unvote" : "Upvote",
                      systemImage: hasUpvoted ? "arrow.up.circle.fill" : "arrow.up")
            }
            .disabled(!auth.isLoggedIn)

            Button {
                showReply = true
            } label: {
                Label("Reply", systemImage: "bubble.left")
            }
            .disabled(!auth.isLoggedIn)
        }

        // ── Organisation ──
        Section {
            Button {
                saved.toggleSaved(story.id)
            } label: {
                Label(
                    saved.isSaved(story.id) ? "Remove from Saved" : "Save for Later",
                    systemImage: saved.isSaved(story.id) ? "bookmark.fill" : "bookmark"
                )
            }

            Button {
                Task {
                    do { try await HNAuthService.shared.flag(itemId: story.id) }
                    catch { actionError = error.localizedDescription }
                }
            } label: {
                Label("Flag", systemImage: "flag")
            }
            .disabled(!auth.isLoggedIn)
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

    /// Opens an article URL using the user's default link open mode.
    private func openArticle(_ url: URL) {
        switch settings.defaultLinkOpen {
        case .reader:  activeSheet = .nativeReader(url)
        case .browser: activeSheet = .webReader(url)
        case .safari:  openURL(url)
        }
    }

    private var hnURL: URL {
        URL(string: "https://news.ycombinator.com/item?id=\(story.id)")!
    }

    // MARK: - Story header

    private var storyHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let domain = story.displayURL {
                Label(domain, systemImage: "link")
                    .font(.system(size: domainBadgeSize, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentMuted, in: Capsule())
            }

            Text(story.title ?? "")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Label("\(localScore) points", systemImage: hasUpvoted ? "arrow.up.circle.fill" : "arrow.up")
                    .foregroundStyle(hasUpvoted ? AppTheme.accent : .secondary)
                Label("\(story.descendants ?? 0) comments", systemImage: "bubble.left")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: metaSize, weight: .medium))

            HStack(spacing: 8) {
                if let by = story.by {
                    Label(by, systemImage: "person.fill")
                        .font(.system(size: metaSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(story.timeAgo)
                    .font(.system(size: metaSize))
                    .foregroundStyle(.tertiary)
            }

            // Read Article CTA — uses the user's default link open mode.
            // Long-press for a one-off override without changing the setting.
            if let urlString = story.url, let url = URL(string: urlString) {
                Button { openArticle(url) } label: {
                    HStack {
                        Image(systemName: settings.defaultLinkOpen.systemImage)
                        Text("Read Article")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: domainBadgeSize))
                    }
                    .font(.system(size: buttonSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .contextMenu {
                    Button { activeSheet = .nativeReader(url) } label: {
                        Label("Open in Reader", systemImage: "textformat")
                    }
                    Button { activeSheet = .webReader(url) } label: {
                        Label("Open in Browser", systemImage: "globe")
                    }
                    Button { openURL(url) } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
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

    // MARK: - Related stories

    private func loadRelatedStories() async {
        guard story.url != nil else { return }
        isLoadingRelated = true
        do {
            relatedStories = try await HNAPIService.shared.relatedStories(for: story)
        } catch {
            // Supplementary feature — silently fail
        }
        isLoadingRelated = false
    }

    @ViewBuilder
    private var relatedStoriesSection: some View {
        // Only show for link posts and only when there's something to display
        if story.url != nil && (isLoadingRelated || !relatedStories.isEmpty) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Section header ──
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: domainBadgeSize, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(isLoadingRelated ? "Also Discussed on HN" : "Also Discussed on HN (\(relatedStories.count))")
                        .font(.system(size: metaSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    if isLoadingRelated {
                        ProgressView().scaleEffect(0.6).tint(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                if !relatedStories.isEmpty {
                    Divider().overlay(AppTheme.glassBorder)

                    ForEach(Array(relatedStories.enumerated()), id: \.element.id) { index, related in
                        Button {
                            selectedRelatedStory = related
                        } label: {
                            relatedStoryRow(related)
                        }
                        .buttonStyle(.plain)

                        if index < relatedStories.count - 1 {
                            Divider()
                                .overlay(AppTheme.glassBorder)
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
            .padding(.bottom, relatedStories.isEmpty ? 0 : 10)
            .glassCard()
        }
    }

    private func relatedStoryRow(_ related: HNItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(related.title ?? "")
                .font(.system(size: metaSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                MetaBadge(icon: "arrow.up",    value: "\(related.score ?? 0)")
                MetaBadge(icon: "bubble.left", value: "\(related.descendants ?? 0)")
                if let by = related.by {
                    MetaBadge(icon: "person", value: by)
                }
                Spacer()
                Text(related.timeAgo)
                    .font(.system(size: smallSize))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Comments header

    private var commentsHeader: some View {
        Text("Comments")
            .font(.system(size: sectionHeaderSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 2)
            .padding(.top, 4)
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
