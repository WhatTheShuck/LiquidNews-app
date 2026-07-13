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
    var story: HNItem? = nil
    /// True only for the first top-level comment, so it carries the commentLongPress
    /// coach-mark anchor. Replies and other comments leave this false.
    var isCoachMarkTarget: Bool = false

    @State private var isExpanded = true
    @State private var replies: [HNItem] = []
    @State private var isLoadingReplies = false
    @State private var hasAutoLoaded = false
    @State private var showThread: HNItem?

    // Long-press / actions
    @State private var auth = HNAuthService.shared
    @Environment(CoachMarkController.self) private var coachMarks: CoachMarkController?
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
                coachMarks?.reportInteraction(.commentTapCollapse)
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
                                        opUsername: opUsername, story: story)
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
        .modifier(CommentCardBackground(
            depth: depth, cornerRadius: 18, threadColor: threadColor,
            glass: settings.glassComments))
        // Reply loads animate ancestor card heights (staggered 120ms/depth).
        // Commit each card's animated frame as a single geometry change so
        // the glass shape and the card content can't desync mid-animation.
        .geometryGroup()
        .coachMarkTarget(isCoachMarkTarget ? .commentLongPress : nil)
        .coachMarkTarget(isCoachMarkTarget ? .commentTapCollapse : nil)
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showActions = true
            coachMarks?.reportInteraction(.commentLongPress)
        }
        .confirmationDialog("", isPresented: $showActions, titleVisibility: .hidden) {
            CommentActions(
                comment: comment,
                effectiveMode: effectiveMode,
                hasUpvoted: hasUpvoted,
                isOnline: NetworkMonitor.shared.currentlyOnline(),
                onToggleUpvote: {
                    Task {
                        if hasUpvoted {
                            try? await HNAuthService.shared.vote(itemId: comment.id, how: "un")
                            hasUpvoted = false
                        } else {
                            try? await HNAuthService.shared.vote(itemId: comment.id, how: "up")
                            hasUpvoted = true
                        }
                    }
                },
                onReply:                { showReply = true },
                onSetTextOnly:          { localRenderMode = .textOnly },
                onRestoreFullRendering: { localRenderMode = nil },
                onFlag: {
                    Task {
                        do { try await HNAuthService.shared.flag(itemId: comment.id) }
                        catch { actionError = error.localizedDescription }
                    }
                }
            )
        }
        .task {
            await autoLoadIfNeeded()
        }
        .sheet(item: $showThread) { thread in
            NavigationStack {
                ThreadView(rootComment: thread, depth: depth + 1, opUsername: opUsername, story: story)
            }
            .glassSheet()
            .iPadPageSheet()
        }
        .sheet(isPresented: $showReply) {
            NavigationStack { ComposeReplyView(parentId: comment.id) }
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

    // MARK: - Comment body rendering

    @ViewBuilder
    private func commentBody(for text: String) -> some View {
        CommentBodyContent(text: text, mode: effectiveMode, tintColor: threadColor)
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

        // Deliberately un-animated: initial population runs staggered across dozens
        // of cards while the thread loads, and any in-flight animation transaction
        // makes LazyVStack cells realised during it fly in from the top of the list.
        // User-initiated growth (loadMoreReplies) keeps its animation.
        isLoadingReplies = true
        let batch = Array(kids.prefix(count))
        let loaded = await Self.loadReplies(ids: batch)
        replies = loaded
        isLoadingReplies = false
    }

    // MARK: - Manual load

    private func loadMoreReplies() async {
        guard let kids = comment.kids, !kids.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) { isLoadingReplies = true }
        let alreadyLoaded = replies.count
        let nextBatch = Array(kids.dropFirst(alreadyLoaded).prefix(10))
        let newReplies = await Self.loadReplies(ids: nextBatch)
        withAnimation(.easeInOut(duration: 0.25)) {
            replies.append(contentsOf: newReplies)
            isLoadingReplies = false
        }
    }

    /// Cache-first reply loading. When online, fetch from the network and write the
    /// replies through to the cache (so a thread you read becomes offline-ready); when
    /// offline (or the fetch fails), assemble whatever is cached in `ids` order. This is
    /// what lets the comment layers prefetched for offline actually render without a
    /// connection.
    private static func loadReplies(ids: [Int]) async -> [HNItem] {
        if NetworkMonitor.shared.currentlyOnline(),
           let loaded = try? await HNAPIService.shared.items(ids: ids) {
            for reply in loaded {
                await HNCache.shared.storeItem(reply, fillSource: .readThrough, pinned: false)
            }
            return loaded
        }
        var cached: [HNItem] = []
        for id in ids {
            if let reply = await HNCache.shared.cachedItem(id: id) { cached.append(reply) }
        }
        return cached
    }
}

// MARK: - Card background

/// Card background for comment cards, per the user's "Glass comments" setting.
///
/// Glass mode: only depth-0 cards carry a live `.glassEffect`. Liquid Glass
/// does not support nested/overlapping glass surfaces — a reply card's glass
/// would live-sample its ancestors' glass output, which is what caused the
/// flicker and colour-desync artifacts on busy threads. Nested cards use a
/// plain thread-colour fill + stroke instead (no backdrop sampling); the
/// parent's glass shows through the translucent tint, so the nested look is
/// preserved (same treatment as the continue-thread preview boxes).
/// Depth-0 cards taller than `glassHeightLimit` fall back to the material
/// background: a single glass shape's backdrop pass covers the card's full
/// bounds, and past a few screen-heights the renderer degrades visibly.
///
/// Non-glass mode (default): `.ultraThinMaterial` at every depth — a fixed
/// UIBlurEffect with no live sampling, so no flicker regardless of thread size.
/// Depth 0 gets a slightly stronger tint and stroke for root-comment prominence.
private struct CommentCardBackground: ViewModifier {
    let depth: Int
    let cornerRadius: CGFloat
    let threadColor: Color
    let glass: Bool

    /// Above this height, a depth-0 glass card swaps to the material
    /// background. ~2.5 iPhone screens; tune on device if artifacts persist.
    static let glassHeightLimit: CGFloat = 2000

    @State private var exceedsGlassHeightLimit = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// True when this card should render live glass: depth 0, glass mode on,
    /// and under the height limit.
    private var glassActive: Bool { glass && depth == 0 && !exceedsGlassHeightLimit }

    func body(content: Content) -> some View {
        // `content` is deliberately outside the glass/material conditional:
        // branching around it would re-identify the subtree when the height
        // gate flips, resetting nested reply state. Only the background view
        // switches arms.
        content
            .background { cardBackground }
            .overlay(shape.stroke(threadColor.opacity(depth == 0 ? 0.35 : 0.25), lineWidth: 0.5))
            // Observed outside the background arms so the fallback card keeps
            // reporting its height and can return to glass when the thread is
            // collapsed. The action only fires when the Bool flips, and the
            // swap can't oscillate: the background choice doesn't change
            // layout height.
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.height > Self.glassHeightLimit
            } action: { exceeds in
                exceedsGlassHeightLimit = exceeds
            }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if glassActive {
            shape.fill(threadColor.opacity(0.12))
                .glassEffect(in: shape)
                // No morph transition when the glass surface appears or
                // disappears (initial insert in the lazy stack, and the
                // height-limit swap to/from material) — the morph is a
                // second live-sampling animation on top of the resize.
                .glassEffectTransition(.identity)
        } else if glass && depth > 0 {
            // Nested card: tint-only, no glass and no material. Slightly
            // stronger fill than material mode's 0.08 to compensate for
            // losing the per-card glass layer beneath it.
            shape.fill(threadColor.opacity(0.10))
        } else {
            // Material: the non-glass default at every depth, and the
            // fallback for depth-0 glass cards past the height limit.
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(threadColor.opacity(depth == 0 ? 0.12 : 0.08))
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        ThemeBackground(colorScheme: .dark).ignoresSafeArea()
        VStack(spacing: 10) {
            CommentView(comment: PreviewData.topComment, depth: 0)
            CommentView(comment: PreviewData.childComment, depth: 1)
        }
        .padding()
    }
}
