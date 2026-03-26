// ContentView.swift
// Root view. Builds a floating pill TabView from whichever tabs the user has enabled.
// Feed is always first and cannot be removed. The remaining four are toggled in Settings.

import SwiftUI

struct ContentView: View {

    @State private var settings = UserSettings.shared

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
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
