// ContentView.swift
// Root view. Builds a floating pill TabView from whichever tabs the user has enabled.
// Feed is always first and cannot be removed. The remaining five are toggled in Settings.

import SwiftUI

struct ContentView: View {

    @State private var settings = UserSettings.shared
    @State private var deepLinkedStory: HNItem?
    @Environment(DeepLinkState.self) private var deepLink

    var body: some View {
        TabView {
            Tab(AppTab.feed.label, systemImage: AppTab.feed.systemImage) {
                NavigationStack { StoriesListView() }
            }
            if settings.enabledOptionalTabs.contains(.catchUp) {
                Tab(AppTab.catchUp.label, systemImage: AppTab.catchUp.systemImage) {
                    NavigationStack { CatchUpView() }
                }
            }
            if settings.enabledOptionalTabs.contains(.saved) {
                Tab(AppTab.saved.label, systemImage: AppTab.saved.systemImage) {
                    NavigationStack { SavedView() }
                }
            }
            if settings.enabledOptionalTabs.contains(.history) {
                Tab(AppTab.history.label, systemImage: AppTab.history.systemImage) {
                    NavigationStack { HistoryView() }
                }
            }
            if settings.enabledOptionalTabs.contains(.favourites) {
                Tab(AppTab.favourites.label, systemImage: AppTab.favourites.systemImage) {
                    NavigationStack { FavouritesView() }
                }
            }
            if settings.enabledOptionalTabs.contains(.curated) {
                Tab(AppTab.curated.label, systemImage: AppTab.curated.systemImage) {
                    NavigationStack { CuratedView() }
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
