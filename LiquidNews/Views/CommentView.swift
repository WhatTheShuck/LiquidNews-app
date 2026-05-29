// CommentView.swift
// Renders a single HN comment with:
//   • Depth-coloured glass tint (thread colour overlaid on the glass)
//   • Auto-expansion of the first N replies (controlled by UserSettings)
//   • Tap the header to collapse/expand
//   • Long-press context menu for comment actions (upvote, reply, copy, share, flag)
//   • Per-comment render-mode override (long-press → "View as Plain Text")
//   • "Continue thread →" at depth threshold → pushes ThreadView
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

    // Long-press / actions
    @State private var auth = HNAuthService.shared
    @State private var showReply = false
    @State private var actionError: String?
    @State private var hasUpvoted = false
    @State private var showActions = false

    // Per-comment render override (nil = follow global setting)
    @State private var localRenderMode: CommentRenderMode?

    private var settings: UserSettings { .shared }

    private var effectiveMode: CommentRenderMode {
        localRenderMode ?? settings.commentRenderingStyle
    }

    private var threadColor: Color {
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

    private var isLoggedIn: Bool { auth.isLoggedIn }
    private var isMod: Bool { HNItem.moderators.contains(comment.by ?? "") }
    private var isOP: Bool { comment.by != nil && comment.by == opUsername }
    private var isCurrentUser: Bool {
        comment.by != nil && comment.by == HNAuthService.shared.username
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Header: tap to collapse/expand ──
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

            // ── Body ──
            if isExpanded {
                if let text = comment.text, !text.isEmpty {
                    commentBody(for: text)
                        .transition(.opacity)
                }
            }

            // ── Replies ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if atDepthLimit {
                        continueThreadButtons
                    } else {
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

                        if isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(threadColor)
                                .frame(maxWidth: .infinity)
                        }

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
                                // Plain tinted capsule — no nested glassEffect inside the parent card
                                .background(Capsule().fill(threadColor.opacity(0.15)))
                                .overlay(Capsule().stroke(threadColor.opacity(0.3), lineWidth: 0.5))
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
        .modifier(CommentCardBackground(depth: depth, cornerRadius: 18, threadColor: threadColor))
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showActions = true
        }
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
        .alert("Action Failed", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Comment body rendering

    @ViewBuilder
    private func commentBody(for text: String) -> some View {
        Group {
            switch effectiveMode {
            case .textOnly:
                Text(text.htmlStripped)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            case .textWithLinks:
                Text(text.htmlWithLinks)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(AppTheme.accent)
            case .rich:
                CommentBodyView(html: text, tintColor: threadColor)
            }
        }
    }

    // MARK: - Long-press actions

    @ViewBuilder
    private var commentActions: some View {
        if isLoggedIn {
            Button(hasUpvoted ? "Unvote" : "Upvote") {
                Task {
                    if hasUpvoted {
                        try? await HNAuthService.shared.vote(itemId: comment.id, how: "un")
                        hasUpvoted = false
                    } else {
                        try? await HNAuthService.shared.vote(itemId: comment.id, how: "up")
                        hasUpvoted = true
                    }
                }
            }
            Button("Reply") { showReply = true }
        }

        Button("Copy Text") {
            UIPasteboard.general.string = comment.text?.htmlStripped ?? ""
        }

        let hnURL = URL(string: "https://news.ycombinator.com/item?id=\(comment.id)")!
        ShareLink(item: hnURL)

        if effectiveMode != .textOnly {
            Button("View as Plain Text") { localRenderMode = .textOnly }
        } else {
            Button("Restore Full Rendering") { localRenderMode = nil }
        }

        if isLoggedIn {
            Button("Flag", role: .destructive) {
                Task {
                    do { try await HNAuthService.shared.flag(itemId: comment.id) }
                    catch { actionError = error.localizedDescription }
                }
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Continue thread

    @ViewBuilder
    private var continueThreadButtons: some View {
        let childCount = comment.kids?.count ?? 0
        if childCount > 0 {
            if let firstReply = replies.first {
                let replyColor = AppTheme.threadColor(depth: depth + 1)
                // Leaf: single child with no further replies — render inline.
                if childCount == 1 && (firstReply.kids?.count ?? 0) == 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(firstReply.by ?? "[deleted]")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(replyColor)
                            if HNItem.moderators.contains(firstReply.by ?? "") {
                                CommentBadge(label: "mod", color: .green)
                            }
                            if firstReply.by != nil && firstReply.by == opUsername {
                                CommentBadge(label: "OP", color: Color(red: 0.45, green: 0.65, blue: 1.0))
                            }
                            Spacer()
                            Text(firstReply.timeAgo)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        if let text = firstReply.text, !text.isEmpty {
                            Text(text.htmlStripped)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(replyColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(replyColor.opacity(0.25), lineWidth: 0.5)
                    )
                    .padding(.top, 4)
                } else {
                    // Non-leaf: first child preview, tap to open thread
                    Button {
                        showThread = comment
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(firstReply.by ?? "[deleted]")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(replyColor)
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
                                        .foregroundStyle(.primary.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(replyColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(replyColor.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    if childCount > 1 {
                        Text("Continue thread (\(childCount) replies) →")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(threadColor.opacity(0.85))
                            .onTapGesture { showThread = comment }
                    }
                }
            } else {
                // Replies not yet loaded
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

    // MARK: - Auto-load

    private func autoLoadIfNeeded() async {
        guard !hasAutoLoaded else { return }
        hasAutoLoaded = true

        guard settings.autoLoadReplyCount > 0,
            let kids = comment.kids, !kids.isEmpty
        else { return }

        let count = atDepthLimit ? 1 : settings.autoLoadReplyCount
        guard depth <= maxDepth else { return }

        // Stagger deeper cards so they don't all fire at the same moment as their
        // parent. Depth 0 is immediate; each level adds 120ms. This spreads the
        // request burst across time and keeps the UI responsive during initial load.
        if depth > 0 {
            try? await Task.sleep(for: .milliseconds(depth * 120))
            guard !Task.isCancelled else { return }
        }

        withAnimation(.easeInOut(duration: 0.25)) { isLoadingReplies = true }
        let batch = Array(kids.prefix(count))
        do {
            let loaded = try await HNAPIService.shared.items(ids: batch)
            withAnimation(.easeInOut(duration: 0.25)) {
                replies = loaded
                isLoadingReplies = false
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.25)) { isLoadingReplies = false }
        }
    }

    // MARK: - Manual load

    private func loadMoreReplies() async {
        guard let kids = comment.kids, !kids.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) { isLoadingReplies = true }
        let alreadyLoaded = replies.count
        let nextBatch = Array(kids.dropFirst(alreadyLoaded).prefix(10))
        do {
            let newReplies = try await HNAPIService.shared.items(ids: nextBatch)
            withAnimation(.easeInOut(duration: 0.25)) {
                replies.append(contentsOf: newReplies)
                isLoadingReplies = false
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.25)) { isLoadingReplies = false }
        }
    }
}

// MARK: - Card background

/// Applies glass at depth 0 only. Nesting glassEffect inside glassEffect causes the
/// parent's material to re-sample out of sync with layout changes, producing glow flicker.
private struct CommentCardBackground: ViewModifier {
    let depth: Int
    let cornerRadius: CGFloat
    let threadColor: Color

    func body(content: Content) -> some View {
        if depth == 0 {
            content
                .glassCard(cornerRadius: cornerRadius, tint: threadColor)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(threadColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(threadColor.opacity(0.25), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Comment badge

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
        AppTheme.backgroundGradient(for: .dark).ignoresSafeArea()
        VStack(spacing: 10) {
            CommentView(comment: PreviewData.topComment, depth: 0)
            CommentView(comment: PreviewData.childComment, depth: 1)
        }
        .padding()
    }
}
