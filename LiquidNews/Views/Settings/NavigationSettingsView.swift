// NavigationSettingsView.swift
// Tab order, optional tabs, and the Read Later badge.

import SwiftUI

struct NavigationSettingsView: View {

    @State private var settings = UserSettings.shared

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        SettingsDetailScaffold(title: "Navigation") {
            VStack(alignment: .leading, spacing: 0) {
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
                                .foregroundStyle(.primary)
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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                HStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read Later Badge")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Show a count badge on the Read Later tab")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.showReadLaterBadge)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)
            }
            .glassCard()
        }
    }
}

#Preview {
    NavigationStack { NavigationSettingsView() }
}
