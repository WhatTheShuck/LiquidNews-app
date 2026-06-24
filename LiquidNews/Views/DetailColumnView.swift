// DetailColumnView.swift
// The detail (right) column of the iPad/Mac split view. Renders the selected
// story per the model's detailMode, with a Reader⇄Comments toggle in the
// toolbar, or a neutral placeholder when nothing is selected.

import SwiftUI

struct DetailColumnView: View {
    let model: iPadNavModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = UserSettings.shared

    var body: some View {
        Group {
            if let story = storyToShow {
                content(for: story)
                    .toolbar {
                        if !isSideBySide {
                            toggleToolbar(for: story)
                        }
                    }
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

    /// Closes the current article: clears the selection so the detail column
    /// returns to its placeholder. Routed from `StoryDetailView`'s ✕ button, whose
    /// default `dismiss()` is a no-op inside a split-view detail column.
    private func closeArticle() {
        withAnimation(.smooth) { model.selectedStory = nil }
    }

    @ViewBuilder
    private func content(for story: HNItem) -> some View {
        switch model.detailMode {
        // `.replace` reader and in-app browser take over the whole detail column.
        case .reader where !isSideBySide:
            if let url = storyURL {
                ArticleReaderView(url: url)   // replace path — nav-bar chrome
            } else {
                StoryDetailView(story: story, onClose: closeArticle)
            }
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

    /// Comments pane (full width, or narrower when side by side) with the reader
    /// sliding in from the trailing edge when side-by-side reading is active.
    /// Closing the reader (floating ✕) sets `detailMode = .comments`, which removes
    /// the pane. A 320pt floor keeps comments legible in iPad portrait.
    private func commentsWithOptionalReader(story: HNItem) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                StoryDetailView(story: story, onClose: closeArticle)
                    .frame(width: isSideBySide ? max(320, geo.size.width * 0.42) : geo.size.width)
                    // Snap the comments width rather than animating it: animating the
                    // width continuously rewraps/reflows the comments ScrollView,
                    // which makes it jitter vertically. The reader pane still slides
                    // in via its own transition.
                    .animation(nil, value: isSideBySide)
                if isSideBySide, let url = storyURL {
                    Divider()
                    ArticleReaderView(url: url, chromeStyle: .floating, onClose: {
                        withAnimation(.smooth) { model.detailMode = .comments }
                    })
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing))
                }
            }
        }
    }

    /// Reader⇄Comments toggle. Disabled when the story has no URL (nothing to
    /// read), in which case only comments are available.
    @ToolbarContentBuilder
    private func toggleToolbar(for story: HNItem) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.smooth) {
                    model.detailMode = (model.detailMode == .comments) ? .reader : .comments
                }
            } label: {
                Label(
                    model.detailMode == .comments ? "Reader" : "Comments",
                    systemImage: model.detailMode == .comments ? "textformat" : "bubble.left"
                )
            }
            .disabled(storyURL == nil)
        }
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
