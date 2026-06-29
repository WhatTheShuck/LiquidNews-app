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
    @State private var resumeCoordinator = ResumeCoordinator()
    @State private var store = StoreService.shared
    @AppStorage("LN_hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("LN_lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @State private var showWhatsNew = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showThemeNudge = false
    @State private var showThemePaywall = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLink)
                .environment(resumeCoordinator)
                .background(AppIconSyncer())
                .onOpenURL { url in
                    guard let id = itemID(from: url) else { return }
                    // Durable signal so a real deep link suppresses the resume
                    // banner/auto-open this launch (the transient pendingItemID is
                    // nilled the instant it's consumed — see ResumeCoordinator).
                    resumeCoordinator.markDeepLinkConsumed()
                    deepLink.pendingItemID = id
                }
                .onContinueUserActivity(StoryActivity.activityType) { activity in
                    guard let id = StoryActivity.itemID(from: activity) else { return }
                    resumeCoordinator.markDeepLinkConsumed()
                    deepLink.pendingItemID = id
                }
                .task {
                    // Start the shared path monitor at launch (it begins observing in init).
                    _ = NetworkMonitor.shared
                    SavedPostsStore.shared.applyHiddenPostsExpiry(
                        UserSettings.shared.hiddenPostsExpiry
                    )
                    await BackgroundPrefetcher.runIfEnabled()
                    if WhatsNewGate.shouldShow(
                        storedVersion: lastSeenWhatsNewVersion,
                        currentVersion: currentAppVersion,
                        hasSeenOnboarding: hasSeenOnboarding
                    ) {
                        showWhatsNew = true
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await SavedPostsStore.shared.mergeFromiCloud() }
                        Task {
                            await store.updatePurchasedProducts()
                            enforceTrials()
                        }
                        Task { await BackgroundPrefetcher.runIfEnabled() }
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
                    set: { _ in
                        hasSeenOnboarding = true
                        lastSeenWhatsNewVersion = currentAppVersion
                    }
                )) {
                    OnboardingView {
                        hasSeenOnboarding = true
                        lastSeenWhatsNewVersion = currentAppVersion
                    }
                    .presentationCornerRadius(.glassCornerRadius)
                }
                .sheet(isPresented: Binding(
                    get: { showWhatsNew },
                    set: { newValue in
                        if !newValue { lastSeenWhatsNewVersion = currentAppVersion }
                        showWhatsNew = newValue
                    }
                )) {
                    WhatsNewView {
                        lastSeenWhatsNewVersion = currentAppVersion
                        showWhatsNew = false
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

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
