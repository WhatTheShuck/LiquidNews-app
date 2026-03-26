// AccountView.swift
// Shows login form when logged out; account details + logout when logged in.

import SwiftUI

struct AccountView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var auth = HNAuthService.shared

    // Login form state
    @State private var usernameField = ""
    @State private var passwordField = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                if auth.isLoggedIn {
                    loggedInSection
                } else {
                    loginSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
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
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Link("View profile on HN",
                         destination: URL(string: "https://news.ycombinator.com/user?id=\(auth.username ?? "")")!)
                        .font(.system(size: 13))
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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Use your existing HN username and password.")
                    .font(.system(size: 13))
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
                    .padding(16)
                    .foregroundStyle(.white)

                Divider().overlay(AppTheme.glassBorder)

                SecureField("Password", text: $passwordField)
                    .textContentType(.password)
                    .padding(16)
                    .foregroundStyle(.white)
            }
            .glassCard()

            // Error banner
            if let error = loginError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
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
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.accent)
        }
    }

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
    .preferredColorScheme(.dark)
}
