// CatchUpView.swift
// Placeholder for the Catch-up section.

import SwiftUI

struct CatchUpView: View {
    var body: some View {
        placeholderContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(AppTab.catchUp.label)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.catchUp.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(AppTab.catchUp.label)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { CatchUpView() }
        .preferredColorScheme(.dark)
}
