// RootSplitView.swift
// The iPad/Mac three-column layout (regular width). Sidebar selects a
// destination; the content column shows that destination's list (or Settings/
// Search); selecting a story drives the detail column via iPadNavModel.
// Deep links route into the model instead of presenting sheets.

import SwiftUI

struct RootSplitView: View {
    @State private var model = iPadNavModel()
    @State private var deepLinkError = false
    @Environment(DeepLinkState.self) private var deepLink
    @State private var settings = UserSettings.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private let coachStore = CoachMarkStore.shared
    @State private var showDividerHint = false
    /// Suppress the divider hint while the What's New sheet may be presenting on
    /// the same launch (coach marks defer to sheets).
    @AppStorage("LN_lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @AppStorage("LN_hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(model: model)
        } content: {
            contentColumn
                // Rebuild the content column from scratch whenever the sidebar
                // selection changes. Settings categories push onto SettingsListView's
                // own NavigationStack (which lives here, in the content column);
                // without a fresh identity per destination, that pushed page stays
                // wedged in place when you pick another sidebar row — you can't leave
                // it, and the wedged stack blocks the detail column from opening a
                // story. Keying on the destination tears the pushed stack down so each
                // sidebar selection starts clean.
                .id(model.destination)
                // Presence of the model is the iPad routing signal for list views.
                .environment(\.iPadNavModel, model)
                // Search (and Settings → Hidden Posts) present story sheets straight
                // from this column, so it needs the same regular-size-class fix the
                // detail column applies — otherwise those sheets come up as small
                // form sheets. (See RegularSizeClass.swift / DetailColumnView.)
                .forceRegularSizeClassForPresentations()
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
        // Changing the sidebar selection clears the screen: drop any open story so
        // the detail column resets to its placeholder (rather than re-showing the
        // previous selection when you return to a browsing tab) and so the split
        // un-collapses from a side-by-side reader. The content column itself is rebuilt
        // via `.id(model.destination)` above.
        .onChange(of: model.destination) { _, _ in
            model.closeStory()
        }
        .onChange(of: deepLink.pendingItemID) { _, id in
            guard let id else { return }
            deepLink.pendingItemID = nil
            Task { await openItem(id: id) }
        }
        .overlay {
            GeometryReader { proxy in
                if showDividerHint {
                    let x = proxy.size.width * 0.62
                    let rect = CGRect(x: x, y: proxy.size.height / 2 - 1, width: 2, height: 2)
                    CoachMarkBubble(
                        text: CoachMark.iPadDividerResize.text,
                        arrowEdge: CoachMark.iPadDividerResize.arrowEdge,
                        targetRect: rect
                    ) {
                        coachStore.markSeen(.iPadDividerResize)
                        showDividerHint = false
                    }
                    .animation(.easeInOut(duration: 0.25), value: showDividerHint)
                }
            }
            .allowsHitTesting(showDividerHint)
        }
        .onAppear {
            // Defer to the What's New sheet: only show once the user is past it.
            let whatsNewPending = WhatsNewGate.shouldShow(
                storedVersion: lastSeenWhatsNewVersion,
                currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                hasSeenOnboarding: hasSeenOnboarding)
            if !whatsNewPending && !coachStore.hasSeen(.iPadDividerResize) {
                showDividerHint = true
            }
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
        // List views need an enclosing NavigationStack for their titles/toolbars.
        // SettingsListView already wraps itself in one, and SearchView is a
        // self-contained ZStack — wrapping either would double the navigation bar
        // in the content column. (Account is reached via Settings → Account, so it
        // is not a top-level content destination here.)
        case .tab(let tab): NavigationStack { listView(for: tab) }
        // Search/Settings here are split-view columns, not sheets — suppress their
        // dismiss affordances (Cancel / Close), which would be dead chrome.
        case .search:       SearchView(showsCancel: false)
        case .settings:     SettingsListView(showsCloseButton: false)
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
            // back to a tab.
            model.destination = .tab(.feed)
            // Match iPhone's deep-link behavior (TabRootView.openItem): a comment
            // opens in a focused ThreadView with a swap to its parent story, while
            // a story opens straight into comments. `.thread` carries the comment
            // as `selectedStory`; DetailColumnView renders ThreadView for it.
            model.select(item, mode: item.type == .comment ? .thread : .comments)
        } catch {
            deepLinkError = true
        }
    }
}
