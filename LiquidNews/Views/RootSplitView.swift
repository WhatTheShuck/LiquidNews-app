// RootSplitView.swift
// The iPad/Mac three-column layout (regular width). Sidebar selects a
// destination; the content column shows that destination's list (or Settings/
// Account/Search); selecting a story drives the detail column via iPadNavModel.
// Deep links route into the model instead of presenting sheets.

import SwiftUI

struct RootSplitView: View {
    @State private var model = iPadNavModel()
    @State private var deepLinkError = false
    @Environment(DeepLinkState.self) private var deepLink
    @State private var settings = UserSettings.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } content: {
            NavigationStack {
                contentColumn
            }
            // Presence of the model is the iPad routing signal for list views.
            .environment(\.iPadNavModel, model)
        } detail: {
            NavigationStack {
                DetailColumnView(model: model)
            }
        }
        .preferredColorScheme(settings.selectedAppTheme == .classic ? .light : settings.appColorScheme.resolved)
        .onChange(of: deepLink.pendingItemID) { _, id in
            guard let id else { return }
            deepLink.pendingItemID = nil
            Task { await openItem(id: id) }
        }
    }

    // MARK: - Content column routing

    @ViewBuilder
    private var contentColumn: some View {
        switch model.destination {
        case .tab(let tab): listView(for: tab)
        case .search:       SearchView()
        case .settings:     SettingsListView()
        case .account:      AccountView()
        }
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

    // MARK: - Deep linking (routes into the detail column, not a sheet)

    private func openItem(id: Int?) async {
        guard let id else { return }
        do {
            let item = try await HNAPIService.shared.item(id: id)
            if item.type == .comment {
                // Fetch the parent story so the detail column can show context,
                // mirroring TabRootView's comment→story swap. If unavailable,
                // fall back to showing the item itself as comments.
                model.select(item, mode: .comments)
            } else {
                model.destination = .tab(.feed)
                model.select(item, mode: .comments)
            }
        } catch {
            deepLinkError = true
        }
    }
}
