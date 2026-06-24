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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
        } content: {
            contentColumn
                // Presence of the model is the iPad routing signal for list views.
                .environment(\.iPadNavModel, model)
        } detail: {
            NavigationStack {
                DetailColumnView(model: model)
            }
            // StoryDetailView / ArticleReaderView seed their own @State from the
            // story/url in init, and @State is only honored once per view
            // identity. Giving the detail stack a distinct identity per selected
            // story (and mode) makes SwiftUI rebuild it fresh on each selection,
            // so the comments and reader content track the chosen story instead
            // of staying on the first one shown.
            .id(detailColumnIdentity)
            .environment(\.iPadNavModel, model)
        }
        .preferredColorScheme(settings.selectedAppTheme == .classic ? .light : settings.appColorScheme.resolved)
        .onChange(of: model.isReaderSideBySideVisible(layout: settings.iPadReaderLayout)) { _, active in
            withAnimation { columnVisibility = active ? .detailOnly : .all }
        }
        .onChange(of: deepLink.pendingItemID) { _, id in
            guard let id else { return }
            deepLink.pendingItemID = nil
            Task { await openItem(id: id) }
        }
    }

    /// Identity for the detail stack. Changes whenever the selected story or its
    /// presentation mode changes (constant while nothing is selected), so the
    /// detail view is rebuilt fresh per selection.
    private var detailColumnIdentity: String {
        guard case .tab = model.destination, let story = model.selectedStory else {
            return "none"
        }
        return "\(story.id)-\(model.detailMode)"
    }

    // MARK: - Content column routing

    @ViewBuilder
    private var contentColumn: some View {
        switch model.destination {
        // List views and AccountView need an enclosing NavigationStack for their
        // titles/toolbars. SettingsListView already wraps itself in one, and
        // SearchView is a self-contained ZStack — wrapping either would double
        // the navigation bar in the content column.
        case .tab(let tab): NavigationStack { listView(for: tab) }
        case .search:       SearchView()
        case .settings:     SettingsListView()
        case .account:      NavigationStack { AccountView() }
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
            // Route into the Feed tab's detail column. DetailColumnView only
            // renders a story when the destination is a browsing tab, so a deep
            // link arriving while Settings/Account/Search is selected must switch
            // back to a tab. v1 shows a comment item directly in .comments mode;
            // reproducing TabRootView's ThreadView comment→story swap is out of
            // scope here.
            model.destination = .tab(.feed)
            model.select(item, mode: .comments)
        } catch {
            deepLinkError = true
        }
    }
}
