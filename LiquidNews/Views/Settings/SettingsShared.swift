// SettingsShared.swift
// Shared building blocks for the settings hub and its detail pages.

import SwiftUI

/// A choice that can be shown in the settings segmented picker — needs a short
/// label and an SF Symbol. The mode enums in `UserSettings` already provide both.
protocol SettingsSegmentOption {
    var label: String { get }
    var systemImage: String { get }
}

extension LinkOpenMode: SettingsSegmentOption {}
extension CommentLinkMode: SettingsSegmentOption {}
extension ReaderLinkMode: SettingsSegmentOption {}
extension HNLinkMode: SettingsSegmentOption {}
extension ResumeMode: SettingsSegmentOption {}

/// Uppercased caption header used at the top of a settings card.
/// Detail pages with a single card rely on the navigation title instead and
/// omit this; pages that stack multiple cards use it to label each one.
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }
}

/// Standard chrome shared by every settings detail page: a scrolling stack of
/// glass cards over the app background gradient, with an inline title.
struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    // Non-nil only inside the iPad/Mac split view. There, settings is a persistent
    // column rather than a pushed sheet, so the leading chevron reads oddly — swap it
    // for an explicit ✕ that pops the category back to the settings list.
    @Environment(\.iPadNavModel) private var iPadNavModel

    private var isSplitColumn: Bool { iPadNavModel != nil }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(ThemeBackground().ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // On iPad, replace the system back chevron with a ✕ that clears the category
        // (dismiss() pops this page off the settings column's NavigationStack, back to
        // the list). On iPhone the category is a push, so keep the native back arrow.
        .navigationBarBackButtonHidden(isSplitColumn)
        .toolbar {
            if isSplitColumn {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}
