// CommentView.swift
// Renders a single HN comment with:
//   • Depth-coloured glass tint (thread colour overlaid on the glass)
//   • Auto-expansion of the first N replies (controlled by UserSettings)
//   • Tap the header to collapse/expand
//   • "Continue thread →" at depth threshold → pushes ThreadView
//   • Long-press context menu for comment actions, including per-comment render mode override
//   • Manual "Load N more" for replies beyond the auto-loaded batch

import SwiftUI
import UIKit

struct CommentView: View {
    let comment: HNItem
    let depth: Int
    /// Maximum inline nesting depth. Beyond this, a "Continue thread" button
    /// replaces inline replies and pushes a focused ThreadView.
    /// Defaults to UserSettings value; ThreadView passes .max to disable.
    var maxDepth: Int = UserSettings.shared.maxAutoExpandDepth
    /// Username of the story's original poster. Passed down from StoryDetailView.
    var opUsername: String? = nil

    @State private var isExpanded = true
    @State private var replies: [HNItem] = []
    @State private var isLoadingReplies = false
    @State private var hasAutoLoaded = false
    @State private var showThread: HNItem?

    // MARK: Rendering
    /// Per-comment override. nil means "follow the global setting".
    @State private var localRenderMode: CommentRenderMode?

    private var settings: UserSettings { .shared }

    /// The effective rendering mode for this comment instance.
    private var effectiveMode: CommentRenderMode {
        localRenderMode ?? settings.commentRenderingStyle
    }

    var threadColor: Color {
        AppTheme.threadColor(depth: depth)
    }

    /// How many child IDs exist beyond what we've already loaded
    private var remainingCount: Int {
        max(0, (comment.kids?.count ?? 0) - replies.count)
    }

    /// Whether we've hit the depth threshold for "Continue thread"
    private var atDepthLimit: Bool {
        depth >= maxDepth
    }

    @State private var auth = HNAuthService.shared
    @State private var showReply = false
    @State private var actionError: String?
    @State private var hasUpvoted = false
    @State private var showActions = false

    private var isLoggedIn: Bool { auth.isLoggedIn }
    private var isMod: Bool { HNItem.moderators.contains(comment.by ?? "") }
    private var isOP: Bool { comment.by != nil && comment.by == opUsername }
    private var isCurrentUser: Bool {
        comment.by != nil && comment.by == HNAuthService.shared.username
    }

    var body: some View {
        // ── Comment card ──
        VStack(alignment: .leading, spacing: 8) {

            // ── Own content: header + body ──
            // LongPressHost is overlaid only on this area so it doesn't intercept
            // touches meant for nested child CommentViews below.
            VStack(alignment: .leading, spacing: 8) {

                // Header — tap anywhere on this row to collapse/expand
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center) {
                        Text(comment.by ?? "[deleted]")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(threadColor)

                        if isMod { CommentBadge(label: "mod", color: .green) }
                        if isOP {
                            CommentBadge(label: "OP", color: Color(red: 0.45, green: 0.65, blue: 1.0))
                        }
                        if isCurrentUser { CommentBadge(label: "you", color: AppTheme.accent) }

                        Spacer()

                        Text(comment.timeAgo)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if let text = comment.text, !text.isEmpty {
                        commentBody(for: text)
                            .transition(.opacity)
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.async { showActions = true }
            }

            // ── Replies — no LongPressHost here; each child has its own ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if atDepthLimit {
                        // ── "Continue thread →" at depth limit ──
                        continueThreadButtons
                    } else {
                        // ── Inline replies (recursive) ──
                        if !replies.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(replies) { reply in
                                    CommentView(
                                        comment: reply, depth: depth + 1, maxDepth: maxDepth,
                                        opUsername: opUsername)
                                }
                            }
                            .padding(.top, 4)
                        }

                        // Loading indicator
                        if isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(threadColor)
                                .frame(maxWidth: .infinity)
                        }

                        // "Load more" — centered rounded capsule
                        if remainingCount > 0 && !isLoadingReplies {
                            Button {
                                Task { await loadMoreReplies() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.bubble")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(
                                        "\(remainingCount) more repl\(remainingCount == 1 ? "y" : "ies")"
                                    )
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(threadColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassCard(cornerRadius: 20, tint: threadColor)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18, tint: threadColor)
        .confirmationDialog("", isPresented: $showActions, titleVisibility: .hidden) {
            commentActions
        }
        .task {
            await autoLoadIfNeeded()
        }
        .sheet(item: $showThread) { thread in
            NavigationStack {
                ThreadView(rootComment: thread, depth: depth + 1, opUsername: opUsername)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(isPresented: $showReply) {
            NavigationStack { ComposeReplyView(parentId: comment.id) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Comment body rendering

    @ViewBuilder
    private func commentBody(for text: String) -> some View {
        switch effectiveMode {

        case .textOnly:
            Text(text.htmlStripped)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

        case .textWithLinks:
            Text(text.htmlWithLinks)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .tint(AppTheme.accent)

        case .rich:
            CommentBodyView(html: text, tintColor: threadColor)
        }
    }

    // MARK: - Continue thread buttons

    @ViewBuilder
    private var continueThreadButtons: some View {
        let childCount = comment.kids?.count ?? 0
        if childCount > 0 {
            // Show first child as a preview, then "Continue thread" to drill in
            if let firstReply = replies.first {
                Button {
                    showThread = comment
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(firstReply.by ?? "[deleted]")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.threadColor(depth: depth + 1))
                                if HNItem.moderators.contains(firstReply.by ?? "") {
                                    CommentBadge(label: "mod", color: .green)
                                }
                                if firstReply.by != nil && firstReply.by == opUsername {
                                    CommentBadge(
                                        label: "OP", color: Color(red: 0.45, green: 0.65, blue: 1.0)
                                    )
                                }
                            }

                            if let text = firstReply.text {
                                Text(text.htmlStripped)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .glassCard(cornerRadius: 14, tint: AppTheme.threadColor(depth: depth + 1))
                }
                .buttonStyle(.plain)

                if childCount > 1 {
                    Text("Continue thread (\(childCount) replies) →")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(threadColor.opacity(0.85))
                        .onTapGesture { showThread = comment }
                }
            } else {
                // Replies not loaded yet — simple "Continue thread" button
                Button {
                    showThread = comment
                } label: {
                    HStack(spacing: 6) {
                        Text(
                            "Continue thread (\(childCount) repl\(childCount == 1 ? "y" : "ies")) →"
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(threadColor.opacity(0.85))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Context menu actions

    @ViewBuilder
    private var commentActions: some View {
        if isLoggedIn {
            Button {
                Task {
                    if hasUpvoted {
                        try? await HNAuthService.shared.vote(itemId: comment.id, how: "un")
                        hasUpvoted = false
                    } else {
                        try? await HNAuthService.shared.vote(itemId: comment.id, how: "up")
                        hasUpvoted = true
                    }
                }
            } label: {
                Label(
                    hasUpvoted ? "Unvote" : "Upvote",
                    systemImage: hasUpvoted ? "arrow.up.circle.fill" : "arrow.up")
            }
            Button {
                showReply = true
            } label: {
                Label("Reply", systemImage: "bubble.left")
            }
        }

        Button {
            UIPasteboard.general.string = comment.text?.htmlStripped ?? ""
        } label: {
            Label("Copy Text", systemImage: "doc.on.doc")
        }

        let hnURL = URL(string: "https://news.ycombinator.com/item?id=\(comment.id)")!
        ShareLink(item: hnURL)

        if effectiveMode != .textOnly {
            Button {
                localRenderMode = .textOnly
            } label: {
                Label("View as Plain Text", systemImage: "text.alignleft")
            }
        } else {
            Button {
                localRenderMode = nil
            } label: {
                Label("Restore Full Rendering", systemImage: "richtext.page")
            }
        }

        if isLoggedIn {
            Button(role: .destructive) {
                Task {
                    do { try await HNAuthService.shared.flag(itemId: comment.id) } catch {
                        actionError = error.localizedDescription
                    }
                }
            } label: {
                Label("Flag", systemImage: "flag")
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Auto-load

    private func autoLoadIfNeeded() async {
        guard !hasAutoLoaded else { return }
        hasAutoLoaded = true

        guard settings.autoLoadReplyCount > 0,
            let kids = comment.kids, !kids.isEmpty
        else { return }

        // At depth limit, load just 1 reply for the preview snippet
        let count = atDepthLimit ? 1 : settings.autoLoadReplyCount

        // Only auto-load if within the auto-expand depth OR at the limit (for preview)
        guard depth <= maxDepth else { return }

        isLoadingReplies = true
        let batch = Array(kids.prefix(count))
        do {
            replies = try await HNAPIService.shared.items(ids: batch)
        } catch {
            // Silently fail — user can tap "Load more" / "Continue thread"
        }
        isLoadingReplies = false
    }

    // MARK: - Manual load

    private func loadMoreReplies() async {
        guard let kids = comment.kids, !kids.isEmpty else { return }
        isLoadingReplies = true

        let alreadyLoaded = replies.count
        let nextBatch = Array(kids.dropFirst(alreadyLoaded).prefix(10))

        do {
            let newReplies = try await HNAPIService.shared.items(ids: nextBatch)
            replies.append(contentsOf: newReplies)
        } catch {
            // Silently fail
        }
        isLoadingReplies = false
    }
}

// MARK: - Comment badge

/// Small inline pill used to mark the OP or a mod next to the username.
private struct CommentBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 10) {
            CommentView(comment: PreviewData.topComment, depth: 0)
            CommentView(comment: PreviewData.childComment, depth: 1)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
