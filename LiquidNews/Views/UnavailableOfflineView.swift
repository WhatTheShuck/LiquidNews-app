// UnavailableOfflineView.swift
// Shown when the user opens content that isn't cached while offline.

import SwiftUI

struct UnavailableOfflineView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeBackground().ignoresSafeArea()
            EmptyStateView(
                icon: "wifi.slash",
                title: "Not Available Offline",
                message: "This hasn't been downloaded yet. Try again when you're connected."
            )
        }
    }
}
