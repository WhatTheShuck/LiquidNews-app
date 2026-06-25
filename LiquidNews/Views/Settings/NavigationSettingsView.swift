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

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Resume last story (read only at launch)
                HStack(spacing: 12) {
                    Image(systemName: settings.resumeMode.systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resume Last Story")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(settings.resumeMode.subtitle)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                resumeModePicker
            }
            .glassCard()
        }
    }

    /// Segmented row of icon+label buttons for the resume mode, matching the
    /// app's settings style (same look as ReadingSettingsView's picker).
    private var resumeModePicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(ResumeMode.allCases.enumerated()), id: \.offset) { index, mode in
                Button {
                    settings.resumeMode = mode
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
                        settings.resumeMode == mode ? AppTheme.accent.opacity(0.2) : Color.clear
                    )
                    .foregroundStyle(
                        settings.resumeMode == mode ? AppTheme.accent : Color.secondary
                    )
                }
                .buttonStyle(.plain)

                if index != ResumeMode.allCases.count - 1 {
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

#Preview {
    NavigationStack { NavigationSettingsView() }
}
