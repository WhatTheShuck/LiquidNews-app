// SettingsListView.swift
// App settings presented as a sheet from the main toolbar.

import SwiftUI

struct SettingsListView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var settings = UserSettings.shared
    @State private var auth = HNAuthService.shared
    @State private var navigateToAccount = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    accountSection
                    navigationSection
                    feedSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToAccount) {
                AccountView()
            }
        }
    }

    // MARK: - Account section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Account")
            Button {
                navigateToAccount = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: auth.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.isLoggedIn ? (auth.username ?? "Account") : "Sign In")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text(auth.isLoggedIn ? "Tap to manage your account" : "Log in with your HN account")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
        .glassCard()
    }

    // MARK: - Navigation section

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Navigation")

            VStack(spacing: 0) {
                ForEach(Array(AppTab.optional.enumerated()), id: \.element.id) { index, tab in
                    if index > 0 {
                        Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(tab.label)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.enabledOptionalTabs.contains(tab) },
                            set: { enabled in
                                if enabled {
                                    settings.enabledOptionalTabs.insert(tab)
                                } else {
                                    settings.enabledOptionalTabs.remove(tab)
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                    .padding(16)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Feed section

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Feed")

            // Auto-load reply count
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    Text("Auto-load replies")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(settings.autoLoadReplyCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.autoLoadReplyCount, in: 0...10)
                        .labelsHidden()
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Max auto-expand depth
                HStack {
                    Image(systemName: "list.indent")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max auto-expand depth")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Replies deeper than this require a tap")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.maxAutoExpandDepth)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.maxAutoExpandDepth, in: 0...5)
                        .labelsHidden()
                }
                .padding(16)
            }
        }
        .glassCard()
    }

    // MARK: - About section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("About")

            Link(destination: URL(string: "https://news.ycombinator.com")!) {
                HStack(spacing: 12) {
                    Image(systemName: "safari")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    Text("Open Hacker News")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }

            Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30)
                Text("LiquidNews")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .glassCard()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsListView()
        .preferredColorScheme(.dark)
}
