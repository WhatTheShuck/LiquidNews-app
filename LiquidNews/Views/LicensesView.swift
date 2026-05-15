// LicensesView.swift
// Open source acknowledgements — required by the Apache 2.0 licence terms
// for any bundled third-party library.

import SwiftUI

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    ForEach(License.all) { license in
                        LicenseCard(license: license)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Open Source Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Card

private struct LicenseCard: View {
    let license: License
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(license.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(license.licenseName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                VStack(alignment: .leading, spacing: 10) {
                    if let copyright = license.copyright {
                        Text(copyright)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(license.licenseText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if let url = license.url {
                        Link("View source ↗", destination: url)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .glassCard()
    }
}

// MARK: - Model

private struct License: Identifiable {
    let id = UUID()
    let name: String
    let copyright: String?
    let licenseName: String
    let licenseText: String
    let url: URL?

    static let all: [License] = [readability]

    static let readability = License(
        name: "Readability.js",
        copyright: "Copyright (c) 2010 Arc90 Inc\nMaintained by Mozilla Foundation",
        licenseName: "Apache License 2.0",
        licenseText: """
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the
        License. You may obtain a copy of the License at

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing,
        software distributed under the License is distributed on an
        "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
        either express or implied. See the License for the specific
        language governing permissions and limitations under the License.
        """,
        url: URL(string: "https://github.com/mozilla/readability")
    )
}

// MARK: - Preview

#Preview {
    LicensesView()
}
