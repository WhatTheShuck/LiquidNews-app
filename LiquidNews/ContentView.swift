// ContentView.swift
// Root view. Branches on horizontal size class: compact (iPhone, narrow iPad
// multitasking) shows the TabView (TabRootView); regular (iPad full/half, Mac)
// shows the three-column split view (RootSplitView, wired in Task 9).

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabRootView()
    }
}

#Preview {
    ContentView()
}
