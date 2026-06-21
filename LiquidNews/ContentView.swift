// ContentView.swift
// Root view. Branches on horizontal size class: compact (iPhone, narrow iPad
// multitasking) shows the TabView (TabRootView); regular (iPad full/half, Mac)
// shows the three-column split view (RootSplitView). Keying on size class — not
// device idiom — means iPad multitasking that shrinks the app falls back to the
// tab bar gracefully.

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            RootSplitView()
        } else {
            TabRootView()
        }
    }
}

#Preview {
    ContentView()
}
