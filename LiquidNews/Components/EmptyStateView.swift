// EmptyStateView.swift
// Reusable centred placeholder shown when a tab's data source is empty.

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.primary)
            Text(message)
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        ThemeBackground(colorScheme: .dark).ignoresSafeArea()
        EmptyStateView(
            icon: "bookmark",
            title: "You're all caught up",
            message: "Bookmark a story to save it for later."
        )
    }
}
