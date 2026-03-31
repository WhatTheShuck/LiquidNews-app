// CuratedView.swift
// Placeholder for the Curated section.

import SwiftUI

struct CuratedView: View {
    var body: some View {
        placeholderContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(AppTab.curated.label)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.curated.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(AppTab.curated.label)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { CuratedView() }
        .preferredColorScheme(.dark)
}
