// ContentView.swift
// Root view. Builds a selection-based TabView from whichever tabs the user has enabled,
// in the order the user has arranged them in Settings.
// Feed is always first and cannot be removed or reordered.
//
// Overflow handling:
//   When more than 4 optional tabs are enabled, the tab bar shows Feed + 3 optional +
//   a custom "More" tab.
//
//   When More is tapped, selection naturally moves to .more and stays there — we never
//   reset it, so the tab indicator doesn't bounce. The overlay and any overflow tab
//   content live entirely inside the More tab's own content view. Tapping a real tab
//   from the bar clears everything and switches normally.

import SwiftUI

// MARK: - Tab selection type

private enum TabSelection: Hashable {
    case tab(AppTab)
    case more
}

// MARK: - ContentView

struct ContentView: View {

    @State private var settings = UserSettings.shared
    @State private var deepLinkedStory: HNItem?
    @Environment(DeepLinkState.self) private var deepLink

    @State private var selection: TabSelection = .tab(.feed)
    /// The last real (non-More) tab the user was on — used to show contextual
    /// background content inside the More tab while the overlay is open.
    @State private var lastRealSelection: TabSelection = .tab(.feed)
    @State private var showingMore = false
    /// Overflow tab currently being shown inside the More tab's content area.
    @State private var activeOverflowTab: AppTab? = nil

    // MARK: - Derived tab collections

    private var allEnabledOptional: [AppTab] {
        settings.tabOrder.filter { settings.enabledOptionalTabs.contains($0) }
    }

    private var visibleOptionalTabs: [AppTab] {
        Array(allEnabledOptional.prefix(3))
    }

    private var hasOverflow: Bool { allEnabledOptional.count > 4 }

    private var overflowTabs: [AppTab] {
        guard hasOverflow else { return [] }
        return Array(allEnabledOptional.dropFirst(3))
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selection) {
            Tab(
                AppTab.feed.label,
                systemImage: AppTab.feed.systemImage,
                value: TabSelection.tab(.feed)
            ) {
                NavigationStack { StoriesListView() }
            }

            ForEach(visibleOptionalTabs) { tab in
                Tab(tab.label, systemImage: tab.systemImage, value: TabSelection.tab(tab)) {
                    tabContent(for: tab)
                }
            }

            if hasOverflow {
                Tab("More", systemImage: "ellipsis", value: TabSelection.more) {
                    moreTabContent
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            switch newValue {
            case .more:
                // Selection arrived at More — leave it there (no snap-back).
                // The overlay lives inside moreTabContent.
                withAnimation(.spring(duration: 0.32, bounce: 0.15)) {
                    showingMore = true
                }
            case .tab:
                // User switched to a real tab — clear overflow state.
                lastRealSelection = newValue
                withAnimation(.spring(duration: 0.28)) {
                    activeOverflowTab = nil
                    showingMore = false
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
        .onChange(of: allEnabledOptional) { _, all in
            if let active = activeOverflowTab, !all.contains(active) {
                activeOverflowTab = nil
            }
        }
    }

    // MARK: - More tab content

    /// The More tab hosts the glass overlay and any selected overflow tab content.
    /// The last real tab's view is rendered as a background so the user retains
    /// visual context while choosing from the overlay.
    private var moreTabContent: some View {
        ZStack {
            // Background: the real tab the user came from.
            if case .tab(let realTab) = lastRealSelection {
                tabContent(for: realTab)
            }

            // Selected overflow tab content — appears once the user picks one.
            // .id() forces a view identity reset each time the tab changes.
            if let overflowTab = activeOverflowTab {
                tabContent(for: overflowTab)
                    .id(overflowTab)
            }

            // Glass overlay with overflow tab buttons.
            if showingMore {
                overflowOverlay
            }
        }
        .background {
            MoreRetapDetector {
                withAnimation(.spring(duration: 0.32, bounce: 0.15)) {
                    showingMore = true
                }
            }
        }
    }

    // MARK: - Overflow overlay

    private var overflowOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .glassEffect(in: Rectangle())
                .overlay(AppTheme.backgroundGradient.opacity(0.55))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.28)) {
                        selection = lastRealSelection
                    }
                }

            VStack(alignment: .trailing, spacing: 12) {
                ForEach(Array(overflowTabs.reversed().enumerated()), id: \.element.id) { index, tab in
                    Button {
                        selectOverflow(tab)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 17, weight: .medium))
                            Text(tab.label)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .glassEffect(in: Capsule())
                    }
                    .transition(.offset(y: 16).combined(with: .opacity))
                    .animation(
                        .spring(duration: 0.35, bounce: 0.2).delay(Double(index) * 0.06),
                        value: showingMore
                    )
                }
            }
            .padding(.bottom, 16)
            .padding(.trailing, 20)
        }
        .transition(.opacity)
    }

    // MARK: - Tab management

    private func selectOverflow(_ tab: AppTab) {
        withAnimation(.spring(duration: 0.28)) {
            activeOverflowTab = tab
            showingMore = false
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

// MARK: - More tab re-tap detector

/// Invisible UIViewRepresentable placed as background of moreTabContent.
/// Walks the responder chain to find the UITabBarController and installs a
/// chaining delegate that fires `onRetap` when the More tab is tapped while
/// it is already selected.
private struct MoreRetapDetector: UIViewRepresentable {

    let onRetap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onRetap = onRetap
        // Install delegate after view is in the hierarchy.
        DispatchQueue.main.async {
            guard context.coordinator.tabBarController == nil,
                  let tbc = uiView.tabBarController else { return }
            context.coordinator.install(on: tbc)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onRetap: onRetap) }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITabBarControllerDelegate {

        var onRetap: () -> Void
        weak var tabBarController: UITabBarController?
        weak var previousDelegate: UITabBarControllerDelegate?

        init(onRetap: @escaping () -> Void) { self.onRetap = onRetap }

        func install(on tbc: UITabBarController) {
            tabBarController = tbc
            previousDelegate = tbc.delegate
            tbc.delegate = self
        }

        // Fires before the selection changes — if the VC is already selected,
        // it's a same-tab re-tap.
        func tabBarController(
            _ tabBarController: UITabBarController,
            shouldSelect viewController: UIViewController
        ) -> Bool {
            if viewController === tabBarController.selectedViewController {
                DispatchQueue.main.async { self.onRetap() }
            }
            return previousDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            didSelect viewController: UIViewController
        ) {
            previousDelegate?.tabBarController?(tabBarController, didSelect: viewController)
        }
    }
}

// MARK: - UIView responder-chain helper

private extension UIView {
    var tabBarController: UITabBarController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let tbc = r as? UITabBarController { return tbc }
            responder = r.next
        }
        return nil
    }
}

#Preview {
    ContentView()
}
