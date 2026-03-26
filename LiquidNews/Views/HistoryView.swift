// HistoryView.swift
// Placeholder for the History (recently viewed) section.

import SwiftUI

struct HistoryView: View {
    var body: some View {
        placeholderContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(AppTab.history.label)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var placeholderContent: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.history.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text(AppTab.history.label)
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .preferredColorScheme(.dark)
}
