//
//  LiquidNewsApp.swift
//  LiquidNews
//

import SwiftUI

/// Shared state that carries a pending deep-linked story ID from the URL
/// handler down to ContentView, which fetches and presents it.
@Observable
class DeepLinkState {
    var pendingItemID: Int? = nil
}

@main
struct LiquidNewsApp: App {

    @State private var deepLink = DeepLinkState()
    @State private var store = StoreService.shared
    @AppStorage("LN_hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showThemeNudge = false
    @State private var showThemePaywall = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLink)
                .background(AppIconSyncer())
                .onOpenURL { url in
                    deepLink.pendingItemID = itemID(from: url)
                }
                .task {
                    SavedPostsStore.shared.applyHiddenPostsExpiry(
                        UserSettings.shared.hiddenPostsExpiry
                    )
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await SavedPostsStore.shared.mergeFromiCloud() }
                        Task {
                            await store.updatePurchasedProducts()
                            enforceTrials()
                        }
                    }
                }
                .alert("Trial Ended", isPresented: $showThemeNudge) {
                    Button("Unlock Themes") { showThemePaywall = true }
                    Button("Use Default", role: .destructive) {
                        UserSettings.shared.selectedAppTheme = .standard
                    }
                } message: {
                    Text("Your 7-day free trial has ended. Unlock Themes to keep using premium themes.")
                }
                .sheet(isPresented: $showThemePaywall) {
                    NavigationStack {
                        PremiumPaywallView(focused: StoreService.ProductID.themes)
                    }
                    .presentationCornerRadius(.glassCornerRadius)
                }
                .sheet(isPresented: .init(
                    get: { !hasSeenOnboarding },
                    set: { _ in hasSeenOnboarding = true }
                )) {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                    .presentationCornerRadius(.glassCornerRadius)
                }
        }
    }

    @MainActor
    private func enforceTrials() {
        let state = store.trialState
        guard state == .grace || state == .hardExpired else { return }

        if state == .hardExpired {
            // Force free state — no dialog, no bypass.
            if !store.isAccountUnlocked && HNAuthService.shared.isLoggedIn {
                HNAuthService.shared.logout()
            }
            if !store.isThemesUnlocked && UserSettings.shared.selectedAppTheme.isPremium {
                UserSettings.shared.selectedAppTheme = .standard
            }
        } else if state == .grace {
            // Nudge only — still allowed to use the app.
            if !store.isThemesUnlocked && UserSettings.shared.selectedAppTheme.isPremium {
                showThemeNudge = true
            }
        }
    }

    /// Extracts an HN item ID from either scheme:
    ///   liquidnews://item/42
    ///   liquidnews://story/42
    ///   https://news.ycombinator.com/item?id=42
    private func itemID(from url: URL) -> Int? {
        if url.scheme == "liquidnews",
           (url.host == "story" || url.host == "item"),
           let segment = url.pathComponents.dropFirst().first {
            return Int(segment)
        }
        if url.host?.hasSuffix("ycombinator.com") == true, url.path == "/item",
           let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "id" })?.value {
            return Int(value)
        }
        return nil
    }
}
