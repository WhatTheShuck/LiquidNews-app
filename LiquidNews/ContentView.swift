// ContentView.swift
// Root view. Builds a floating pill TabView from whichever tabs the user has enabled,
// in the order the user has arranged them in Settings.
// Feed is always first and cannot be removed or reordered.

import SwiftUI

struct ContentView: View {

    @State private var settings = UserSettings.shared
    @State private var deepLinkedStory: HNItem?
    @Environment(DeepLinkState.self) private var deepLink

    /// Optional tabs in user-defined order, filtered to only the enabled ones.
    private var orderedEnabledTabs: [AppTab] {
        settings.tabOrder.filter { settings.enabledOptionalTabs.contains($0) }
    }

    var body: some View {
        TabView {
            Tab(AppTab.feed.label, systemImage: AppTab.feed.systemImage) {
                NavigationStack { StoriesListView() }
            }
            ForEach(orderedEnabledTabs) { tab in
                Tab(tab.label, systemImage: tab.systemImage) {
                    tabContent(for: tab)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $deepLinkedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .onChange(of: deepLink.pendingItemID) { _, id in
            guard let id else { return }
            deepLink.pendingItemID = nil
            Task { await openStory(id: id) }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .feed:       NavigationStack { StoriesListView() }
        case .catchUp:    NavigationStack { CatchUpView() }
        case .saved:      NavigationStack { SavedView() }
        case .history:    NavigationStack { HistoryView() }
        case .favourites: NavigationStack { FavouritesView() }
        case .curated:    NavigationStack { CuratedView() }
        }
    }

    // MARK: - Deep linking

    private func openStory(id: Int?) async {
        guard let id,
              let story = try? await HNAPIService.shared.item(id: id) else { return }
        deepLinkedStory = story
    }
}

#Preview {
    ContentView()
}
