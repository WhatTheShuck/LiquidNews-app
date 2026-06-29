// AccountView.swift
// Shows login form when logged out; account details + logout when logged in.

import SwiftUI

struct AccountView: View {

    @ScaledMetric(relativeTo: .title3)    private var usernameFontSize: CGFloat = 18
    @ScaledMetric(relativeTo: .title2)    private var headerFontSize:   CGFloat = 20
    @ScaledMetric(relativeTo: .body)      private var buttonFontSize:   CGFloat = 16
    @ScaledMetric(relativeTo: .footnote)  private var linkFontSize:     CGFloat = 13

    @Environment(\.colorScheme) private var colorScheme
    @State private var auth = HNAuthService.shared
    @State private var store = StoreService.shared
    @State private var showPaywall = false
    @State private var showTrialStart = false
    @State private var showTrialExpiredNudge = false
    #if DEBUG
    @State private var savedPosts = SavedPostsStore.shared
    @State private var showWipeiCloudConfirm = false
    @State private var wipeResultMessage: String?
    @State private var showWipeResult = false
    @State private var showTutorialClearedConfirm = false
    @AppStorage("LN_lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    #endif
    @FocusState private var focusedField: LoginField?

    // Login form state
    @State private var usernameField = ""
    @State private var passwordField = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?

    private enum LoginField { case username, password }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                switch store.trialState {
                case .notStarted where !store.isAccountUnlocked:
                    trialNotStartedSection
                case .hardExpired where !store.isAccountUnlocked:
                    trialExpiredSection
                default:
                    if auth.isLoggedIn {
                        loggedInSection
                    } else {
                        loginSection
                    }
                    if store.isInAccountTrial {
                        trialBanner
                    } else if store.trialState == .grace && !store.isAccountUnlocked {
                        graceBanner
                    }
                }
                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task {
            if store.trialState == .grace && !store.isAccountUnlocked && auth.isLoggedIn {
                showTrialExpiredNudge = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PremiumPaywallView(focused: StoreService.ProductID.account)
            }
            .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(isPresented: $showTrialStart) {
            NavigationStack {
                TrialStartSheet { store.startTrialIfNeeded() }
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(.glassCornerRadius)
        }
        .alert("Trial Ended", isPresented: $showTrialExpiredNudge) {
            Button("Unlock Account") { showPaywall = true }
            Button("Sign Out", role: .destructive) { auth.logout() }
        } message: {
            Text("Your 7-day free trial has ended. Unlock Account to stay signed in.")
        }
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Logged-in state

    private var loggedInSection: some View {
        VStack(spacing: 0) {
            // Avatar row
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.username ?? "")
                        .font(.system(size: usernameFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Link("View profile on HN",
                         destination: URL(string: "https://news.ycombinator.com/user?id=\(auth.username ?? "")")!)
                        .font(.system(size: linkFontSize))
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer()
            }
            .padding(18)

            Divider().overlay(AppTheme.glassBorder)

            Button(role: .destructive) {
                auth.logout()
            } label: {
                HStack {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(18)
            }
            .buttonStyle(.plain)
        }
        .glassCard()
    }

    // MARK: - Login form

    private var loginSection: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                Text("Sign in to Hacker News")
                    .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Use your existing HN username and password.")
                    .font(.system(size: linkFontSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Fields
            VStack(spacing: 0) {
                TextField("Username", text: $usernameField)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                    .padding(16)
                    .foregroundStyle(.primary)

                Divider().overlay(AppTheme.glassBorder)

                SecureField("Password", text: $passwordField)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit { Task { await attemptLogin() } }
                    .padding(16)
                    .foregroundStyle(.primary)
            }
            .glassCard()

            // Error banner
            if let error = loginError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: linkFontSize))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(14)
                .glassCard(tint: .red)
            }

            // Login button
            Button {
                Task { await attemptLogin() }
            } label: {
                HStack {
                    Spacer()
                    if isLoggingIn {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.system(size: buttonFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .glassEffect(in: RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.25))
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .disabled(usernameField.isEmpty || passwordField.isEmpty || isLoggingIn)

            Link("Create an account on HN",
                 destination: URL(string: "https://news.ycombinator.com/login?goto=news")!)
                .font(.system(size: linkFontSize))
                .foregroundStyle(AppTheme.accent)
        }
    }

    // MARK: - Trial banner

    private var trialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .foregroundStyle(AppTheme.accent)
            Text("\(store.trialDaysRemaining) day\(store.trialDaysRemaining == 1 ? "" : "s") left in your free trial.")
                .font(.system(size: linkFontSize))
                .foregroundStyle(.primary)
            Spacer()
            Button("Unlock") { showPaywall = true }
                .font(.system(size: linkFontSize, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(14)
        .glassCard(tint: AppTheme.accent)
    }

    // MARK: - Grace banner

    private var graceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(store.graceDaysRemaining) day\(store.graceDaysRemaining == 1 ? "" : "s") left before access is removed.")
                .font(.system(size: linkFontSize))
                .foregroundStyle(.primary)
            Spacer()
            Button("Unlock") { showPaywall = true }
                .font(.system(size: linkFontSize, weight: .semibold))
                .foregroundStyle(.orange)
        }
        .padding(14)
        .glassCard(tint: .orange)
    }

    // MARK: - Trial not started

    private var trialNotStartedSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                Text("Sign in to Hacker News")
                    .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Vote, reply, and flag. Try Account and Themes free for 7 days.")
                    .font(.system(size: linkFontSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            Button {
                showTrialStart = true
            } label: {
                HStack {
                    Spacer()
                    Text("Start 7-Day Free Trial")
                        .font(.system(size: buttonFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.vertical, 16)
                .glassEffect(in: RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.25))
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)

            Button { showPaywall = true } label: {
                Text("Unlock now")
                    .font(.system(size: linkFontSize))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Trial expired

    private var trialExpiredSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                Text("Trial Ended")
                    .font(.system(size: headerFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Your 7-day free trial has ended. Unlock Account to continue.")
                    .font(.system(size: linkFontSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Spacer()
                    Text("Unlock Account")
                        .font(.system(size: buttonFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.vertical, 16)
                .glassEffect(in: RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.25))
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Debug controls (DEBUG builds only)

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Trial Debug")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Button("Start Fresh Trial") { store.debugStartFreshTrial() }
                    .padding(14)
                Divider().overlay(AppTheme.glassBorder)
                Button("Grace Period (−8 days)") { store.debugExpireTrial() }
                    .padding(14)
                Divider().overlay(AppTheme.glassBorder)
                Button("Hard Expired (−11 days)") { store.debugHardExpireTrial() }
                    .padding(14)
                Divider().overlay(AppTheme.glassBorder)
                Button("Reset Trial (not started)") { store.debugResetTrial() }
                    .padding(14)
                Divider().overlay(AppTheme.glassBorder)
                Button("Clear Tutorial (Coach Marks + What's New)") {
                    CoachMarkStore.shared.replayAll()
                    lastSeenWhatsNewVersion = ""
                    showTutorialClearedConfirm = true
                }
                .padding(14)
                Divider().overlay(AppTheme.glassBorder)
                Button(role: .destructive) {
                    showWipeiCloudConfirm = true
                } label: {
                    Text("Wipe iCloud + Local Storage")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .foregroundStyle(.red)
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(AppTheme.accent)
            .glassCard()
        }
        .confirmationDialog(
            "Wipe all storage?",
            isPresented: $showWipeiCloudConfirm,
            titleVisibility: .visible
        ) {
            Button("Wipe Everything", role: .destructive) {
                wipeResultMessage = savedPosts.debugWipeAllStorage()
                showWipeResult = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears the iCloud key-value store, the iCloud sync file, and all local favourites / read-later / history / settings. Use this to recover the cooked dev→Store account. Relaunch afterwards.")
        }
        .alert("Storage Wiped", isPresented: $showWipeResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(wipeResultMessage ?? "")
        }
        .alert("Tutorial Cleared", isPresented: $showTutorialClearedConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coach marks and the What's New gate have been reset. What's New shows on next launch; coach marks reappear as you revisit each screen.")
        }
    }
    #endif

    // MARK: - Login action

    private func attemptLogin() async {
        loginError = nil
        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            try await auth.login(username: usernameField, password: passwordField)
            passwordField = ""
        } catch {
            loginError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview("Logged out") {
    NavigationStack {
        AccountView()
    }
}
