// AboutSettingsView.swift
// External links, licenses, and the app version.

import SwiftUI

struct AboutSettingsView: View {

    @State private var showLicenses = false

    @ScaledMetric(relativeTo: .body) private var rowFontSize: CGFloat = 15

    var body: some View {
        SettingsDetailScaffold(title: "About") {
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: URL(string: "https://news.ycombinator.com")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "safari")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        Text("Open Hacker News")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
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
                            .foregroundStyle(.primary)
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
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .glassCard()
        }
        .sheet(isPresented: $showLicenses) {
            LicensesView()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { AboutSettingsView() }
}
