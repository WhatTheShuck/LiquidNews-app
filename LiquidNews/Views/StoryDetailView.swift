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
    case inAppSafari(URL)
    case share(URL)
    case hnStory(HNItem)
    case hnComment(HNItem)

    var id: String {
        switch self {
        case .nativeReader(let url):   return "native-reader-\(url.absoluteString)"
        case .inAppSafari(let url):    return "in-app-safari-\(url.absoluteString)"
        case .share(let url):          return "share-\(url.absoluteString)"
        case .hnStory(let story):      return "hn-story-\(story.id)"
        case .hnComment(let comment):  return "hn-comment-\(comment.id)"
        }
    }
}

// MARK: - View

struct StoryDetailView: View {
    let story: HNItem
    /// Custom close action for non-modal hosts (the iPad detail column, which has
    /// no sheet to dismiss). When nil, the X button falls back to `dismiss()`,
    /// which is correct for sheet and iPhone presentations.
    let onClose: (() -> Void)?
    /// When true (the iPad side-by-side comments pane), the view hosts its own glass
    /// control strip via a top safe-area inset instead of a nav-bar toolbar. This
    /// keeps the controls confined to this pane rather than hoisting into the shared
    /// split-view detail bar alongside the reader's controls.
    let inlineControls: Bool

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
    @Environment(\.iPadNavModel) private var iPadNavModel

    private var saved: SavedPostsStore { .shared }
    @State private var auth = HNAuthService.shared
    @State private var net = NetworkMonitor.shared
    @State private var showReply = false
    @State private var actionError: String?
    @State private var hasUpvoted = false
    @State private var localScore: Int
    @Environment(\.colorScheme) private var colorScheme

    init(story: HNItem, onClose: (() -> Void)? = nil, inlineControls: Bool = false) {
        self.story = story
        self.onClose = onClose
        self.inlineControls = inlineControls
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
        _localScore = State(initialValue: story.score ?? 0)
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 10) {
                storyHeaderCard
                    .padding(.top, 6)

                relatedStoriesSection

                commentsHeader

                if viewModel.isLoading {
                    CommentsSkeletonView()
                } else if viewModel.comments.isEmpty {
                    Text("No comments yet.")
                        .font(AppTheme.bodyFont())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .glassCard()
                } else {
                    ForEach(Array(viewModel.comments.enumerated()), id: \.element.id) { index, comment in
                        CommentView(comment: comment, depth: 0, opUsername: story.by, story: story,
                                    isCoachMarkTarget: index == 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .coachMarks([.readArticleLongPress, .commentTapCollapse, .commentLongPress])
        // Disable scroll clip so glass cards near the top/bottom of the viewport
        // can render their full glow region without being cut off by the clip bounds.
        .scrollClipDisabled()
        // Gradient applied here rather than in a ZStack that fills the
        // entire view including the toolbar area. An opaque layer behind
        // the toolbar prevents the system from sampling content and
        // rendering Liquid Glass — per WWDC25 guidance to remove
        // backgrounds sitting behind toolbars.
        .background(ThemeBackground().ignoresSafeArea())
        .environment(\.openURL, OpenURLAction { url in
            if let id = HNURLRouter.itemID(from: url) {
                Task { @MainActor in
                    if let item = try? await HNAPIService.shared.item(id: id) {
                        activeSheet = item.type == .comment ? .hnComment(item) : .hnStory(item)
                    }
                }
                return .handled
            }
            switch settings.commentLinkOpen {
            case .inAppSafari:
                activeSheet = .inAppSafari(url)
                return .handled
            case .reader:
                activeSheet = .nativeReader(url)
                return .handled
            case .safari:
                return .systemAction
            }
        })
        .navigationBarTitleDisplayMode(.inline)
        // Hide the nav bar's own background fill so the app gradient is
        // continuous behind the toolbar. iOS 26 then renders each toolbar
        // item group with its own automatic Liquid Glass backing — no manual
        // glassEffect needed here (and adding one would double-layer glass
        // on top of the system material, causing the dark band in image 1).
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Suppressed in the side-by-side comments pane, which uses its own glass
            // strip (see `inlineControlBar`) so its controls don't hoist into the
            // shared detail bar next to the reader's.
            if !inlineControls {
                // ── Leading: close ──
                // .cancellationAction gets the system "close" glass group treatment.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        if let onClose { onClose() } else { dismiss() }
                    }
                }

                // ── Trailing: refresh ──
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshContent()
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
        }
        .safeAreaInset(edge: .top) {
            if inlineControls { inlineControlBar }
        }
        .task {
            let store = SavedPostsStore.shared
            // Record this story in read history as soon as the detail view opens.
            store.recordRead(story)
            // Auto-hide if set, but never touch something the user explicitly saved or favourited.
            if UserSettings.shared.readBehaviour == .hide,
               !store.isFavourite(story.id),
               !store.isReadLater(story.id) {
                store.hide(story)
            }
            // Load comments and related discussions in parallel.
            async let comments: () = viewModel.loadComments()
            async let related: () = loadRelatedStories()
            _ = await (comments, related)
        }
        .userActivity(StoryActivity.activityType, isActive: iPadNavModel == nil) { activity in
            StoryActivity.update(activity, with: story)
        }
        .onReceive(NotificationCenter.default.publisher(for: .replyPosted)) { _ in
            Task { await viewModel.loadComments(bustCache: true) }
        }
        .sheet(item: $selectedRelatedStory) { relatedStory in
            NavigationStack { StoryDetailView(story: relatedStory) }
                .glassSheet()
                .iPadPageSheet()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .nativeReader(let url):
                NavigationStack { ArticleReaderView(url: url) }
                    .glassSheet()
                    .iPadPageSheet()
            case .inAppSafari(let url):
                // Clear the binding when Safari's Done button fires. This view is itself
                // a sheet, so leaving `activeSheet` stale after UIKit auto-dismisses lets
                // SwiftUI collapse this whole detail sheet alongside Safari.
                SafariView(url: url, onFinish: { activeSheet = nil })
                    .iPadPageSheet()
            case .share(let url):
                ShareSheet(items: [url])
                    .iPadPageSheet()
            case .hnStory(let story):
                NavigationStack { StoryDetailView(story: story) }
                    .glassSheet()
                    .iPadPageSheet()
            case .hnComment(let comment):
                NavigationStack {
                    ThreadView(
                        rootComment: comment,
                        depth: 0,
                        onShowStory: { fetchedStory in
                            activeSheet = .hnStory(fetchedStory)
                        }
                    )
                }
                .glassSheet()
                .iPadPageSheet()
            }
        }
        .sheet(isPresented: $showReply) {
            NavigationStack { ComposeReplyView(parentId: story.id) }
                .glassSheet()
                .iPadPageSheet()
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

    // MARK: - Inline control strip (iPad side-by-side)

    /// Glass control strip pinned to the top of the comments pane when reading side
    /// by side: close (returns to the list), refresh, and the full actions menu —
    /// the same actions as the nav-bar toolbar, kept inside this pane.
    private var inlineControlBar: some View {
        HStack(spacing: 10) {
            GlassControlButton(systemName: "xmark") {
                if let onClose { onClose() } else { dismiss() }
            }

            Spacer()

            GlassControlButton(
                systemName: "arrow.clockwise",
                enabled: !(viewModel.isLoading || isLoadingRelated)
            ) {
                refreshContent()
            }

            Menu {
                storyActionsMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
            }
            .glassEffect(in: Circle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// Reloads comments and related discussions together. Shared by the nav-bar
    /// refresh button and the inline control strip.
    private func refreshContent() {
        Task {
            async let comments: () = viewModel.loadComments()
            async let related: () = loadRelatedStories()
            _ = await (comments, related)
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
                    Button {
                        if let model = iPadNavModel {
                            withAnimation(.smooth) { model.select(story, mode: .reader) }
                        } else {
                            activeSheet = .nativeReader(url)
                        }
                    } label: {
                        Label("Open in Reader", systemImage: "textformat")
                    }
                    Button {
                        if let model = iPadNavModel {
                            withAnimation(.smooth) { model.select(story, mode: .browser) }
                        } else {
                            activeSheet = .inAppSafari(url)
                        }
                    } label: {
                        Label("Open in In-App Safari", systemImage: "safari")
                    }
                    Button { openURL(url) } label: {
                        Label("Open in Safari", systemImage: "arrow.up.right.square")
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
            .disabled(!auth.isLoggedIn || !net.isOnline)

            Button {
                showReply = true
            } label: {
                Label("Reply", systemImage: "bubble.left")
            }
            .disabled(!auth.isLoggedIn || !net.isOnline)
        }

        // ── Organisation ──
        Section {
            Button {
                saved.toggleReadLater(story.id)
            } label: {
                Label(
                    saved.isReadLater(story.id) ? "Remove from Read Later" : "Read Later",
                    systemImage: saved.isReadLater(story.id) ? "bookmark.fill" : "bookmark"
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
            .disabled(!auth.isLoggedIn || !net.isOnline)
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

    /// Opens an article URL using the user's default link open mode. On iPad
    /// (model present) navigation modes route through the detail column; `.safari`
    /// always opens externally. On iPhone (model absent) the sheet path is used.
    private func openArticle(_ url: URL) {
        if let model = iPadNavModel, let mode = DetailMode.forLinkOpen(settings.defaultLinkOpen) {
            withAnimation(.smooth) { model.select(story, mode: mode) }
            return
        }
        switch settings.defaultLinkOpen {
        case .reader:      activeSheet = .nativeReader(url)
        case .inAppSafari: activeSheet = .inAppSafari(url)
        case .safari:      openURL(url)
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
                .foregroundStyle(.primary)

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
                    .foregroundStyle(.primary)
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
                    Button { activeSheet = .inAppSafari(url) } label: {
                        Label("Open in In-App Safari", systemImage: "safari")
                    }
                    Button { openURL(url) } label: {
                        Label("Open in Safari", systemImage: "arrow.up.right.square")
                    }
                }
                .coachMarkTarget(.readArticleLongPress)
            }

            // Self-post body
            if let text = story.text, !text.isEmpty {
                Divider().overlay(AppTheme.glassBorder)
                storyBody(for: text)
            }
        }
        .padding(18)
        .glassCard()
    }

    @ViewBuilder
    private func storyBody(for text: String) -> some View {
        switch settings.commentRenderingStyle {
        case .textOnly:
            Text(text.htmlStripped)
                .font(AppTheme.bodyFont(14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .textWithLinks:
            Text(text.htmlWithLinks)
                .font(AppTheme.bodyFont(14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .tint(AppTheme.accent)
        case .rich:
            CommentBodyView(html: text)
        }
    }

    // MARK: - Related stories

    private func loadRelatedStories() async {
        guard story.url != nil else { return }
        isLoadingRelated = true
        do {
            let results = try await HNAPIService.shared.relatedStories(for: story)
            withAnimation(.easeInOut(duration: 0.25)) {
                relatedStories = results
                isLoadingRelated = false
            }
        } catch {
            // Supplementary feature — fade out silently
            withAnimation(.easeInOut(duration: 0.25)) {
                isLoadingRelated = false
            }
        }
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
                        .foregroundStyle(.primary.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider().overlay(AppTheme.glassBorder)

                if isLoadingRelated {
                    // Skeleton rows while fetching
                    RelatedRowSkeletonView(twoLineTitle: true)
                    Divider().overlay(AppTheme.glassBorder).padding(.horizontal, 14)
                    RelatedRowSkeletonView()
                    Divider().overlay(AppTheme.glassBorder).padding(.horizontal, 14)
                    RelatedRowSkeletonView(twoLineTitle: true)
                } else {
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
            .padding(.bottom, 10)
            .glassCard()
            .transition(.opacity)
        }
    }

    private func relatedStoryRow(_ related: HNItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(related.title ?? "")
                .font(.system(size: metaSize, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
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
            .foregroundStyle(.primary)
            .padding(.horizontal, 2)
            .padding(.top, 4)
    }
}

// MARK: - Glass control button

/// A circular glass icon button used in the side-by-side comments control strip.
/// Matches the reader pane's floating controls for a consistent split-view feel.
private struct GlassControlButton: View {
    let systemName: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(enabled ? Color.primary : Color.primary.opacity(0.3))
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .glassEffect(in: Circle())
    }
}

// MARK: - Previews

#Preview("Link story") {
    NavigationStack {
        StoryDetailView(story: PreviewData.stories[0])
    }
    .presentationDragIndicator(.visible)
}

#Preview("Ask HN self-post") {
    NavigationStack {
        StoryDetailView(story: PreviewData.stories[2])
    }
    .presentationDragIndicator(.visible)
}
