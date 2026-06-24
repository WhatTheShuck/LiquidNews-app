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
}

// MARK: - Detail column mode

/// What the detail column shows for the selected story.
enum DetailMode: Hashable {
    case comments   // StoryDetailView
    case reader     // ArticleReaderView
    case browser    // in-app SafariView
    case thread     // ThreadView — a deep-linked comment, with a swap to its story

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

    /// Maps the user's default link-open mode to the detail-column mode when a
    /// story is opened via "Read Article" on iPad. `.safari` opens externally,
    /// so it returns `nil` and the caller should fall back to opening the URL.
    static func forLinkOpen(_ mode: LinkOpenMode) -> DetailMode? {
        switch mode {
        case .reader:      return .reader
        case .inAppSafari: return .browser
        case .safari:      return nil
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

    /// Closes the current article entirely: clears the selection AND resets the
    /// detail mode to `.comments`. Resetting the mode is essential — while reading
    /// side by side the layout collapses to `.detailOnly`, and that only reverts to
    /// `.all` (revealing the list again) once `isReaderSideBySideVisible` becomes
    /// false. Clearing `selectedStory` alone leaves `detailMode == .reader`, so the
    /// split stays collapsed on an empty placeholder.
    func closeStory() {
        selectedStory = nil
        detailMode = .comments
    }

    /// Whether the detail column should show comments and the reader side by side.
    /// True only while reading (`detailMode == .reader`) under the `.sideBySide`
    /// layout. In `.replace` the reader takes over the whole column, so this is
    /// false; for `.comments` and `.browser` it is always false.
    func isReaderSideBySide(layout: IPadReaderLayout) -> Bool {
        detailMode == .reader && layout == .sideBySide
    }

    /// Whether the side-by-side reader is actually visible in the detail column —
    /// i.e. reading side by side AND a browsing tab is the active destination.
    /// `DetailColumnView` only renders a story (and thus the side-by-side pane) for
    /// `.tab` destinations, so the split view should only stay collapsed then.
    func isReaderSideBySideVisible(layout: IPadReaderLayout) -> Bool {
        guard case .tab = destination else { return false }
        return isReaderSideBySide(layout: layout)
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
