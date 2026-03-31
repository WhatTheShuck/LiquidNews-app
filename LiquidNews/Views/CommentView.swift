// CommentView.swift
// Renders a single HN comment with:
//   • Depth-coloured glass tint (thread colour overlaid on the glass)
//   • Auto-expansion of the first N replies (controlled by UserSettings)
//   • Tap the header to collapse/expand
//   • "Continue thread →" at depth threshold → pushes ThreadView
//   • Long-press context menu for comment actions, including per-comment render mode override
//   • Manual "Load N more" for replies beyond the auto-loaded batch

import SwiftUI

struct CommentView: View {
    let comment: HNItem
    let depth: Int
    /// Maximum inline nesting depth. Beyond this, a "Continue thread" button
    /// replaces inline replies and pushes a focused ThreadView.
    /// Defaults to UserSettings value; ThreadView passes .max to disable.
    var maxDepth: Int = UserSettings.shared.maxAutoExpandDepth

    @State private var isExpanded = true
    @State private var replies: [HNItem] = []
    @State private var isLoadingReplies = false
    @State private var hasAutoLoaded = false
    @State private var showThread: HNItem?

    // MARK: Rendering
    /// Per-comment override. nil means "follow the global setting".
    @State private var localRenderMode: CommentRenderMode?
    /// Computed rich text for .rich mode; nil until computed.
    @State private var richText: AttributedString?

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

    private var isLoggedIn: Bool { false }

    var body: some View {
        // ── Comment card ──
        VStack(alignment: .leading, spacing: 8) {

            // Header — tap anywhere on this row to collapse/expand
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center) {
                    Text(comment.by ?? "[deleted]")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(threadColor)

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
                // Comment body
                if let text = comment.text, !text.isEmpty {
                    commentBody(for: text)
                }

                if atDepthLimit {
                    // ── "Continue thread →" at depth limit ──
                    continueThreadButtons
                } else {
                    // ── Inline replies (recursive) ──
                    if !replies.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(replies) { reply in
                                CommentView(comment: reply, depth: depth + 1, maxDepth: maxDepth)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Loading indicator
                    if isLoadingReplies {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(threadColor)
                    }

                    // "Load more" — centered rounded capsule
                    if remainingCount > 0 && !isLoadingReplies {
                        HStack {
                            Spacer()
                            Button {
                                Task { await loadMoreReplies() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.bubble")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("\(remainingCount) more repl\(remainingCount == 1 ? "y" : "ies")")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(threadColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassCard(cornerRadius: 20, tint: threadColor)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18, tint: threadColor)
        .contextMenu { commentContextMenu }
        .task {
            await autoLoadIfNeeded()
        }
        .task(id: effectiveMode) {
            await computeRichTextIfNeeded()
        }
        .sheet(item: $showThread) { thread in
            NavigationStack {
                ThreadView(rootComment: thread, depth: depth + 1)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
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
            if let richText {
                Text(richText)
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(AppTheme.accent)
            } else {
                // Shown briefly while richText is being computed
                Text(text.htmlStripped)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Rich text computation

    private func computeRichTextIfNeeded() async {
        guard effectiveMode == .rich, richText == nil, let text = comment.text, !text.isEmpty else { return }
        richText = makeRichText(from: text)
    }

    /// Parses HN HTML into a styled `AttributedString` using WebKit's HTML engine.
    /// Preserves bold, italic, inline code, code blocks, and tappable links.
    private func makeRichText(from html: String) -> AttributedString? {
        // Inject CSS so the parsed text matches the app's dark glass aesthetic.
        // NSAttributedString HTML parsing requires UTF-8 data.
        let styledHTML = """
        <html><head><meta charset="UTF-8"><style>
        body  { font-family: -apple-system; font-size: 14px; color: #DCDCDC; }
        a     { color: #FF6B14; text-decoration: none; }
        code  { font-family: Menlo, 'SF Mono', monospace; font-size: 12px; }
        pre   { font-family: Menlo, 'SF Mono', monospace; font-size: 12px; }
        p     { margin: 0; padding: 0 0 8px 0; }
        </style></head><body>\(html)</body></html>
        """

        guard let data = styledHTML.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        guard let nsAS = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        // Trim the trailing newline that NSAttributedString HTML parsing always adds
        let trimmed: NSAttributedString
        if nsAS.length > 0 {
            let str = nsAS.string
            let trailingNewlines = str.reversed().prefix(while: { $0.isNewline }).count
            if trailingNewlines > 0 {
                trimmed = nsAS.attributedSubstring(from: NSRange(location: 0, length: nsAS.length - trailingNewlines))
            } else {
                trimmed = nsAS
            }
        } else {
            trimmed = nsAS
        }

        return try? AttributedString(trimmed, including: \.uiKit)
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
                            Text(firstReply.by ?? "[deleted]")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.threadColor(depth: depth + 1))

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
                        Text("Continue thread (\(childCount) repl\(childCount == 1 ? "y" : "ies")) →")
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

    // MARK: - Context menu

    @ViewBuilder
    private var commentContextMenu: some View {
        Section {
            Button(action: {}) {
                Label("Upvote", systemImage: "arrow.up")
            }
            .disabled(!isLoggedIn)

            Button(action: {}) {
                Label("Downvote", systemImage: "arrow.down")
            }
            .disabled(!isLoggedIn)
        }

        Section {
            Button(action: {}) {
                Label("Reply", systemImage: "bubble.left")
            }
            .disabled(!isLoggedIn)

            Button {
                UIPasteboard.general.string = comment.text?.htmlStripped ?? ""
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }

            let hnURL = URL(string: "https://news.ycombinator.com/item?id=\(comment.id)")!
            ShareLink(item: hnURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        // ── Rendering mode override ──
        Section {
            if effectiveMode != .textOnly {
                Button {
                    localRenderMode = .textOnly
                } label: {
                    Label("View as Plain Text", systemImage: "text.alignleft")
                }
            } else {
                Button {
                    // Clear the override — falls back to global setting
                    localRenderMode = nil
                } label: {
                    Label("Restore Full Rendering", systemImage: "textformat.alt")
                }
            }
        }

        Section {
            Button(role: nil, action: {}) {
                Label("Flag", systemImage: "flag")
            }
            .disabled(!isLoggedIn)
        }
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
