// SavedView.swift
// Placeholder for the Saved (read-later) section.

import SwiftUI

struct SavedView: View {
    var body: some View {
        placeholderContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(AppTab.saved.label)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.saved.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(AppTab.saved.label)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { SavedView() }
        .preferredColorScheme(.dark)
}
