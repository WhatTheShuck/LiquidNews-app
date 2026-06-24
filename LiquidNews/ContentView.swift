// ContentView.swift
// Root view. Branches on horizontal size class: compact (iPhone, narrow iPad
// multitasking) shows the bottom TabView (TabRootView); regular (iPad full/half,
// Mac) shows the adaptable TabView (AdaptableTabRootView) — a compact floating
// tab bar that expands into a sidebar, with per-tab list | detail reading. Keying
// on size class — not device idiom — means iPad multitasking that shrinks the app
// falls back to the bottom tab bar gracefully.

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            AdaptableTabRootView()
        } else {
            TabRootView()
        }
    }
}

#Preview {
    ContentView()
}
