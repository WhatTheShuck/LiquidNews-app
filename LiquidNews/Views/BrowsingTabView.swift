// BrowsingTabView.swift
// One top-level browsing tab on iPad/Mac (regular width): a 2-column
// NavigationSplitView showing the tab's list (leading) and the selected story's
// detail (trailing). Owns one iPadNavModel and injects it into the list column —
// the presence of that model is what tells list views to drive the detail column
// instead of presenting sheets. The detail stack is rebuilt per selection via
// .id() so seeded @State tracks the chosen story.

import SwiftUI

struct BrowsingTabView: View {
    let tab: AppTab
    @State private var model: iPadNavModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var settings = UserSettings.shared

    init(tab: AppTab, model: iPadNavModel? = nil) {
        self.tab = tab
        _model = State(initialValue: model ?? iPadNavModel())
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // List views and AccountView need an enclosing NavigationStack for
            // their titles/toolbars.
            NavigationStack { listView(for: tab) }
                // Presence of the model is the iPad routing signal for list views.
                .environment(\.iPadNavModel, model)
        } detail: {
            NavigationStack {
                DetailColumnView(model: model)
            }
            // Distinct identity PER STORY (not per mode) so selecting a new story
            // rebuilds the detail stack fresh — StoryDetailView/ArticleReaderView
            // seed @State from the story/url in init, honored once per identity.
            // Mode changes (comments⇄reader) deliberately keep the same identity so
            // the reader pane can animate in/out instead of the whole stack being
            // torn down and rebuilt.
            .id(detailColumnIdentity)
            // The detail column also needs the model: StoryDetailView's "Read
            // Article" / related-story buttons route through \.iPadNavModel to flip
            // the column to the reader (side-by-side) instead of opening a sheet.
            // Without this the detail column would fall back to the iPhone sheet path.
            .environment(\.iPadNavModel, model)
        }
        // The inner split view is the one users collapse; the outer .sidebarAdaptable
        // rail is driven only by the system tab-bar expand affordance.
        .navigationSplitViewStyle(.balanced)
        // Auto-collapse the list column while reading side by side, so comments and
        // the reader get the full width; restore all columns when leaving the reader.
        .onChange(of: model.isReaderSideBySide(layout: settings.iPadReaderLayout)) { _, reading in
            withAnimation(.smooth) { columnVisibility = reading ? .detailOnly : .all }
        }
    }

    /// Identity for the detail stack — constant while nothing is selected, and
    /// constant across mode changes for a given story (see `.id` note above).
    private var detailColumnIdentity: String {
        guard let story = model.selectedStory else { return "none" }
        return "\(story.id)"
    }

    @ViewBuilder
    private func listView(for tab: AppTab) -> some View {
        switch tab {
        case .feed:       StoriesListView()
        case .catchUp:    CatchUpView()
        case .readLater:  ReadLaterView()
        case .history:    HistoryView()
        case .favourites: FavouritesView()
        case .curated:    CuratedView()
        }
    }
}
