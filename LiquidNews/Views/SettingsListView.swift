// SettingsListView.swift
// Settings hub: a short list of categories, each pushing its own detail page.
// Account is reached through here too (Settings → Account), so it is the single
// entry point behind the toolbar's settings cog.

import SwiftUI

struct SettingsListView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    // Custom environment values don't reliably survive a NavigationLink push, so the
    // pushed category pages can't read this from the environment themselves. Capture
    // it here (at the column root, where it IS present) and re-inject it into each
    // pushed destination so SettingsDetailScaffold can show its ✕ on iPad.
    @Environment(\.iPadNavModel) private var iPadNavModel

    /// True when presented as a sheet (iPhone) — shows a Close button. False when
    /// hosted as the iPad Settings tab, where there is nothing to dismiss.
    var showsCloseButton: Bool = true

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    @State private var auth = HNAuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    accountCard
                    categoriesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        NavigationLink {
            AccountView()
                .environment(\.iPadNavModel, iPadNavModel)
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName: auth.isLoggedIn
                        ? "person.crop.circle.fill" : "person.crop.circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.isLoggedIn ? (auth.username ?? "Account") : "Sign In")
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(
                        auth.isLoggedIn
                            ? "Tap to manage your account" : "Log in with your HN account"
                    )
                    .font(.system(size: subtitleFontSize))
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
        .glassCard()
    }

    // MARK: - Category list

    private var categoriesCard: some View {
        VStack(spacing: 0) {
            categoryRow(
                icon: "square.grid.2x2",
                title: "Navigation",
                subtitle: "Tab order and badges"
            ) { NavigationSettingsView() }

            divider

            categoryRow(
                icon: "newspaper",
                title: "Feeds & Sources",
                subtitle: "Categories, curated sources, loading"
            ) { FeedsSettingsView() }

            divider

            categoryRow(
                icon: "book",
                title: "Reading",
                subtitle: "How links and articles open"
            ) { ReadingSettingsView() }

            divider

            categoryRow(
                icon: "hand.tap",
                title: "Interactions",
                subtitle: "Tap and swipe actions"
            ) { InteractionsSettingsView() }

            divider

            categoryRow(
                icon: "paintbrush",
                title: "Appearance",
                subtitle: "Theme, colour, and app icon"
            ) { AppearanceSettingsView() }

            divider

            categoryRow(
                icon: "lock.shield",
                title: "Data & Privacy",
                subtitle: "Hidden posts, history, import/export"
            ) { DataPrivacySettingsView() }

            divider

            categoryRow(
                icon: "info.circle",
                title: "About",
                subtitle: "Links, licenses, and version"
            ) { AboutSettingsView() }
        }
        .glassCard()
    }

    private var divider: some View {
        Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
    }

    @ViewBuilder
    private func categoryRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
                .environment(\.iPadNavModel, iPadNavModel)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SettingsListView()
}
