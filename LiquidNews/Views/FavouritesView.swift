// FavouritesView.swift
// Placeholder for the Favourites section.

import SwiftUI

struct FavouritesView: View {
    var body: some View {
        placeholderContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(AppTab.favourites.label)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.favourites.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(AppTab.favourites.label)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { FavouritesView() }
        .preferredColorScheme(.dark)
}
