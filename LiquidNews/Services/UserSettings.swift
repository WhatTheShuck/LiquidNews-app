// UserSettings.swift
// User-configurable preferences, backed by NSUbiquitousKeyValueStore (iCloud KV sync).
//
// @Observable so SwiftUI views re-render when settings change.
// Accessed globally via UserSettings.shared.

import Foundation
import Observation
import SwiftUI

// MARK: - Link open mode

enum LinkOpenMode: String, CaseIterable, Identifiable {
    case reader      = "reader"
    case inAppSafari = "inAppSafari"
    case safari      = "safari"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reader:      "Reader"
        case .inAppSafari: "In-App Safari"
        case .safari:      "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .reader:      "Extract and display article content natively"
        case .inAppSafari: "Open articles inside the app with Safari"
        case .safari:      "Hand off to Safari for every link"
        }
    }

    var systemImage: String {
        switch self {
        case .reader:      "textformat"
        case .inAppSafari: "safari"
        case .safari:      "arrow.up.right.square"
        }
    }
}

// MARK: - Comment link mode

enum CommentLinkMode: String, CaseIterable, Identifiable {
    case inAppSafari = "inAppSafari"
    case reader      = "reader"
    case safari      = "safari"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inAppSafari: "In-App Safari"
        case .reader:      "Reader"
        case .safari:      "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .inAppSafari: "Open in Safari without leaving the app"
        case .reader:      "Extract and display content natively"
        case .safari:      "Hand off to Safari"
        }
    }

    var systemImage: String {
        switch self {
        case .inAppSafari: "safari"
        case .reader:      "textformat"
        case .safari:      "arrow.up.right.square"
        }
    }
}

// MARK: - Reader link mode

enum ReaderLinkMode: String, CaseIterable, Identifiable {
    case inAppSafari = "inAppSafari"
    case reader      = "reader"
    case inline      = "inline"
    case safari      = "safari"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inAppSafari: "In-App Safari"
        case .reader:      "Reader"
        case .inline:      "Inline"
        case .safari:      "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .inAppSafari: "Open in Safari without leaving the app"
        case .reader:      "Extract and display content natively"
        case .inline:      "Navigate within the current view"
        case .safari:      "Hand off to Safari"
        }
    }

    var systemImage: String {
        switch self {
        case .inAppSafari: "safari"
        case .reader:      "textformat"
        case .inline:      "arrow.turn.down.right"
        case .safari:      "arrow.up.right.square"
        }
    }
}

// MARK: - HN thread link mode

enum HNLinkMode: String, CaseIterable, Identifiable {
    case inApp   = "inApp"
    case safari  = "safari"
    case ask     = "ask"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inApp:   "In App"
        case .safari:  "Safari"
        case .ask:     "Ask Each Time"
        }
    }

    var subtitle: String {
        switch self {
        case .inApp:   "Open HN thread links within LiquidNews"
        case .safari:  "Hand off to Safari"
        case .ask:     "Show share sheet each time"
        }
    }

    var systemImage: String {
        switch self {
        case .inApp:   "apps.iphone"
        case .safari:  "arrow.up.right.square"
        case .ask:     "square.and.arrow.up"
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
        case .openBrowser:  "In-App Safari"
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
        case .openBrowser:  "safari"
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

// MARK: - App color scheme override

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "system"
    case dark   = "dark"
    case light  = "light"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .dark:   return "Dark"
        case .light:  return "Light"
        }
    }

    /// The SwiftUI ColorScheme to pass to `.preferredColorScheme()`.
    /// nil means follow the system — SwiftUI treats nil as "no override".
    var resolved: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

@Observable
final class UserSettings {

    static let shared = UserSettings()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private static let migrationKey = "LN_kv_migrated"

    // MARK: - Comment expansion

    /// How many replies to auto-load per comment (0 = never, loads on tap only).
    /// HN's own website shows all replies inline, but that's impractical on mobile.
    /// Default of 3 balances context vs. scroll fatigue.
    var autoLoadReplyCount: Int {
        didSet { kvStore.set(autoLoadReplyCount, forKey: Keys.autoLoadReplyCount) }
    }

    /// Maximum nesting depth at which replies auto-load.
    /// Depth 0 = top-level comments, 1 = direct replies, etc.
    /// Beyond this depth, replies require a manual tap to load.
    /// Default of 2 keeps threads readable without infinite nesting.
    var maxAutoExpandDepth: Int {
        didSet { kvStore.set(maxAutoExpandDepth, forKey: Keys.maxAutoExpandDepth) }
    }

    /// Max concurrent comment fetches on WiFi. Higher = faster load, more bandwidth.
    var maxConcurrentFetchesWifi: Int {
        didSet { kvStore.set(maxConcurrentFetchesWifi, forKey: Keys.maxConcurrentFetchesWifi) }
    }

    /// Max concurrent comment fetches on cellular. Lower = less data usage and more
    /// reliable loads on poor connections.
    var maxConcurrentFetchesCellular: Int {
        didSet { kvStore.set(maxConcurrentFetchesCellular, forKey: Keys.maxConcurrentFetchesCellular) }
    }

    // MARK: - Comment rendering

    /// Global default for how comment text is rendered.
    /// Can be overridden per-comment from the long-press context menu.
    var commentRenderingStyle: CommentRenderMode {
        didSet { kvStore.set(commentRenderingStyle.rawValue, forKey: Keys.commentRenderingStyle) }
    }

    // MARK: - Tab bar

    /// Which optional tabs appear in the bottom pill. Feed is always shown and not stored here.
    var enabledOptionalTabs: Set<AppTab> {
        didSet { kvStore.set(enabledOptionalTabs.map(\.rawValue), forKey: Keys.enabledOptionalTabs) }
    }

    /// Display order of all optional tabs. All five are always present here;
    /// whether each is visible is controlled by `enabledOptionalTabs`.
    var tabOrder: [AppTab] {
        didSet { kvStore.set(tabOrder.map(\.rawValue), forKey: Keys.tabOrder) }
    }

    // MARK: - Feed categories

    /// Display order of all known feed categories (enabled and disabled).
    var feedCategoryOrder: [StoryCategory] {
        didSet { kvStore.set(feedCategoryOrder.map(\.rawValue), forKey: Keys.feedCategoryOrder) }
    }

    /// Which feed categories the user has switched on.
    /// At least one is always kept enabled.
    var enabledFeedCategories: Set<StoryCategory> {
        didSet { kvStore.set(Array(enabledFeedCategories.map(\.rawValue)), forKey: Keys.enabledFeedCategories) }
    }

    /// Enabled categories in user-defined display order (used by the chip picker).
    var orderedEnabledCategories: [StoryCategory] {
        feedCategoryOrder.filter { enabledFeedCategories.contains($0) }
    }

    // MARK: - Link opening

    /// How article links open by default. Users can one-off override via long-press.
    var defaultLinkOpen: LinkOpenMode {
        didSet { kvStore.set(defaultLinkOpen.rawValue, forKey: Keys.defaultLinkOpen) }
    }

    // MARK: - Inline link modes

    /// How links tapped inside comment text open.
    var commentLinkOpen: CommentLinkMode {
        didSet { kvStore.set(commentLinkOpen.rawValue, forKey: Keys.commentLinkOpen) }
    }

    /// How links tapped inside reader views open.
    var readerLinkOpen: ReaderLinkMode {
        didSet { kvStore.set(readerLinkOpen.rawValue, forKey: Keys.readerLinkOpen) }
    }

    /// How links to other HN threads open when tapped inside comments or the reader.
    var hnThreadLinkOpen: HNLinkMode {
        didSet { kvStore.set(hnThreadLinkOpen.rawValue, forKey: Keys.hnThreadLinkOpen) }
    }

    // MARK: - Tap + swipe actions

    /// What happens when the user taps a story card.
    var tapAction: StoryAction {
        didSet { kvStore.set(tapAction.rawValue, forKey: Keys.tapAction) }
    }

    /// Action triggered when swiping a story card left (trailing edge).
    var swipeLeftAction: StoryAction {
        didSet { kvStore.set(swipeLeftAction.rawValue, forKey: Keys.swipeLeftAction) }
    }

    /// Action triggered when swiping a story card right (leading edge).
    var swipeRightAction: StoryAction {
        didSet { kvStore.set(swipeRightAction.rawValue, forKey: Keys.swipeRightAction) }
    }

    // MARK: - Hidden posts expiry

    /// How long to retain hidden post entries before auto-clearing them.
    var hiddenPostsExpiry: HiddenPostsExpiry {
        didSet { kvStore.set(hiddenPostsExpiry.rawValue, forKey: Keys.hiddenPostsExpiry) }
    }

    /// What happens to a story in feeds after the user opens it.
    var readBehaviour: ReadBehaviour {
        didSet { kvStore.set(readBehaviour.rawValue, forKey: Keys.readBehaviour) }
    }

    // MARK: - Reader

    /// When true, images are fetched and shown in Reader mode by default.
    /// Can still be toggled per-article from the reader's ellipsis menu.
    var readerShowImagesByDefault: Bool {
        didSet { kvStore.set(readerShowImagesByDefault, forKey: Keys.readerShowImagesByDefault) }
    }

    /// When true, SFSafariViewController will attempt to enter Safari Reader Mode automatically.
    var safariReaderMode: Bool {
        didSet { kvStore.set(safariReaderMode, forKey: Keys.safariReaderMode) }
    }

    /// When true, code blocks in comments wrap long lines instead of scrolling horizontally.
    var codeWrapLines: Bool {
        didSet { kvStore.set(codeWrapLines, forKey: Keys.codeWrapLines) }
    }

    // MARK: - Read Later

    /// When true, a count badge appears on the Read Later tab.
    var showReadLaterBadge: Bool {
        didSet { kvStore.set(showReadLaterBadge, forKey: Keys.showReadLaterBadge) }
    }

    // MARK: - App Theme

    var selectedAppTheme: AppThemePreset {
        didSet { kvStore.set(selectedAppTheme.rawValue, forKey: Keys.selectedAppTheme) }
    }

    /// Custom accent color stored as a 6-char lowercase hex string, or nil for the preset default.
    var customAccentHex: String? {
        didSet {
            if let hex = customAccentHex {
                kvStore.set(hex, forKey: Keys.customAccentHex)
            } else {
                kvStore.removeObject(forKey: Keys.customAccentHex)
            }
        }
    }

    // MARK: - Color scheme override

    var appColorScheme: AppColorScheme {
        didSet { kvStore.set(appColorScheme.rawValue, forKey: Keys.appColorScheme) }
    }

    // MARK: - Curated sources

    /// When true, the "loading may take a moment" banner is permanently hidden.
    var hideCuratedLoadingBanner: Bool {
        didSet { kvStore.set(hideCuratedLoadingBanner, forKey: Keys.hideCuratedLoadingBanner) }
    }

    /// Which built-in curated sources are enabled (stored by rawValue).
    var enabledBuiltInCuratedSources: Set<String> {
        didSet {
            kvStore.set(Array(enabledBuiltInCuratedSources), forKey: Keys.enabledBuiltInCuratedSources)
        }
    }

    /// User-added custom curated feed URLs.
    var customCuratedFeeds: [CustomCuratedFeed] {
        didSet {
            if let data = try? JSONEncoder().encode(customCuratedFeeds) {
                kvStore.set(data, forKey: Keys.customCuratedFeeds)
            }
        }
    }

    // MARK: - Init

    private enum Keys {
        static let autoLoadReplyCount              = "LN_autoLoadReplyCount"
        static let maxAutoExpandDepth              = "LN_maxAutoExpandDepth"
        static let maxConcurrentFetchesWifi        = "LN_maxConcurrentFetchesWifi"
        static let maxConcurrentFetchesCellular    = "LN_maxConcurrentFetchesCellular"
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
        static let commentLinkOpen              = "LN_commentLinkOpen"
        static let readerLinkOpen               = "LN_readerLinkOpen"
        static let hnThreadLinkOpen             = "LN_hnThreadLinkOpen"
        static let hiddenPostsExpiry            = "LN_hiddenPostsExpiry"
        static let readBehaviour                = "LN_readBehaviour"
        static let readerShowImagesByDefault    = "LN_readerShowImagesByDefault"
        static let safariReaderMode             = "LN_safariReaderMode"
        static let codeWrapLines                = "LN_codeWrapLines"
        static let showReadLaterBadge           = "LN_showReadLaterBadge"
        static let selectedAppTheme             = "LN_selectedAppTheme"
        static let customAccentHex              = "LN_customAccentHex"
        static let appColorScheme               = "LN_appColorScheme"
    }

    /// Runs once on upgrade: copies existing UserDefaults values into the KV store
    /// so existing users don't lose their settings.
    /// Static so it can be called before all stored properties are initialized.
    private static func migrateFromUserDefaultsIfNeeded(kvStore: NSUbiquitousKeyValueStore, migrationKey: String) {
        let ud = UserDefaults.standard
        // The migration flag lives in UserDefaults (not the KV store) so that
        // device-local migration state is never subject to iCloud sync. If it were
        // in the KV store, one device completing migration could suppress migration
        // on another device that hasn't run yet.
        guard !ud.bool(forKey: migrationKey) else { return }
        let allKeys: [String] = [
            Keys.autoLoadReplyCount, Keys.maxAutoExpandDepth,
            Keys.enabledOptionalTabs, Keys.tabOrder,
            Keys.commentRenderingStyle, Keys.hideCuratedLoadingBanner,
            Keys.enabledBuiltInCuratedSources, Keys.customCuratedFeeds,
            Keys.feedCategoryOrder, Keys.enabledFeedCategories,
            Keys.tapAction, Keys.swipeLeftAction, Keys.swipeRightAction,
            Keys.defaultLinkOpen, Keys.commentLinkOpen, Keys.readerLinkOpen,
            Keys.hnThreadLinkOpen,
            Keys.hiddenPostsExpiry, Keys.readBehaviour,
            Keys.readerShowImagesByDefault, Keys.safariReaderMode, Keys.codeWrapLines, Keys.showReadLaterBadge,
            Keys.selectedAppTheme, Keys.customAccentHex, Keys.appColorScheme,
        ]
        for key in allKeys {
            if kvStore.object(forKey: key) == nil, let value = ud.object(forKey: key) {
                kvStore.set(value, forKey: key)
            }
        }
        kvStore.synchronize()
        ud.set(true, forKey: migrationKey)
    }

    private func applyExternalChanges(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        for key in changedKeys {
            switch key {
            case Keys.autoLoadReplyCount:
                autoLoadReplyCount = (kvStore.object(forKey: key) as? Int) ?? 3
            case Keys.maxAutoExpandDepth:
                maxAutoExpandDepth = (kvStore.object(forKey: key) as? Int) ?? 2
            case Keys.maxConcurrentFetchesWifi:
                maxConcurrentFetchesWifi = (kvStore.object(forKey: key) as? Int) ?? 10
            case Keys.maxConcurrentFetchesCellular:
                maxConcurrentFetchesCellular = (kvStore.object(forKey: key) as? Int) ?? 6
            case Keys.enabledOptionalTabs:
                let raw = (kvStore.array(forKey: key) as? [String]) ?? AppTab.optional.map(\.rawValue)
                enabledOptionalTabs = Set(raw.compactMap(AppTab.init(rawValue:)))
            case Keys.tabOrder:
                let saved = ((kvStore.array(forKey: key) as? [String]) ?? []).compactMap(AppTab.init(rawValue:))
                let missing = AppTab.optional.filter { !saved.contains($0) }
                tabOrder = saved + missing
            case Keys.commentRenderingStyle:
                commentRenderingStyle = CommentRenderMode(rawValue: kvStore.string(forKey: key) ?? "") ?? .rich
            case Keys.hideCuratedLoadingBanner:
                hideCuratedLoadingBanner = kvStore.bool(forKey: key)
            case Keys.enabledBuiltInCuratedSources:
                let raw = (kvStore.array(forKey: key) as? [String]) ?? BuiltInCuratedSource.allCases.map(\.rawValue)
                enabledBuiltInCuratedSources = Set(raw)
            case Keys.customCuratedFeeds:
                if let data = kvStore.data(forKey: key),
                   let feeds = try? JSONDecoder().decode([CustomCuratedFeed].self, from: data) {
                    customCuratedFeeds = feeds
                } else {
                    customCuratedFeeds = []
                }
            case Keys.feedCategoryOrder:
                let saved = ((kvStore.array(forKey: key) as? [String]) ?? []).compactMap(StoryCategory.init(rawValue:))
                let missing = StoryCategory.allCases.filter { !saved.contains($0) }
                feedCategoryOrder = saved + missing
            case Keys.enabledFeedCategories:
                let raw = (kvStore.array(forKey: key) as? [String]) ?? StoryCategory.defaults.map(\.rawValue)
                enabledFeedCategories = Set(raw.compactMap(StoryCategory.init(rawValue:)))
            case Keys.tapAction:
                tapAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .openComments
            case Keys.swipeLeftAction:
                swipeLeftAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .favourite
            case Keys.swipeRightAction:
                swipeRightAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .saveLater
            case Keys.defaultLinkOpen:
                let raw = kvStore.string(forKey: key) ?? ""
                let migrated = raw == "browser" ? LinkOpenMode.inAppSafari.rawValue : raw
                defaultLinkOpen = LinkOpenMode(rawValue: migrated) ?? .inAppSafari
            case Keys.commentLinkOpen:
                commentLinkOpen = CommentLinkMode(rawValue: kvStore.string(forKey: key) ?? "") ?? .inAppSafari
            case Keys.readerLinkOpen:
                readerLinkOpen = ReaderLinkMode(rawValue: kvStore.string(forKey: key) ?? "") ?? .inAppSafari
            case Keys.hnThreadLinkOpen:
                hnThreadLinkOpen = HNLinkMode(rawValue: kvStore.string(forKey: key) ?? "") ?? .inApp
            case Keys.hiddenPostsExpiry:
                hiddenPostsExpiry = HiddenPostsExpiry(rawValue: kvStore.string(forKey: key) ?? "") ?? .days30
            case Keys.readBehaviour:
                readBehaviour = ReadBehaviour(rawValue: kvStore.string(forKey: key) ?? "") ?? .dim
            case Keys.readerShowImagesByDefault:
                readerShowImagesByDefault = kvStore.bool(forKey: key)
            case Keys.safariReaderMode:
                safariReaderMode = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.codeWrapLines:
                codeWrapLines = kvStore.bool(forKey: key)
            case Keys.showReadLaterBadge:
                // kvStore.bool(forKey:) returns false for absent keys; this setting defaults to true
                showReadLaterBadge = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.selectedAppTheme:
                selectedAppTheme = AppThemePreset(rawValue: kvStore.string(forKey: key) ?? "") ?? .standard
            case Keys.customAccentHex:
                customAccentHex = kvStore.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 }
            case Keys.appColorScheme:
                appColorScheme = AppColorScheme(rawValue: kvStore.string(forKey: key) ?? "") ?? .system
            default:
                break
            }
        }
    }

    private init() {
        // Refresh the in-memory KV cache from disk before reading any values,
        // so settings changed on another device while this app wasn't running are picked up.
        NSUbiquitousKeyValueStore.default.synchronize()
        UserSettings.migrateFromUserDefaultsIfNeeded(kvStore: .default, migrationKey: UserSettings.migrationKey)

        autoLoadReplyCount = (kvStore.object(forKey: Keys.autoLoadReplyCount) as? Int) ?? 3
        maxAutoExpandDepth = (kvStore.object(forKey: Keys.maxAutoExpandDepth) as? Int) ?? 2
        maxConcurrentFetchesWifi     = (kvStore.object(forKey: Keys.maxConcurrentFetchesWifi) as? Int) ?? 10
        maxConcurrentFetchesCellular = (kvStore.object(forKey: Keys.maxConcurrentFetchesCellular) as? Int) ?? 6

        let rawTabs = (kvStore.array(forKey: Keys.enabledOptionalTabs) as? [String])
            ?? AppTab.optional.map(\.rawValue)
        enabledOptionalTabs = Set(rawTabs.compactMap(AppTab.init(rawValue:)))

        let savedOrder = ((kvStore.array(forKey: Keys.tabOrder) as? [String]) ?? [])
            .compactMap(AppTab.init(rawValue:))
        let missing = AppTab.optional.filter { !savedOrder.contains($0) }
        tabOrder = savedOrder + missing

        let rawRenderMode = kvStore.string(forKey: Keys.commentRenderingStyle) ?? CommentRenderMode.rich.rawValue
        commentRenderingStyle = CommentRenderMode(rawValue: rawRenderMode) ?? .rich

        let rawBuiltIn = (kvStore.array(forKey: Keys.enabledBuiltInCuratedSources) as? [String])
            ?? BuiltInCuratedSource.allCases.map(\.rawValue)
        enabledBuiltInCuratedSources = Set(rawBuiltIn)

        hideCuratedLoadingBanner = kvStore.bool(forKey: Keys.hideCuratedLoadingBanner)

        if let data = kvStore.data(forKey: Keys.customCuratedFeeds),
           let feeds = try? JSONDecoder().decode([CustomCuratedFeed].self, from: data) {
            customCuratedFeeds = feeds
        } else {
            customCuratedFeeds = []
        }

        let savedCategoryOrder = ((kvStore.array(forKey: Keys.feedCategoryOrder) as? [String]) ?? [])
            .compactMap(StoryCategory.init(rawValue:))
        let missingCategories = StoryCategory.allCases.filter { !savedCategoryOrder.contains($0) }
        feedCategoryOrder = savedCategoryOrder + missingCategories

        let rawEnabled = (kvStore.array(forKey: Keys.enabledFeedCategories) as? [String])
            ?? StoryCategory.defaults.map(\.rawValue)
        enabledFeedCategories = Set(rawEnabled.compactMap(StoryCategory.init(rawValue:)))

        let rawTap = kvStore.string(forKey: Keys.tapAction) ?? StoryAction.openComments.rawValue
        tapAction = StoryAction(rawValue: rawTap) ?? .openComments

        let rawSwipeLeft = kvStore.string(forKey: Keys.swipeLeftAction) ?? StoryAction.favourite.rawValue
        swipeLeftAction = StoryAction(rawValue: rawSwipeLeft) ?? .favourite

        let rawSwipeRight = kvStore.string(forKey: Keys.swipeRightAction) ?? StoryAction.saveLater.rawValue
        swipeRightAction = StoryAction(rawValue: rawSwipeRight) ?? .saveLater

        let rawLinkOpen = kvStore.string(forKey: Keys.defaultLinkOpen) ?? LinkOpenMode.inAppSafari.rawValue
        let migratedLinkOpen = rawLinkOpen == "browser" ? LinkOpenMode.inAppSafari.rawValue : rawLinkOpen
        defaultLinkOpen = LinkOpenMode(rawValue: migratedLinkOpen) ?? .inAppSafari
        if rawLinkOpen == "browser" {
            kvStore.set(migratedLinkOpen, forKey: Keys.defaultLinkOpen)
        }

        let rawCommentLink = kvStore.string(forKey: Keys.commentLinkOpen) ?? CommentLinkMode.inAppSafari.rawValue
        commentLinkOpen = CommentLinkMode(rawValue: rawCommentLink) ?? .inAppSafari

        let rawReaderLink = kvStore.string(forKey: Keys.readerLinkOpen) ?? ReaderLinkMode.inAppSafari.rawValue
        readerLinkOpen = ReaderLinkMode(rawValue: rawReaderLink) ?? .inAppSafari

        let rawHNLink = kvStore.string(forKey: Keys.hnThreadLinkOpen) ?? HNLinkMode.inApp.rawValue
        hnThreadLinkOpen = HNLinkMode(rawValue: rawHNLink) ?? .inApp

        let rawExpiry = kvStore.string(forKey: Keys.hiddenPostsExpiry) ?? HiddenPostsExpiry.days30.rawValue
        hiddenPostsExpiry = HiddenPostsExpiry(rawValue: rawExpiry) ?? .days30

        let rawReadBehaviour = kvStore.string(forKey: Keys.readBehaviour) ?? ReadBehaviour.dim.rawValue
        readBehaviour = ReadBehaviour(rawValue: rawReadBehaviour) ?? .dim

        readerShowImagesByDefault = kvStore.bool(forKey: Keys.readerShowImagesByDefault)

        // kvStore.bool(forKey:) returns false for absent keys; these settings default to true
        safariReaderMode = (kvStore.object(forKey: Keys.safariReaderMode) as? Bool) ?? true
        codeWrapLines = kvStore.bool(forKey: Keys.codeWrapLines)

        showReadLaterBadge = (kvStore.object(forKey: Keys.showReadLaterBadge) as? Bool) ?? true

        let rawTheme = kvStore.string(forKey: Keys.selectedAppTheme) ?? AppThemePreset.standard.rawValue
        selectedAppTheme = AppThemePreset(rawValue: rawTheme) ?? .standard

        customAccentHex = kvStore.string(forKey: Keys.customAccentHex).flatMap { $0.isEmpty ? nil : $0 }

        let rawColorScheme = kvStore.string(forKey: Keys.appColorScheme) ?? AppColorScheme.system.rawValue
        appColorScheme = AppColorScheme(rawValue: rawColorScheme) ?? .system

        // Listen for changes pushed from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] notification in
            self?.applyExternalChanges(notification)
        }
    }
}
