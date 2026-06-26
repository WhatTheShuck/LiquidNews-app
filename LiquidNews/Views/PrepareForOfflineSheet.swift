// PrepareForOfflineSheet.swift
// Pre-flight selection for "Prepare for offline": toggle enabled feeds, pick depth,
// remember the choice, then download with progress.

import SwiftUI

struct PrepareForOfflineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = UserSettings.shared
    @State private var coordinator = OfflineDownloadCoordinator.shared
    @State private var selected: Set<StoryCategory> = []
    @State private var depth: Int = 50

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    private var enabledFeeds: [StoryCategory] { settings.orderedEnabledCategories }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {

                    SettingsSectionHeader(title: "Feeds")
                        .padding(.top, -4)
                    VStack(spacing: 0) {
                        ForEach(Array(enabledFeeds.enumerated()), id: \.element) { index, category in
                            HStack(spacing: 12) {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 30)
                                Text(category.rawValue)
                                    .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { selected.contains(category) },
                                    set: { on in if on { selected.insert(category) } else { selected.remove(category) } }
                                ))
                                .labelsHidden()
                                .tint(AppTheme.accent)
                            }
                            .padding(16)
                            if index != enabledFeeds.count - 1 {
                                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
                            }
                        }
                    }
                    .glassCard()

                    SettingsSectionHeader(title: "Stories per feed")
                    VStack(spacing: 0) {
                        Picker("Depth", selection: $depth) {
                            Text("25").tag(25)
                            Text("50").tag(50)
                            Text("100").tag(100)
                        }
                        .pickerStyle(.segmented)
                        .padding(16)
                    }
                    .glassCard()

                    if let progress = coordinator.progress {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Downloading \(progress.done) / \(progress.total)…")
                                .font(.system(size: subtitleFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                                .tint(AppTheme.accent)
                        }
                        .padding(16)
                        .glassCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Prepare for Offline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { coordinator.cancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.isDownloading ? "Downloading…" : "Download") {
                        let plan = OfflinePlan(categories: Array(selected), depth: depth)
                        settings.offlineDownloadCategories = plan.categories  // remember
                        settings.offlineDownloadDepth = depth
                        Task { await coordinator.download(plan: plan); dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty || coordinator.isDownloading)
                }
            }
            .onAppear {
                // Pre-fill from the remembered selection, intersected with currently-enabled feeds.
                let remembered = Set(settings.offlineDownloadCategories)
                selected = remembered.isEmpty
                    ? Set(enabledFeeds)
                    : remembered.intersection(Set(enabledFeeds))
                depth = settings.offlineDownloadDepth
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(.glassCornerRadius)
    }
}
