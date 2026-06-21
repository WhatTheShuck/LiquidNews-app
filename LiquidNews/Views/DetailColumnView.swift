// DetailColumnView.swift
// The detail (right) column of the iPad/Mac split view. Renders the selected
// story per the model's detailMode, with a Reader⇄Comments toggle in the
// toolbar, or a neutral placeholder when nothing is selected.

import SwiftUI

struct DetailColumnView: View {
    let model: iPadNavModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let story = storyToShow {
                content(for: story)
                    .toolbar { toggleToolbar(for: story) }
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

    @ViewBuilder
    private func content(for story: HNItem) -> some View {
        switch model.detailMode {
        case .comments:
            StoryDetailView(story: story)
        case .reader:
            if let url = storyURL {
                ArticleReaderView(url: url)
            } else {
                StoryDetailView(story: story)
            }
        case .browser:
            if let url = storyURL {
                SafariView(url: url).ignoresSafeArea()
            } else {
                StoryDetailView(story: story)
            }
        }
    }

    /// Reader⇄Comments toggle. Disabled when the story has no URL (nothing to
    /// read), in which case only comments are available.
    @ToolbarContentBuilder
    private func toggleToolbar(for story: HNItem) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.detailMode = (model.detailMode == .comments) ? .reader : .comments
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
