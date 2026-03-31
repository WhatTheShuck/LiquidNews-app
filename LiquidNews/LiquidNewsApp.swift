//
//  LiquidNewsApp.swift
//  LiquidNews
//
//  Created by Fred on 24/3/2026.
//

import SwiftUI

/// Shared state that carries a pending deep-linked story ID from the URL
/// handler down to ContentView, which fetches and presents it.
@Observable
class DeepLinkState {
    var pendingItemID: Int? = nil
}

@main
struct LiquidNewsApp: App {

    @State private var deepLink = DeepLinkState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLink)
                .onOpenURL { url in
                    deepLink.pendingItemID = itemID(from: url)
                }
        }
    }

    /// Extracts an HN item ID from either scheme:
    ///   liquidnews://story/42
    ///   https://news.ycombinator.com/item?id=42
    private func itemID(from url: URL) -> Int? {
        if url.scheme == "liquidnews", url.host == "story",
           let segment = url.pathComponents.dropFirst().first {
            return Int(segment)
        }
        if url.host?.hasSuffix("ycombinator.com") == true, url.path == "/item",
           let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "id" })?.value {
            return Int(value)
        }
        return nil
    }
}
