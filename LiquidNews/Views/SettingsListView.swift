// SettingsListView.swift
// App settings presented as a sheet from the main toolbar.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsListView: View {

    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    @State private var settings = UserSettings.shared
    @State private var auth = HNAuthService.shared
    @State private var navigateToAccount = false
    @State private var showAddCuratedFeed = false
    @State private var showLicenses = false

    // Data & Privacy state
    private let store = SavedPostsStore.shared
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingExportOptions = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var showingImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var showingClearHistoryConfirm = false
    @State private var navigateToHiddenPosts = false
    @State private var selectedIconName: String? = UIApplication.shared.alternateIconName

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    accountSection
                    navigationSection
                    feedCategoriesSection
                    curatedSection
                    feedSection
                    readingSection
                    swipeActionsSection
                    dataPrivacySection
                    appearanceSection
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
            .navigationDestination(isPresented: $navigateToHiddenPosts) {
                HiddenPostsView()
            }
        }
        // Export share sheet
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        // Import file picker
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            // Coordinate access — file may be outside sandbox
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                importError = "Could not read the selected file."
                showingImportError = true
                return
            }
            pendingImportData = data
            showingImportConfirm = true
        }
        .confirmationDialog(
            "Import Data",
            isPresented: $showingImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Merge with existing data") {
                if let data = pendingImportData {
                    try? store.importData(data, replacing: false)
                }
            }
            Button("Replace all data", role: .destructive) {
                if let data = pendingImportData {
                    try? store.importData(data, replacing: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Merge keeps your existing favourites, saved posts, and history. Replace will overwrite everything with the imported data."
            )
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error.")
        }
        .confirmationDialog(
            "Clear all read history?",
            isPresented: $showingClearHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
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
                            .foregroundStyle(.white)
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
        }
        .glassCard()
    }

    // MARK: - Navigation section

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Navigation")

            // Always-on edit mode so drag handles are visible without a separate Edit button.
            List {
                ForEach(settings.tabOrder) { tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(tab.label)
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.enabledOptionalTabs.contains(tab) },
                                set: { enabled in
                                    if enabled {
                                        settings.enabledOptionalTabs.insert(tab)
                                    } else {
                                        settings.enabledOptionalTabs.remove(tab)
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
                    settings.tabOrder.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(.active))
            // Fixed height: 5 tabs × ~54 pt per row
            .frame(height: CGFloat(settings.tabOrder.count) * 54)
        }
        .glassCard()
    }

    // MARK: - Feed categories section

    private var feedCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Feed Categories")

            List {
                ForEach(settings.feedCategoryOrder) { category in
                    HStack(spacing: 12) {
                        Image(systemName: feedCategoryIcon(for: category))
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text(category.rawValue)
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
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

    // MARK: - Curated section

    private var curatedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Curated Sources")

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
                            .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
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
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
            }
        }
        .glassCard()
    }

    // MARK: - Reading section

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Reading")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: settings.defaultLinkOpen.systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default open mode")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text(settings.defaultLinkOpen.subtitle)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                HStack(spacing: 0) {
                    ForEach(LinkOpenMode.allCases) { mode in
                        Button {
                            settings.defaultLinkOpen = mode
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
                                settings.defaultLinkOpen == mode
                                    ? AppTheme.accent.opacity(0.2)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                settings.defaultLinkOpen == mode
                                    ? AppTheme.accent
                                    : Color.secondary
                            )
                        }
                        .buttonStyle(.plain)

                        if mode != LinkOpenMode.allCases.last {
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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Reader images default
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show images in Reader")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Fetch and display images when opening articles in Reader mode")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.readerShowImagesByDefault)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)
            }
        }
        .glassCard()
    }

    // MARK: - Swipe actions section

    private var swipeActionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Interactions")

            VStack(spacing: 0) {
                actionPickerRow(
                    title: "Tap",
                    subtitle: "What happens when you tap a story card",
                    systemImage: "hand.tap",
                    selection: $settings.tapAction,
                    options: StoryAction.tapOptions
                )

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                actionPickerRow(
                    title: "Swipe Left",
                    subtitle: "Action when swiping a story card left",
                    systemImage: "arrow.left",
                    selection: $settings.swipeLeftAction,
                    options: StoryAction.allCases
                )

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                actionPickerRow(
                    title: "Swipe Right",
                    subtitle: "Action when swiping a story card right",
                    systemImage: "arrow.right",
                    selection: $settings.swipeRightAction,
                    options: StoryAction.allCases
                )
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private func actionPickerRow(
        title: String,
        subtitle: String,
        systemImage: String,
        selection: Binding<StoryAction>,
        options: [StoryAction]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: selection) {
                    ForEach(options) { action in
                        Text(action.label).tag(action)
                    }
                }
                .labelsHidden()
                .tint(AppTheme.accent)
                .fixedSize()
            }
            Text(subtitle)
                .font(.system(size: subtitleFontSize))
                .foregroundStyle(.secondary)
                .padding(.leading, 42)
        }
        .padding(16)
    }

    // MARK: - Data & Privacy section

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Data & Privacy")

            VStack(spacing: 0) {

                // Hidden posts
                Button {
                    navigateToHiddenPosts = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hidden Posts")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(store.hiddenPosts.count) hidden")
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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Hidden posts auto-expiry
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-clear hidden posts")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Text("HN posts age quickly — auto-expiry keeps the list lean")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.hiddenPostsExpiry) {
                        ForEach(HiddenPostsExpiry.allCases) { expiry in
                            Text(expiry.label).tag(expiry)
                        }
                    }
                    .labelsHidden()
                    .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Viewed post behaviour
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: settings.readBehaviour.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("When you view a post")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(settings.readBehaviour.subtitle)
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 0) {
                        ForEach(ReadBehaviour.allCases) { behaviour in
                            Button {
                                settings.readBehaviour = behaviour
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: behaviour.systemImage)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(behaviour.label)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    settings.readBehaviour == behaviour
                                        ? AppTheme.accent.opacity(0.2)
                                        : Color.clear
                                )
                                .foregroundStyle(
                                    settings.readBehaviour == behaviour
                                        ? AppTheme.accent
                                        : Color.secondary
                                )
                            }
                            .buttonStyle(.plain)

                            if behaviour != ReadBehaviour.allCases.last {
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

                // Note: Hide mode never auto-hides favourited or saved posts
                if settings.readBehaviour == .hide {
                    Text("Favourited and saved posts are never auto-hidden.")
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Clear read history
                Button(role: .destructive) {
                    showingClearHistoryConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Read History")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.red.opacity(0.8))
                            Text("\(store.readHistory.count) entries")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Export
                Button {
                    showingExportOptions = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Data")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Share favourites, saved posts, history, or everything")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Export Data", isPresented: $showingExportOptions, titleVisibility: .visible
                ) {
                    Button("All Data — JSON file") {
                        triggerExport(data: try? store.exportData(), name: "liquidnews-all")
                    }
                    Button("Favourites — Copy \(store.favouriteIDs.count) IDs to clipboard") {
                        UIPasteboard.general.string = store.favouriteIDs.sorted()
                            .map(String.init).joined(separator: "\n")
                    }
                    Button("Favourites — JSON file") {
                        triggerExport(
                            data: try? store.exportFavourites(), name: "liquidnews-favourites")
                    }
                    Button("Saved — Copy \(store.savedIDs.count) IDs to clipboard") {
                        UIPasteboard.general.string = store.savedIDs.sorted()
                            .map(String.init).joined(separator: "\n")
                    }
                    Button("Saved — JSON file") {
                        triggerExport(data: try? store.exportSaved(), name: "liquidnews-saved")
                    }
                    Button("Read History — JSON file") {
                        triggerExport(data: try? store.exportHistory(), name: "liquidnews-history")
                    }
                    Button("Hidden Posts — JSON file") {
                        triggerExport(data: try? store.exportHidden(), name: "liquidnews-hidden")
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("IDs are copied one per line. JSON files can be re-imported later.")
                }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Import
                Button {
                    showingImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Data")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Restore from a previous export")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
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
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }

            Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

            Button {
                showLicenses = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    Text("Open Source Licenses")
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30)
                Text("LiquidNews")
                    .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .glassCard()
        .sheet(isPresented: $showLicenses) {
            LicensesView()
        }
    }

    // MARK: - Appearance section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Appearance")

            HStack(spacing: 12) {
                Image(systemName: "app.badge")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30)
                Text("App Icon")
                    .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            HStack(spacing: 24) {
                iconChoice(label: "Droplet", iconName: nil) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }
                iconChoice(label: "Letter", iconName: "AppIcon-L") {
                    Text("L")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .glassCard()
    }

    @ViewBuilder
    private func iconChoice<Symbol: View>(
        label: String,
        iconName: String?,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        let isSelected = selectedIconName == iconName
        Button {
            UIApplication.shared.setAlternateIconName(iconName) { _ in
                selectedIconName = UIApplication.shared.alternateIconName
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.19),
                                Color(red: 0.91, green: 0.33, blue: 0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    symbol()
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? AppTheme.accent : Color.white.opacity(0.12),
                            lineWidth: isSelected ? 3 : 1
                        )
                )

                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export helper

    private func triggerExport(data: Data?, name: String) {
        guard let data else {
            importError = "Failed to prepare export data."
            showingImportError = true
            return
        }
        let dateTag = Date().formatted(.iso8601.year().month().day())
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(dateTag).json")
        do {
            try data.write(to: tmp, options: .atomic)
            exportURL = tmp
            showingExportSheet = true
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: urlString.trimmingCharacters(in: .whitespaces)) != nil
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
