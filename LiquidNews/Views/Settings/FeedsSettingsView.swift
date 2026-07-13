// FeedsSettingsView.swift
// Feed categories, curated sources, and feed/comment loading behaviour.

import SwiftUI

struct FeedsSettingsView: View {

    @State private var settings = UserSettings.shared
    @State private var showAddCuratedFeed = false

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        SettingsDetailScaffold(title: "Feeds & Sources") {
            feedCategoriesCard
            curatedCard
            feedCard
        }
        .sheet(isPresented: $showAddCuratedFeed) {
            AddCuratedFeedView { newFeed in
                settings.customCuratedFeeds.append(newFeed)
            }
        }
    }

    // MARK: - Feed categories

    private var feedCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Feed Categories")

            List {
                ForEach(settings.feedCategoryOrder) { category in
                    HStack(spacing: 12) {
                        Image(systemName: feedCategoryIcon(for: category))
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(category.rawValue)
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.enabledFeedCategories.contains(category) },
                                set: { enabled in
                                    if enabled {
                                        settings.enabledFeedCategories.insert(category)
                                    } else if settings.enabledFeedCategories.count > 1 {
                                        // Always keep at least one enabled
                                        settings.enabledFeedCategories.remove(category)
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(AppTheme.glassBorder)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onMove { from, to in
                    settings.feedCategoryOrder.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(.active))
            .frame(height: CGFloat(settings.feedCategoryOrder.count) * 54)

            Text(
                "The first 5 enabled categories appear as chips. Additional enabled categories are available via the last chip."
            )
            .font(.system(size: subtitleFontSize))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .glassCard()
    }

    private func feedCategoryIcon(for category: StoryCategory) -> String {
        switch category {
        case .top: "flame"
        case .new: "sparkles"
        case .best: "star"
        case .ask: "questionmark.bubble"
        case .show: "eye"
        case .jobs: "briefcase"
        case .classic: "clock.arrow.circlepath"
        case .active: "bubble.left.and.bubble.right"
        case .shownew: "hourglass.badge.eye"
        case .asknew: "questionmark.bubble.fill"
        case .noob: "person.badge.plus"
        case .launches: "airplane.up.right"
        case .pool: "person.2"
        }
    }

    // MARK: - Curated sources

    private var curatedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Curated Sources")

            VStack(spacing: 0) {
                // Built-in sources
                ForEach(Array(BuiltInCuratedSource.allCases.enumerated()), id: \.element.id) {
                    index, source in
                    if index > 0 {
                        Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: source.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(source.name)
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: {
                                    settings.enabledBuiltInCuratedSources.contains(source.rawValue)
                                },
                                set: { enabled in
                                    if enabled {
                                        settings.enabledBuiltInCuratedSources.insert(
                                            source.rawValue)
                                    } else {
                                        settings.enabledBuiltInCuratedSources.remove(
                                            source.rawValue)
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                        .tint(AppTheme.accent)
                    }
                    .padding(16)
                }

                // User-added custom feeds
                ForEach(settings.customCuratedFeeds) { feed in
                    Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.name)
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(feed.urlString)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { feed.isEnabled },
                            set: { enabled in
                                if let idx = settings.customCuratedFeeds.firstIndex(where: { $0.id == feed.id }) {
                                    settings.customCuratedFeeds[idx].isEnabled = enabled
                                }
                            }
                        ))
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
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                // Loading notice toggle
                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show loading notice")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Banner warning that newsletter parsing may take a moment")
                            .font(.system(size: subtitleFontSize, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { !settings.hideCuratedLoadingBanner },
                            set: { settings.hideCuratedLoadingBanner = !$0 }
                        )
                    )
                    .labelsHidden()
                    .tint(AppTheme.accent)
                }
                .padding(16)

                // Hacker Newsletter attribution
                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                Link(destination: URL(string: "https://www.hackernewsletter.com")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Powered by Hacker Newsletter")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("The best of HN, curated weekly. Consider sponsoring or donating to support their work.")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Feed

    private var feedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Feed")

            // Auto-load reply count
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    Text("Auto-load replies")
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(settings.autoLoadReplyCount)")
                        .font(.system(size: rowFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.autoLoadReplyCount, in: 0...10)
                        .labelsHidden()
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Max auto-expand depth
                HStack {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max auto-expand depth")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Replies deeper than this require a tap")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.maxAutoExpandDepth)")
                        .font(.system(size: rowFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.maxAutoExpandDepth, in: 0...5)
                        .labelsHidden()
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Concurrent fetch limit — WiFi
                HStack {
                    Image(systemName: "wifi")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parallel loads (WiFi)")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Higher = faster threads, more bandwidth")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.maxConcurrentFetchesWifi)")
                        .font(.system(size: rowFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.maxConcurrentFetchesWifi, in: 1...20)
                        .labelsHidden()
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Concurrent fetch limit — Cellular
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parallel loads (Cellular)")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Lower = less data usage on slow connections")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.maxConcurrentFetchesCellular)")
                        .font(.system(size: rowFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper("", value: $settings.maxConcurrentFetchesCellular, in: 1...20)
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
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(settings.commentRenderingStyle.subtitle)
                                .font(.system(size: subtitleFontSize))
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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Code block line wrapping
                HStack(spacing: 12) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wrap code block lines")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Wrap long lines instead of scrolling horizontally")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.codeWrapLines)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Glass comment cards
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Glass comments")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Liquid Glass comment cards. May cause visual artifacts, glitches, or slow scrolling on busy threads.")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.glassComments)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)
            }
        }
        .glassCard()
    }
}

#Preview {
    NavigationStack { FeedsSettingsView() }
}

// MARK: - Add Curated Feed sheet

private struct AddCuratedFeedView: View {

    var onSave: (CustomCuratedFeed) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var urlString = ""
    @State private var showFormat = false

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // Require a real http(s) URL with a host — `URL(string:)` alone accepts
        // schemeless junk like "example", which would become a silently-broken feed.
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else { return false }
        return true
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
                                .foregroundStyle(.primary)
                                .padding(16)
                        }
                        Divider().overlay(AppTheme.glassBorder).padding(.leading, 16)
                        VStack(alignment: .leading, spacing: 0) {
                            fieldLabel("JSON URL")
                            TextField("https://example.com/curated.json", text: $urlString)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.primary)
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
                                    .foregroundStyle(.primary)
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
                                            .font(
                                                .system(
                                                    size: 12, weight: .semibold, design: .monospaced
                                                )
                                            )
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
            .background(ThemeBackground().ignoresSafeArea())
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
