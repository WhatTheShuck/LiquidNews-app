// AdaptableTabRootView.swift
// Regular-size-class root view (iPad full/half, Mac). A single .sidebarAdaptable
// TabView: a compact floating tab bar that expands into a sidebar on demand.
// Feed first, then the user's enabled optional tabs in order, then Search and
// Settings grouped in a lower TabSection. Each browsing tab is a 2-column
// list | detail split (BrowsingTabView). Deep links route into the Feed tab's
// detail model. Search and Settings stay sheets on iPhone (see TabRootView) —
// this view is never instantiated on the compact path.

import SwiftUI

struct AdaptableTabRootView: View {

    enum Selection: Hashable {
        case tab(AppTab)
        case search
        case settings
    }

    @State private var settings = UserSettings.shared
    @State private var selection: Selection = .tab(.feed)
    // Feed's detail model is owned here (not inside BrowsingTabView) so deep links
    // can drive it. Other browsing tabs own their own models internally.
    @State private var feedModel = iPadNavModel()
    @State private var deepLinkError = false
    @Environment(DeepLinkState.self) private var deepLink

    private var optionalTabs: [AppTab] {
        // Feed is rendered explicitly first; this is the remainder.
        Array(settings.orderedEnabledTabs.dropFirst())
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.feed.label, systemImage: AppTab.feed.systemImage, value: Selection.tab(.feed)) {
                BrowsingTabView(tab: .feed, model: feedModel)
            }

            ForEach(optionalTabs) { tab in
                Tab(tab.label, systemImage: tab.systemImage, value: Selection.tab(tab)) {
                    BrowsingTabView(tab: tab)
                }
            }

            TabSection {
                Tab("Search", systemImage: "magnifyingglass", value: Selection.search) {
                    SearchView(showsCancel: false)
                }
                Tab("Settings", systemImage: "gearshape", value: Selection.settings) {
                    SettingsListView(showsCloseButton: false)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .preferredColorScheme(settings.selectedAppTheme == .classic ? .light : settings.appColorScheme.resolved)
        .onChange(of: deepLink.pendingItemID) { _, id in
            guard let id else { return }
            deepLink.pendingItemID = nil
            Task { await openItem(id: id) }
        }
    }

    // MARK: - Deep linking

    private func openItem(id: Int?) async {
        guard let id else { return }
        do {
            let item = try await HNAPIService.shared.item(id: id)
            // Selection and per-tab model are now separate pieces of state: switch
            // to the Feed tab AND set its detail model. v1 shows a comment item
            // directly in .comments mode; reproducing TabRootView's ThreadView
            // comment→story swap stays out of scope (iPad deep links remain at
            // today's degraded level).
            selection = .tab(.feed)
            feedModel.select(item, mode: .comments)
        } catch {
            deepLinkError = true
        }
    }
}
