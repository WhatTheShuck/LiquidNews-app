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

// MARK: - Viewed post behaviour

enum ReadBehaviour: String, CaseIterable, Identifiable {
    case hide    = "hide"
    case dim     = "dim"
    case nothing = "nothing"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hide:    "Hide"
        case .dim:     "Grey out"
        case .nothing: "Nothing"
        }
    }

    var systemImage: String {
        switch self {
        case .hide:    "eye.slash"
        case .dim:     "circle.lefthalf.filled"
        case .nothing: "minus"
        }
    }

    var subtitle: String {
        switch self {
        case .hide:    "Viewed posts disappear from feeds"
        case .dim:     "Viewed posts are shown faded"
        case .nothing: "No change to viewed posts"
        }
    }
}

// MARK: - Hidden posts auto-expiry

enum HiddenPostsExpiry: String, CaseIterable, Identifiable {
    case never  = "never"
    case days7  = "7days"
    case days30 = "30days"
    case days90 = "90days"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never:  "Never"
        case .days7:  "After 7 days"
        case .days30: "After 30 days"
        case .days90: "After 90 days"
        }
    }

    /// Returns the cutoff `Date` before which hidden entries should be removed,
    /// or `nil` if expiry is disabled.
    var cutoffDate: Date? {
        switch self {
        case .never:  nil
        case .days7:  Calendar.current.date(byAdding: .day, value: -7,  to: .now)
        case .days30: Calendar.current.date(byAdding: .day, value: -30, to: .now)
        case .days90: Calendar.current.date(byAdding: .day, value: -90, to: .now)
        }
    }
}

// MARK: - Story action (tap + swipe)

/// All the actions that can be assigned to a swipe gesture or the default tap.
enum StoryAction: String, CaseIterable, Identifiable {
    case openComments = "openComments"
    case openBrowser  = "openBrowser"
    case openReader   = "openReader"
    case openSafari   = "openSafari"
    case favourite    = "favourite"
    case saveLater    = "saveLater"
    case hide         = "hide"
    case none         = "none"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openComments: "Open Comments"
        case .openBrowser:  "Open in Browser"
        case .openReader:   "Open in Reader"
        case .openSafari:   "Open in Safari"
        case .favourite:    "Favourite"
        case .saveLater:    "Read Later"
        case .hide:         "Hide Post"
        case .none:         "None"
        }
    }

    var systemImage: String {
        switch self {
        case .openComments: "bubble.left"
        case .openBrowser:  "globe"
        case .openReader:   "textformat"
        case .openSafari:   "safari"
        case .favourite:    "heart"
        case .saveLater:    "bookmark"
        case .hide:         "eye.slash"
        case .none:         "minus"
        }
    }

    /// Tint colour used when this action appears as a swipe button.
    var swipeTint: Color {
        switch self {
        case .openComments: .purple
        case .openBrowser:  .teal
        case .openReader:   .green
        case .openSafari:   .blue
        case .favourite:    .orange
        case .saveLater:    .indigo
        case .hide:         .red
        case .none:         .gray
        }
    }

    /// Cases valid for the default-tap setting (exclude none/hide which make no sense as a tap).
    static var tapOptions: [StoryAction] {
        [.openComments, .openBrowser, .openReader, .openSafari]
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

    // MARK: - Tap + swipe actions

    /// What happens when the user taps a story card.
    var tapAction: StoryAction {
        didSet { UserDefaults.standard.set(tapAction.rawValue, forKey: Keys.tapAction) }
    }

    /// Action triggered when swiping a story card left (trailing edge).
    var swipeLeftAction: StoryAction {
        didSet { UserDefaults.standard.set(swipeLeftAction.rawValue, forKey: Keys.swipeLeftAction) }
    }

    /// Action triggered when swiping a story card right (leading edge).
    var swipeRightAction: StoryAction {
        didSet { UserDefaults.standard.set(swipeRightAction.rawValue, forKey: Keys.swipeRightAction) }
    }

    // MARK: - Hidden posts expiry

    /// How long to retain hidden post entries before auto-clearing them.
    var hiddenPostsExpiry: HiddenPostsExpiry {
        didSet { UserDefaults.standard.set(hiddenPostsExpiry.rawValue, forKey: Keys.hiddenPostsExpiry) }
    }

    /// What happens to a story in feeds after the user opens it.
    var readBehaviour: ReadBehaviour {
        didSet { UserDefaults.standard.set(readBehaviour.rawValue, forKey: Keys.readBehaviour) }
    }

    // MARK: - Reader

    /// When true, images are fetched and shown in Reader mode by default.
    /// Can still be toggled per-article from the reader's ellipsis menu.
    var readerShowImagesByDefault: Bool {
        didSet { UserDefaults.standard.set(readerShowImagesByDefault, forKey: Keys.readerShowImagesByDefault) }
    }

    // MARK: - Read Later

    /// When true, a count badge appears on the Read Later tab.
    var showReadLaterBadge: Bool {
        didSet { UserDefaults.standard.set(showReadLaterBadge, forKey: Keys.showReadLaterBadge) }
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
        static let tapAction                    = "LN_tapAction"
        static let swipeLeftAction              = "LN_swipeLeftAction"
        static let swipeRightAction             = "LN_swipeRightAction"
        static let defaultLinkOpen              = "LN_defaultLinkOpen"
        static let hiddenPostsExpiry            = "LN_hiddenPostsExpiry"
        static let readBehaviour                = "LN_readBehaviour"
        static let readerShowImagesByDefault    = "LN_readerShowImagesByDefault"
        static let showReadLaterBadge           = "LN_showReadLaterBadge"
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
            Keys.tapAction:                    StoryAction.openComments.rawValue,
            Keys.swipeLeftAction:              StoryAction.favourite.rawValue,
            Keys.swipeRightAction:             StoryAction.saveLater.rawValue,
            Keys.defaultLinkOpen:              LinkOpenMode.browser.rawValue,
            Keys.hiddenPostsExpiry:            HiddenPostsExpiry.days30.rawValue,
            Keys.readBehaviour:                ReadBehaviour.dim.rawValue,
            Keys.readerShowImagesByDefault:    false,
            Keys.showReadLaterBadge:           true,
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

        let rawTap = defaults.string(forKey: Keys.tapAction) ?? StoryAction.openComments.rawValue
        tapAction = StoryAction(rawValue: rawTap) ?? .openComments

        let rawSwipeLeft = defaults.string(forKey: Keys.swipeLeftAction) ?? StoryAction.favourite.rawValue
        swipeLeftAction = StoryAction(rawValue: rawSwipeLeft) ?? .favourite

        let rawSwipeRight = defaults.string(forKey: Keys.swipeRightAction) ?? StoryAction.saveLater.rawValue
        swipeRightAction = StoryAction(rawValue: rawSwipeRight) ?? .saveLater

        let rawLinkOpen = defaults.string(forKey: Keys.defaultLinkOpen) ?? LinkOpenMode.browser.rawValue
        defaultLinkOpen = LinkOpenMode(rawValue: rawLinkOpen) ?? .browser

        let rawExpiry = defaults.string(forKey: Keys.hiddenPostsExpiry) ?? HiddenPostsExpiry.days30.rawValue
        hiddenPostsExpiry = HiddenPostsExpiry(rawValue: rawExpiry) ?? .days30

        let rawReadBehaviour = defaults.string(forKey: Keys.readBehaviour) ?? ReadBehaviour.dim.rawValue
        readBehaviour = ReadBehaviour(rawValue: rawReadBehaviour) ?? .dim

        readerShowImagesByDefault = defaults.bool(forKey: Keys.readerShowImagesByDefault)

        showReadLaterBadge = defaults.bool(forKey: Keys.showReadLaterBadge)
    }
}
