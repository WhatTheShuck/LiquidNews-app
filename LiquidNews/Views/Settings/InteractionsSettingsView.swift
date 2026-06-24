// InteractionsSettingsView.swift
// Tap and swipe actions for story cards.

import SwiftUI

struct InteractionsSettingsView: View {

    @State private var settings = UserSettings.shared

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        SettingsDetailScaffold(title: "Interactions") {
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
            .glassCard()
        }
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
                    .foregroundStyle(.primary)
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
}

#Preview {
    NavigationStack { InteractionsSettingsView() }
}
