// DetailColumnView.swift
// The detail (right) column of the iPad/Mac split view. Renders the selected
// story per the model's detailMode, with a Reader⇄Comments toggle in the
// toolbar, or a neutral placeholder when nothing is selected.

import SwiftUI

struct DetailColumnView: View {
    let model: iPadNavModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = UserSettings.shared

    /// Persisted comments-pane width as a fraction of the detail column, used while
    /// reading side by side. Adjusted by dragging the center divider; clamped to the
    /// per-pane minimums below so neither pane can be squeezed away.
    @AppStorage("iPadCommentsFraction") private var commentsFraction: Double = 0.42

    /// True while the user is actively dragging the divider — drives the handle's
    /// active (lifted) appearance. Resets automatically when the gesture ends.
    @GestureState private var isResizing = false

    private let minCommentsWidth: CGFloat = 320
    private let minReaderWidth: CGFloat = 360
    private let splitSpace = "detailSplit"

    var body: some View {
        Group {
            if let story = storyToShow {
                content(for: story)
                    // Side by side, each pane carries its own glass control strip, so
                    // the shared detail nav bar (and its system "show columns" button)
                    // is hidden to avoid a second, full-width row of controls.
                    .toolbar(isSideBySide ? .hidden : .automatic, for: .navigationBar)
            } else {
                placeholder
            }
        }
    }

    /// Only show a story when a browsing tab is the active destination.
    /// Settings/Account/Search destinations leave the detail column empty.
    private var storyToShow: HNItem? {
        if case .tab = model.destination { return model.selectedStory }
        return nil
    }

    private var storyURL: URL? {
        guard let s = model.selectedStory?.url else { return nil }
        return URL(string: s)
    }

    /// Closes the current article: clears the selection and resets the detail mode
    /// so the split view returns to its full layout (list + placeholder). Routed
    /// from `StoryDetailView`'s ✕ button, whose default `dismiss()` is a no-op
    /// inside a split-view detail column. Resetting the mode (via `closeStory`) is
    /// what un-collapses the split when closing from the comments pane while reading
    /// side by side — see `iPadNavModel.closeStory()`.
    private func closeArticle() {
        withAnimation(.smooth) { model.closeStory() }
    }

    @ViewBuilder
    private func content(for story: HNItem) -> some View {
        switch model.detailMode {
        // `.replace` reader and in-app browser take over the whole detail column.
        case .reader where !isSideBySide:
            if let url = storyURL {
                // Replace path — nav-bar chrome. Its ✕ would otherwise call the
                // environment `dismiss`, a no-op inside the detail column. Route it
                // back to comments instead, matching the side-by-side reader pane's
                // ✕ so the icon means the same thing in both layouts.
                ArticleReaderView(url: url, onClose: backToComments)
            } else {
                StoryDetailView(story: story, onClose: closeArticle)
            }
        // A deep-linked comment: show the focused thread with a swap to its parent
        // story (mirrors iPhone's TabRootView ThreadView → StoryDetailView flow).
        case .thread:
            ThreadView(
                rootComment: story,
                depth: 0,
                onClose: closeArticle,
                onShowStory: { resolved in
                    withAnimation(.smooth) { model.select(resolved, mode: .comments) }
                }
            )
        case .browser:
            if let url = storyURL {
                SafariView(url: url).ignoresSafeArea()
            } else {
                StoryDetailView(story: story, onClose: closeArticle)
            }
        // `.comments` and side-by-side `.reader` share this branch: the comments
        // pane stays mounted (preserving its scroll position) while the reader pane
        // slides in beside it, so toggling between them animates instead of rebuilding.
        default:
            commentsWithOptionalReader(story: story)
        }
    }

    /// True when the detail column should show comments and the reader side by side.
    private var isSideBySide: Bool {
        model.isReaderSideBySide(layout: settings.iPadReaderLayout) && storyURL != nil
    }

    /// Comments pane (full width, or a resizable fraction when side by side) with
    /// the reader sliding in from the trailing edge when side-by-side reading is
    /// active. Closing the reader (its toolbar ✕) sets `detailMode = .comments`,
    /// which removes the pane. The center divider is draggable to rebalance the two
    /// panes; per-pane minimums keep both legible in iPad portrait.
    private func commentsWithOptionalReader(story: HNItem) -> some View {
        GeometryReader { geo in
            let total = geo.size.width
            let commentsWidth = isSideBySide ? clampedCommentsWidth(total: total) : total
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // `inlineControls` makes the comments pane host its own glass
                    // control strip (close / refresh / more) instead of a nav-bar
                    // toolbar, so its controls stay confined to this pane rather than
                    // hoisting into the shared detail bar alongside the reader's.
                    StoryDetailView(story: story, onClose: closeArticle, inlineControls: isSideBySide)
                        .frame(width: commentsWidth)
                        // Snap the comments width rather than animating it: animating
                        // the width continuously rewraps/reflows the comments
                        // ScrollView, which makes it jitter vertically. This also keeps
                        // the pane tracking the finger directly while dragging the
                        // divider. The reader pane still slides in via its transition.
                        .animation(nil, value: isSideBySide)
                        .animation(nil, value: commentsWidth)
                    if isSideBySide, let url = storyURL {
                        // Floating chrome keeps the reader's controls as a glass strip
                        // confined to this pane. (A nested NavigationStack toolbar
                        // would hoist its items into the shared detail bar.) The reader
                        // insets its own content below the strip so nothing overlaps.
                        ArticleReaderView(url: url, chromeStyle: .floating, onClose: {
                            withAnimation(.smooth) { model.detailMode = .comments }
                        })
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .trailing))
                    }
                }
                // The grabber floats on the seam as an overlay rather than occupying
                // layout width between the panes, so the panes sit flush and only the
                // handle shows at rest — the seam line appears only while dragging.
                if isSideBySide, storyURL != nil {
                    resizableDivider(total: total, seamX: commentsWidth)
                }
            }
            .coordinateSpace(name: splitSpace)
        }
    }

    /// Comments-pane width derived from the persisted fraction, clamped so both
    /// panes keep their minimum width regardless of the detail column's size.
    private func clampedCommentsWidth(total: CGFloat) -> CGFloat {
        let maxComments = max(minCommentsWidth, total - minReaderWidth)
        return min(max(total * commentsFraction, minCommentsWidth), maxComments)
    }

    /// Draggable seam overlay. A thin full-height grab zone is positioned over the
    /// boundary at `seamX`; only the glass handle shows at rest, and the seam line
    /// fades in while dragging. Reading the drag's absolute x within the split's
    /// coordinate space (rather than accumulating deltas) keeps it pinned under the
    /// finger. The handle lifts and brightens while in use.
    private func resizableDivider(total: CGFloat, seamX: CGFloat) -> some View {
        let zoneWidth: CGFloat = 24
        return ZStack {
            if isResizing {
                Rectangle()
                    .fill(.primary.opacity(0.22))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            DividerHandle(isActive: isResizing)
        }
        .frame(width: zoneWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .offset(x: seamX - zoneWidth / 2)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(splitSpace))
                .updating($isResizing) { _, state, _ in state = true }
                .onChanged { value in
                    let maxComments = max(minCommentsWidth, total - minReaderWidth)
                    let clamped = min(max(value.location.x, minCommentsWidth), maxComments)
                    commentsFraction = Double(clamped / total)
                }
        )
        .animation(.easeOut(duration: 0.15), value: isResizing)
    }

    /// Returns the detail column to the comments pane. Used as the replace-layout
    /// reader's ✕ action, where the environment `dismiss` is a no-op — mirroring the
    /// side-by-side reader pane's ✕, so the icon means the same thing in both layouts.
    private func backToComments() {
        withAnimation(.smooth) { model.detailMode = .comments }
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "newspaper")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.accent)
                Text("Select a story")
                    .font(AppTheme.titleFont(20))
                    .foregroundStyle(.primary)
                Text("Pick a story from the list to read it here.")
                    .font(AppTheme.bodyFont(14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Divider handle

/// A raised glass grabber centered on the split's seam. The pill shape with grip
/// dots and a soft shadow reads as draggable on sight; it lifts and brightens
/// while in use and shows a pointer lift effect under a trackpad/mouse.
private struct DividerHandle: View {
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.primary.opacity(isActive ? 0.85 : 0.55))
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .frame(width: 10, height: 60)
        .glassEffect(in: Capsule())
        .overlay(
            Capsule().strokeBorder(.white.opacity(isActive ? 0.35 : 0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: isActive ? 8 : 4, y: 1)
        .scaleEffect(isActive ? 1.14 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .contentShape(Capsule())
        .hoverEffect(.lift)
    }
}
