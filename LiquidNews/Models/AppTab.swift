// AppTab.swift
// The six navigatable sections of the app.
// Feed is always present; the other five are user-configurable via Settings.

import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed
    case catchUp
    case readLater
    case history
    case favourites
    case curated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed:       return "Feed"
        case .catchUp:    return "Catch-up"
        case .readLater:  return "Read Later"
        case .history:    return "History"
        case .favourites: return "Favourites"
        case .curated:    return "Curated"
        }
    }

    var systemImage: String {
        switch self {
        case .feed:       return "newspaper"
        case .catchUp:    return "sparkles"
        case .readLater:  return "bookmark"
        case .history:    return "clock"
        case .favourites: return "heart"
        case .curated:    return "list.star"
        }
    }

    /// Feed is always shown and cannot be toggled off.
    var isRequired: Bool { self == .feed }

    /// The five tabs the user can add or remove.
    static var optional: [AppTab] { allCases.filter { !$0.isRequired } }

    /// Feed first, then the given optional tabs in `order`, filtered to those in
    /// `enabled`. The single source of truth for top-level tab ordering — used by
    /// the iPad adaptable TabView and the compact TabRootView.
    static func orderedEnabled(order: [AppTab], enabled: Set<AppTab>) -> [AppTab] {
        [.feed] + order.filter { $0 != .feed && enabled.contains($0) }
    }
}
