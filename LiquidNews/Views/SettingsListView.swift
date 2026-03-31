// SettingsListView.swift
// App settings presented as a sheet from the main toolbar.

import SwiftUI

struct SettingsListView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var settings = UserSettings.shared
    @State private var auth = HNAuthService.shared
    @State private var navigateToAccount = false
    @State private var showAddCuratedFeed = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    accountSection
                    navigationSection
                    curatedSection
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

    // MARK: - Curated section

    private var curatedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Curated Sources")

            VStack(spacing: 0) {
                // Built-in sources
                ForEach(Array(BuiltInCuratedSource.allCases.enumerated()), id: \.element.id) { index, source in
                    if index > 0 {
                        Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: source.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(source.name)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.enabledBuiltInCuratedSources.contains(source.rawValue) },
                            set: { enabled in
                                if enabled {
                                    settings.enabledBuiltInCuratedSources.insert(source.rawValue)
                                } else {
                                    settings.enabledBuiltInCuratedSources.remove(source.rawValue)
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                    .padding(16)
                }

                // User-added custom feeds
                ForEach($settings.customCuratedFeeds) { $feed in
                    Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(feed.urlString)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: $feed.isEnabled)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                        Button {
                            settings.customCuratedFeeds.removeAll { $0.id == feed.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }

                // Add custom feed button
                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                Button {
                    showAddCuratedFeed = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text("Add Custom Feed")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
        .sheet(isPresented: $showAddCuratedFeed) {
            AddCuratedFeedView { newFeed in
                settings.customCuratedFeeds.append(newFeed)
            }
        }
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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Comment rendering style
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: settings.commentRenderingStyle.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Comment rendering")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(settings.commentRenderingStyle.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 0) {
                        ForEach(CommentRenderMode.allCases, id: \.self) { mode in
                            Button {
                                settings.commentRenderingStyle = mode
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: mode.systemImage)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(mode.label)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    settings.commentRenderingStyle == mode
                                        ? AppTheme.accent.opacity(0.2)
                                        : Color.clear
                                )
                                .foregroundStyle(
                                    settings.commentRenderingStyle == mode
                                        ? AppTheme.accent
                                        : Color.secondary
                                )
                            }
                            .buttonStyle(.plain)

                            if mode != CommentRenderMode.allCases.last {
                                Divider()
                                    .frame(height: 32)
                                    .overlay(AppTheme.glassBorder)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
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

// MARK: - Add Curated Feed sheet

private struct AddCuratedFeedView: View {

    var onSave: (CustomCuratedFeed) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlString = ""
    @State private var showFormat = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        URL(string: urlString.trimmingCharacters(in: .whitespaces)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Input fields
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            fieldLabel("Feed name")
                            TextField("My Curated List", text: $name)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(16)
                        }
                        Divider().overlay(AppTheme.glassBorder).padding(.leading, 16)
                        VStack(alignment: .leading, spacing: 0) {
                            fieldLabel("JSON URL")
                            TextField("https://example.com/curated.json", text: $urlString)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.white)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(16)
                        }
                    }
                    .glassCard()

                    // JSON format disclosure
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showFormat.toggle() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 30)
                                Text("Expected JSON format")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: showFormat ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)

                        if showFormat {
                            Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(CuratedFeedFormat.exampleJSON)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                ForEach(CuratedFeedFormat.fieldDescriptions, id: \.field) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(item.field)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(AppTheme.accent)
                                            .frame(width: 44, alignment: .leading)
                                        Text(item.detail)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .glassCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Add Custom Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let feed = CustomCuratedFeed(
                            name: name.trimmingCharacters(in: .whitespaces),
                            urlString: urlString.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(feed)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }
}

#Preview("Add Feed") {
    AddCuratedFeedView { _ in }
}
