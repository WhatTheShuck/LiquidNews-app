// OfflineCacheSettingsView.swift
// "Offline & Cache" settings: storage usage, clear, size cap, the Frequent Flyer
// shortcut, background prefetch, and the entry point to "Prepare for offline".

import SwiftUI

struct OfflineCacheSettingsView: View {
    @State private var settings = UserSettings.shared
    @State private var usage: CacheUsage?
    @State private var showPrepareSheet = false

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    private func fmt(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var body: some View {
        SettingsDetailScaffold(title: "Offline & Cache") {

            // ── Storage ──
            VStack(spacing: 0) {
                usageRow(icon: "internaldrive", title: "Used",
                         value: usage.map { fmt($0.totalBytes) } ?? "—")
                rowDivider
                usageRow(icon: "doc.richtext", title: "Articles",
                         value: usage.map { fmt($0.articleBytes) } ?? "—")
                rowDivider
                usageRow(icon: "airplane", title: "Offline downloads",
                         value: usage.map { fmt($0.pinnedBytes) } ?? "—")
                rowDivider
                Button(role: .destructive) {
                    Task { await DiskCache.shared.clearUnpinned(); await refreshUsage() }
                } label: {
                    actionRow(icon: "trash", iconColor: .red.opacity(0.8),
                              title: "Clear Cache", titleColor: .red.opacity(0.8),
                              subtitle: "Removes everything except offline downloads")
                }
                .buttonStyle(.plain)
            }
            .glassCard()

            // ── Size limit ──
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    rowIcon("externaldrive")
                    rowText("Cache size limit",
                            "Oldest unpinned items are removed past this")
                    Spacer()
                    Picker("", selection: $settings.cacheSizeCapMB) {
                        Text("50 MB").tag(50)
                        Text("150 MB").tag(150)
                        Text("300 MB").tag(300)
                        Text("500 MB").tag(500)
                    }
                    .labelsHidden()
                    .tint(AppTheme.accent)
                }
                .padding(16)
            }
            .glassCard()

            // ── Shortcuts & prefetch ──
            VStack(spacing: 0) {
                toggleRow(icon: "airplane.circle", title: "Frequent Flyer",
                          subtitle: "Adds a one-tap download button to the feed toolbar",
                          isOn: $settings.frequentFlyerEnabled)
                rowDivider
                toggleRow(icon: "arrow.triangle.2.circlepath", title: "Background Feed Prefetch",
                          subtitle: "Keeps enabled feeds offline-ready over WiFi",
                          isOn: $settings.backgroundFeedPrefetch)
                if settings.backgroundFeedPrefetch {
                    rowDivider
                    toggleRow(icon: "doc.text", title: "Also Download Article Text",
                              subtitle: "Heavier — extracts article bodies too",
                              isOn: $settings.backgroundPrefetchArticles)
                }
            }
            .glassCard()

            // ── Prepare for offline ──
            VStack(spacing: 0) {
                Button {
                    showPrepareSheet = true
                } label: {
                    HStack(spacing: 12) {
                        rowIcon("square.and.arrow.down.on.square")
                        rowText("Prepare for Offline…",
                                "Pin selected feeds for a trip — never auto-removed")
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
        .sheet(isPresented: $showPrepareSheet) { PrepareForOfflineSheet() }
        .task { await refreshUsage() }
    }

    // MARK: - Row builders

    private var rowDivider: some View {
        Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)
    }

    private func rowIcon(_ systemName: String, color: Color = AppTheme.accent) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18))
            .foregroundStyle(color)
            .frame(width: 30)
    }

    private func rowText(_ title: String, _ subtitle: String, titleColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(titleColor)
            Text(subtitle)
                .font(.system(size: subtitleFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private func usageRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon)
            Text(title)
                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: rowFontSize, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func actionRow(icon: String, iconColor: Color, title: String,
                           titleColor: Color, subtitle: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, color: iconColor)
            rowText(title, subtitle, titleColor: titleColor)
            Spacer()
        }
        .padding(16)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon)
            rowText(title, subtitle)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(16)
    }

    private func refreshUsage() async {
        usage = await DiskCache.shared.usage()
    }
}
