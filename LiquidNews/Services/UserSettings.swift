// UserSettings.swift
// User-configurable preferences, backed by UserDefaults.
//
// @Observable so SwiftUI views re-render when settings change.
// Accessed globally via UserSettings.shared.

import Foundation
import Observation
import SwiftUI

// MARK: - Link open mode

enum LinkOpenMode: String, CaseIterable, Identifiable {
    case reader  = "reader"
    case browser = "browser"
    case safari  = "safari"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reader:  "Reader"
        case .browser: "In-App Browser"
        case .safari:  "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .reader:  "Extract and display article content natively"
        case .browser: "Open articles inside the app with full web rendering"
        case .safari:  "Hand off to Safari for every link"
        }
    }

    var systemImage: String {
        switch self {
        case .reader:  "textformat"
        case .browser: "globe"
        case .safari:  "safari"
        }
    }
}

// MARK: - Swipe action options

enum SwipeAction: String, CaseIterable, Identifiable {
    case favourite = "favourite"
    case saveLater = "saveLater"
    case none      = "none"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .favourite: "Favourite"
        case .saveLater: "Save for Later"
        case .none:      "None"
        }
    }

    var systemImage: String {
        switch self {
        case .favourite: "heart"
        case .saveLater: "bookmark"
        case .none:      "minus"
        }
    }
}

@Observable
final class UserSettings {

    static let shared = UserSettings()

    // MARK: - Comment expansion

    /// How many replies to auto-load per comment (0 = never, loads on tap only).
    /// HN's own website shows all replies inline, but that's impractical on mobile.
    /// Default of 3 balances context vs. scroll fatigue.
    var autoLoadReplyCount: Int {
        didSet { UserDefaults.standard.set(autoLoadReplyCount, forKey: Keys.autoLoadReplyCount) }
    }

    /// Maximum nesting depth at which replies auto-load.
    /// Depth 0 = top-level comments, 1 = direct replies, etc.
    /// Beyond this depth, replies require a manual tap to load.
    /// Default of 2 keeps threads readable without infinite nesting.
    var maxAutoExpandDepth: Int {
        didSet { UserDefaults.standard.set(maxAutoExpandDepth, forKey: Keys.maxAutoExpandDepth) }
    }

    // MARK: - Comment rendering

    /// Global default for how comment text is rendered.
    /// Can be overridden per-comment from the long-press context menu.
    var commentRenderingStyle: CommentRenderMode {
        didSet { UserDefaults.standard.set(commentRenderingStyle.rawValue, forKey: Keys.commentRenderingStyle) }
    }

    // MARK: - Tab bar

    /// Which optional tabs appear in the bottom pill. Feed is always shown and not stored here.
    var enabledOptionalTabs: Set<AppTab> {
        didSet {
            UserDefaults.standard.set(
                enabledOptionalTabs.map(\.rawValue),
                forKey: Keys.enabledOptionalTabs
            )
        }
    }

    /// Display order of all optional tabs. All five are always present here;
    /// whether each is visible is controlled by `enabledOptionalTabs`.
    var tabOrder: [AppTab] {
        didSet { UserDefaults.standard.set(tabOrder.map(\.rawValue), forKey: Keys.tabOrder) }
    }

    // MARK: - Feed categories

    /// Display order of all known feed categories (enabled and disabled).
    var feedCategoryOrder: [StoryCategory] {
        didSet { UserDefaults.standard.set(feedCategoryOrder.map(\.rawValue), forKey: Keys.feedCategoryOrder) }
    }

    /// Which feed categories the user has switched on.
    /// At least one is always kept enabled.
    var enabledFeedCategories: Set<StoryCategory> {
        didSet { UserDefaults.standard.set(Array(enabledFeedCategories.map(\.rawValue)), forKey: Keys.enabledFeedCategories) }
    }

    /// Enabled categories in user-defined display order (used by the chip picker).
    var orderedEnabledCategories: [StoryCategory] {
        feedCategoryOrder.filter { enabledFeedCategories.contains($0) }
    }

    // MARK: - Link opening

    /// How article links open by default. Users can one-off override via long-press.
    var defaultLinkOpen: LinkOpenMode {
        didSet { UserDefaults.standard.set(defaultLinkOpen.rawValue, forKey: Keys.defaultLinkOpen) }
    }

    // MARK: - Swipe actions

    /// Action triggered when swiping a story card left (trailing edge).
    var swipeLeftAction: SwipeAction {
        didSet { UserDefaults.standard.set(swipeLeftAction.rawValue, forKey: Keys.swipeLeftAction) }
    }

    /// Action triggered when swiping a story card right (leading edge).
    var swipeRightAction: SwipeAction {
        didSet { UserDefaults.standard.set(swipeRightAction.rawValue, forKey: Keys.swipeRightAction) }
    }

    // MARK: - Curated sources

    /// When true, the "loading may take a moment" banner is permanently hidden.
    var hideCuratedLoadingBanner: Bool {
        didSet { UserDefaults.standard.set(hideCuratedLoadingBanner, forKey: Keys.hideCuratedLoadingBanner) }
    }

    /// Which built-in curated sources are enabled (stored by rawValue).
    var enabledBuiltInCuratedSources: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledBuiltInCuratedSources), forKey: Keys.enabledBuiltInCuratedSources)
        }
    }

    /// User-added custom curated feed URLs.
    var customCuratedFeeds: [CustomCuratedFeed] {
        didSet {
            if let data = try? JSONEncoder().encode(customCuratedFeeds) {
                UserDefaults.standard.set(data, forKey: Keys.customCuratedFeeds)
            }
        }
    }

    // MARK: - Init

    private enum Keys {
        static let autoLoadReplyCount           = "LN_autoLoadReplyCount"
        static let maxAutoExpandDepth           = "LN_maxAutoExpandDepth"
        static let enabledOptionalTabs          = "LN_enabledOptionalTabs"
        static let tabOrder                     = "LN_tabOrder"
        static let commentRenderingStyle        = "LN_commentRenderingStyle"
        static let hideCuratedLoadingBanner     = "LN_hideCuratedLoadingBanner"
        static let enabledBuiltInCuratedSources = "LN_enabledBuiltInCuratedSources"
        static let customCuratedFeeds           = "LN_customCuratedFeeds"
        static let feedCategoryOrder            = "LN_feedCategoryOrder"
        static let enabledFeedCategories        = "LN_enabledFeedCategories"
        static let swipeLeftAction              = "LN_swipeLeftAction"
        static let swipeRightAction             = "LN_swipeRightAction"
        static let defaultLinkOpen              = "LN_defaultLinkOpen"
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register sensible defaults for first launch
        defaults.register(defaults: [
            Keys.autoLoadReplyCount:           3,
            Keys.maxAutoExpandDepth:           2,
            Keys.enabledOptionalTabs:          AppTab.optional.map(\.rawValue),
            Keys.tabOrder:                     AppTab.optional.map(\.rawValue),
            Keys.commentRenderingStyle:        CommentRenderMode.rich.rawValue,
            Keys.enabledBuiltInCuratedSources: BuiltInCuratedSource.allCases.map(\.rawValue),
            Keys.feedCategoryOrder:            StoryCategory.allCases.map(\.rawValue),
            Keys.enabledFeedCategories:        StoryCategory.defaults.map(\.rawValue),
            Keys.swipeLeftAction:              SwipeAction.favourite.rawValue,
            Keys.swipeRightAction:             SwipeAction.saveLater.rawValue,
            Keys.defaultLinkOpen:              LinkOpenMode.browser.rawValue,
        ])

        autoLoadReplyCount = defaults.integer(forKey: Keys.autoLoadReplyCount)
        maxAutoExpandDepth = defaults.integer(forKey: Keys.maxAutoExpandDepth)

        let rawTabs = defaults.stringArray(forKey: Keys.enabledOptionalTabs)
            ?? AppTab.optional.map(\.rawValue)
        enabledOptionalTabs = Set(rawTabs.compactMap(AppTab.init(rawValue:)))

        // Restore tab order; append any tabs missing from a previous version's saved order
        let savedOrder = (defaults.stringArray(forKey: Keys.tabOrder) ?? [])
            .compactMap(AppTab.init(rawValue:))
        let missing = AppTab.optional.filter { !savedOrder.contains($0) }
        tabOrder = savedOrder + missing

        let rawRenderMode = defaults.string(forKey: Keys.commentRenderingStyle) ?? CommentRenderMode.rich.rawValue
        commentRenderingStyle = CommentRenderMode(rawValue: rawRenderMode) ?? .rich

        let rawBuiltIn = defaults.stringArray(forKey: Keys.enabledBuiltInCuratedSources)
            ?? BuiltInCuratedSource.allCases.map(\.rawValue)
        enabledBuiltInCuratedSources = Set(rawBuiltIn)

        hideCuratedLoadingBanner = defaults.bool(forKey: Keys.hideCuratedLoadingBanner)

        if let data = defaults.data(forKey: Keys.customCuratedFeeds),
           let feeds = try? JSONDecoder().decode([CustomCuratedFeed].self, from: data) {
            customCuratedFeeds = feeds
        } else {
            customCuratedFeeds = []
        }

        // Feed categories: restore saved order and append any new categories added in updates
        let savedCategoryOrder = (defaults.stringArray(forKey: Keys.feedCategoryOrder) ?? [])
            .compactMap(StoryCategory.init(rawValue:))
        let missingCategories = StoryCategory.allCases.filter { !savedCategoryOrder.contains($0) }
        feedCategoryOrder = savedCategoryOrder + missingCategories

        let rawEnabled = defaults.stringArray(forKey: Keys.enabledFeedCategories)
            ?? StoryCategory.defaults.map(\.rawValue)
        enabledFeedCategories = Set(rawEnabled.compactMap(StoryCategory.init(rawValue:)))

        let rawSwipeLeft = defaults.string(forKey: Keys.swipeLeftAction) ?? SwipeAction.favourite.rawValue
        swipeLeftAction = SwipeAction(rawValue: rawSwipeLeft) ?? .favourite

        let rawSwipeRight = defaults.string(forKey: Keys.swipeRightAction) ?? SwipeAction.saveLater.rawValue
        swipeRightAction = SwipeAction(rawValue: rawSwipeRight) ?? .saveLater

        let rawLinkOpen = defaults.string(forKey: Keys.defaultLinkOpen) ?? LinkOpenMode.browser.rawValue
        defaultLinkOpen = LinkOpenMode(rawValue: rawLinkOpen) ?? .browser
    }
}
