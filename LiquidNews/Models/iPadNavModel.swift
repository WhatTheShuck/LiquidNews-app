// iPadNavModel.swift
// Coordinator for the iPad/Mac three-column split view. Injected into the
// environment only on regular-width layouts; its presence is the signal that
// list views should drive the detail column instead of opening a sheet.

import SwiftUI

// MARK: - Sidebar destinations

/// A selectable row in the sidebar.
enum SidebarDestination: Hashable {
    case tab(AppTab)
    case search
    case settings
    case account
}

// MARK: - Detail column mode

/// What the detail column shows for the selected story.
enum DetailMode: Hashable {
    case comments   // StoryDetailView
    case reader     // ArticleReaderView
    case browser    // in-app SafariView

    /// Maps a navigation `StoryAction` to the detail mode for a freshly selected
    /// story. Returns `nil` for non-navigation actions (favourite/saveLater/hide/
    /// none) — the caller should keep its existing side-effect behavior for those.
    /// `.reader`/`.browser` fall back to `.comments` when the story has no URL.
    /// `.openSafari` is opened externally by the caller; the detail column falls
    /// back to `.comments`.
    static func forSelection(action: StoryAction, hasURL: Bool) -> DetailMode? {
        switch action {
        case .openComments: return .comments
        case .openReader:   return hasURL ? .reader : .comments
        case .openBrowser:  return hasURL ? .browser : .comments
        case .openSafari:   return .comments
        case .favourite, .saveLater, .hide, .none: return nil
        }
    }
}

// MARK: - Navigation model

@Observable
final class iPadNavModel {
    var destination: SidebarDestination = .tab(.feed)
    var selectedStory: HNItem?
    var detailMode: DetailMode = .comments

    /// Select a story and the mode the detail column should present it in.
    func select(_ story: HNItem, mode: DetailMode) {
        selectedStory = story
        detailMode = mode
    }
}

// MARK: - Environment key

private struct iPadNavModelKey: EnvironmentKey {
    static let defaultValue: iPadNavModel? = nil
}

extension EnvironmentValues {
    /// The split-view coordinator, or `nil` on iPhone / compact layouts.
    var iPadNavModel: iPadNavModel? {
        get { self[iPadNavModelKey.self] }
        set { self[iPadNavModelKey.self] = newValue }
    }
}
