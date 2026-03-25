//
//  ContentView.swift
//  LiquidNews
//
//  Created by Fred on 24/3/2026.
//

// ContentView.swift
// The root view. Wraps StoriesListView in a NavigationStack and forces
// dark mode so the glass cards always render against the dark gradient.

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            StoriesListView()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
