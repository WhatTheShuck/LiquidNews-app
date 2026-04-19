// EmptyStateView.swift
// Reusable centred placeholder shown when a tab's data source is empty.

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
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
        AppTheme.backgroundGradient.ignoresSafeArea()
        EmptyStateView(
            icon: "bookmark",
            title: "Nothing saved yet",
            message: "Open a story and use the bookmark action to save it for later."
        )
    }
    .preferredColorScheme(.dark)
}
