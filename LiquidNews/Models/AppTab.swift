// AppTab.swift
// The six navigatable sections of the app.
// Feed is always present; the other five are user-configurable via Settings.

import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case feed
    case catchUp
    case saved
    case history
    case favourites
    case curated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed:       return "Feed"
        case .catchUp:    return "Catch-up"
        case .saved:      return "Saved"
        case .history:    return "History"
        case .favourites: return "Favourites"
        case .curated:    return "Curated"
        }
    }

    var systemImage: String {
        switch self {
        case .feed:       return "newspaper"
        case .catchUp:    return "sparkles"
        case .saved:      return "bookmark"
        case .history:    return "clock"
        case .favourites: return "heart"
        case .curated:    return "list.star"
        }
    }

    /// Feed is always shown and cannot be toggled off.
    var isRequired: Bool { self == .feed }

    /// The four tabs the user can add or remove.
    static var optional: [AppTab] { allCases.filter { !$0.isRequired } }
}
