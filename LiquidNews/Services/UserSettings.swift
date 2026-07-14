// UserSettings.swift
// User-configurable preferences, backed by NSUbiquitousKeyValueStore (iCloud KV sync).
//
// @Observable so SwiftUI views re-render when settings change.
// Accessed globally via UserSettings.shared.

import Foundation
import Observation
import SwiftUI

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

// MARK: - iPad reader layout

enum IPadReaderLayout: String, CaseIterable, Identifiable, SettingsSegmentOption {
    case sideBySide
    case replace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sideBySide: return "Side by Side"
        case .replace:    return "Replace"
        }
    }

    var subtitle: String {
        switch self {
        case .sideBySide: return "Show the article beside its comments"
        case .replace:    return "Article replaces the comments column"
        }
    }

    var systemImage: String {
        switch self {
        case .sideBySide: return "rectangle.split.2x1"
        case .replace:    return "rectangle"
        }
    }
}

// MARK: - Resume last story

enum ResumeMode: String, CaseIterable, Identifiable {
    case off     // never resume
    case prompt  // show a dismissable banner (default)
    case auto    // reopen immediately on launch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:    "Off"
        case .prompt: "Ask"
        case .auto:   "Reopen"
        }
    }

    var subtitle: String {
        switch self {
        case .off:    "Never resume your last story"
        case .prompt: "Offer to resume your last story on launch"
        case .auto:   "Reopen your last story automatically on launch"
        }
    }

    var systemImage: String {
        switch self {
        case .off:    "xmark"
        case .prompt: "questionmark.circle"
        case .auto:   "arrow.clockwise"
        }
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

// MARK: - Custom background

/// What replaces the theme preset's background gradient. `.none` means the
/// preset gradient renders as usual.
enum CustomBackgroundKind: String, CaseIterable {
    case none
    case solid
    case gradient
    case image
}

// MARK: - Feed entrance animation

/// How feed story cards animate in on load events (initial load, category
/// switch, pull-to-refresh). Rows realised later by scrolling never animate.
enum FeedEntranceStyle: String, CaseIterable, Identifiable {
    case off      = "off"
    case fade     = "fade"
    case drip     = "drip"
    case condense = "condense"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:      return "Off"
        case .fade:     return "Fade In"
        case .drip:     return "Liquid Drip"
        case .condense: return "Condense"
        }
    }

    var subtitle: String {
        switch self {
        case .off:      return "Cards appear instantly"
        case .fade:     return "Cards fade in from the top"
        case .drip:     return "Each card pours from the one above"
        case .condense: return "Cards sharpen into focus"
        }
    }

    var systemImage: String {
        switch self {
        case .off:      return "minus.circle"
        case .fade:     return "circle.dashed"
        case .drip:     return "drop"
        case .condense: return "sparkles"
        }
    }
}

@Observable
final class UserSettings {

    static let shared = UserSettings()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private static let migrationKey = "LN_kv_migrated"

    /// True while `applyExternalChanges(_:)` is assigning values that just arrived
    /// from iCloud. Property `didSet`s consult this via `persist` so they don't
    /// echo the just-read value straight back into the KV store.
    private var isApplyingExternalChanges = false

    /// Runs a KV-store write unless we're mid-`applyExternalChanges`, in which case
    /// the value already came from the store and re-writing it is wasteful churn.
    private func persist(_ write: () -> Void) {
        guard !isApplyingExternalChanges else { return }
        write()
    }

    // MARK: - Comment expansion

    /// How many replies to auto-load per comment (0 = never, loads on tap only).
    /// HN's own website shows all replies inline, but that's impractical on mobile.
    /// Default of 3 balances context vs. scroll fatigue.
    var autoLoadReplyCount: Int {
        didSet { persist { kvStore.set(autoLoadReplyCount, forKey: Keys.autoLoadReplyCount) } }
    }

    /// Maximum nesting depth at which replies auto-load.
    /// Depth 0 = top-level comments, 1 = direct replies, etc.
    /// Beyond this depth, replies require a manual tap to load.
    /// Default of 2 keeps threads readable without infinite nesting.
    var maxAutoExpandDepth: Int {
        didSet { persist { kvStore.set(maxAutoExpandDepth, forKey: Keys.maxAutoExpandDepth) } }
    }

    /// Max concurrent comment fetches on WiFi. Higher = faster load, more bandwidth.
    var maxConcurrentFetchesWifi: Int {
        didSet { persist { kvStore.set(maxConcurrentFetchesWifi, forKey: Keys.maxConcurrentFetchesWifi) } }
    }

    /// Max concurrent comment fetches on cellular. Lower = less data usage and more
    /// reliable loads on poor connections.
    var maxConcurrentFetchesCellular: Int {
        didSet { persist { kvStore.set(maxConcurrentFetchesCellular, forKey: Keys.maxConcurrentFetchesCellular) } }
    }

    // MARK: - Comment rendering

    /// Global default for how comment text is rendered.
    /// Can be overridden per-comment from the long-press context menu.
    var commentRenderingStyle: CommentRenderMode {
        didSet { persist { kvStore.set(commentRenderingStyle.rawValue, forKey: Keys.commentRenderingStyle) } }
    }


    // MARK: - Tab bar

    /// Which optional tabs appear in the bottom pill. Feed is always shown and not stored here.
    var enabledOptionalTabs: Set<AppTab> {
        didSet { persist { kvStore.set(enabledOptionalTabs.map(\.rawValue), forKey: Keys.enabledOptionalTabs) } }
    }

    /// Display order of all optional tabs. All five are always present here;
    /// whether each is visible is controlled by `enabledOptionalTabs`.
    var tabOrder: [AppTab] {
        didSet { persist { kvStore.set(tabOrder.map(\.rawValue), forKey: Keys.tabOrder) } }
    }

    // MARK: - Feed categories

    /// Display order of all known feed categories (enabled and disabled).
    var feedCategoryOrder: [StoryCategory] {
        didSet { persist { kvStore.set(feedCategoryOrder.map(\.rawValue), forKey: Keys.feedCategoryOrder) } }
    }

    /// Which feed categories the user has switched on.
    /// At least one is always kept enabled.
    var enabledFeedCategories: Set<StoryCategory> {
        didSet { persist { kvStore.set(Array(enabledFeedCategories.map(\.rawValue)), forKey: Keys.enabledFeedCategories) } }
    }

    /// Enabled categories in user-defined display order (used by the chip picker).
    var orderedEnabledCategories: [StoryCategory] {
        feedCategoryOrder.filter { enabledFeedCategories.contains($0) }
    }

    /// How feed story cards animate in on load events.
    var feedEntranceStyle: FeedEntranceStyle {
        didSet { persist { kvStore.set(feedEntranceStyle.rawValue, forKey: Keys.feedEntranceStyle) } }
    }

    // MARK: - Link opening

    /// How article links open by default. Users can one-off override via long-press.
    var defaultLinkOpen: LinkOpenMode {
        didSet { persist { kvStore.set(defaultLinkOpen.rawValue, forKey: Keys.defaultLinkOpen) } }
    }

    // MARK: - Inline link modes

    /// How links tapped inside comment text open.
    var commentLinkOpen: CommentLinkMode {
        didSet { persist { kvStore.set(commentLinkOpen.rawValue, forKey: Keys.commentLinkOpen) } }
    }

    /// How links tapped inside reader views open.
    var readerLinkOpen: ReaderLinkMode {
        didSet { persist { kvStore.set(readerLinkOpen.rawValue, forKey: Keys.readerLinkOpen) } }
    }

    /// How links to other HN threads open when tapped inside comments or the reader.
    var hnThreadLinkOpen: HNLinkMode {
        didSet { persist { kvStore.set(hnThreadLinkOpen.rawValue, forKey: Keys.hnThreadLinkOpen) } }
    }

    // MARK: - Tap + swipe actions

    /// What happens when the user taps a story card.
    var tapAction: StoryAction {
        didSet { persist { kvStore.set(tapAction.rawValue, forKey: Keys.tapAction) } }
    }

    /// Action triggered when swiping a story card left (trailing edge).
    var swipeLeftAction: StoryAction {
        didSet { persist { kvStore.set(swipeLeftAction.rawValue, forKey: Keys.swipeLeftAction) } }
    }

    /// Action triggered when swiping a story card right (leading edge).
    var swipeRightAction: StoryAction {
        didSet { persist { kvStore.set(swipeRightAction.rawValue, forKey: Keys.swipeRightAction) } }
    }

    // MARK: - Hidden posts expiry

    /// How long to retain hidden post entries before auto-clearing them.
    var hiddenPostsExpiry: HiddenPostsExpiry {
        didSet { persist { kvStore.set(hiddenPostsExpiry.rawValue, forKey: Keys.hiddenPostsExpiry) } }
    }

    /// What happens to a story in feeds after the user opens it.
    var readBehaviour: ReadBehaviour {
        didSet { persist { kvStore.set(readBehaviour.rawValue, forKey: Keys.readBehaviour) } }
    }

    // MARK: - Reader

    /// When true, images are fetched and shown in Reader mode by default.
    /// Can still be toggled per-article from the reader's ellipsis menu.
    var readerShowImagesByDefault: Bool {
        didSet { persist { kvStore.set(readerShowImagesByDefault, forKey: Keys.readerShowImagesByDefault) } }
    }

    /// When true, SFSafariViewController will attempt to enter Safari Reader Mode automatically.
    var safariReaderMode: Bool {
        didSet { persist { kvStore.set(safariReaderMode, forKey: Keys.safariReaderMode) } }
    }

    /// When true, code blocks in comments wrap long lines instead of scrolling horizontally.
    var codeWrapLines: Bool {
        didSet { persist { kvStore.set(codeWrapLines, forKey: Keys.codeWrapLines) } }
    }

    /// When true (default), comment cards use a live Liquid Glass surface instead of
    /// the fixed ultraThinMaterial blur. Only depth-0 cards carry live glass — nested
    /// cards are tinted panels, and very tall cards fall back to material — so busy
    /// threads stay artifact-free (see CommentCardBackground).
    var glassComments: Bool {
        didSet { persist { kvStore.set(glassComments, forKey: Keys.glassComments) } }
    }

    /// When true, a random goofy quote is shown on the reader loading screen.
    var wordsOfWisdom: Bool {
        didSet { persist { kvStore.set(wordsOfWisdom, forKey: Keys.wordsOfWisdom) } }
    }

    /// How the reader presents on iPad (regular width). `.sideBySide` shows the
    /// article beside its comments; `.replace` swaps the detail column to the reader.
    /// Ignored on iPhone (compact), which always uses the reader sheet.
    var iPadReaderLayout: IPadReaderLayout {
        didSet { persist { kvStore.set(iPadReaderLayout.rawValue, forKey: Keys.iPadReaderLayout) } }
    }

    // MARK: - Read Later

    /// When true, a count badge appears on the Read Later tab.
    var showReadLaterBadge: Bool {
        didSet { persist { kvStore.set(showReadLaterBadge, forKey: Keys.showReadLaterBadge) } }
    }

    // MARK: - App Theme

    var selectedAppTheme: AppThemePreset {
        didSet { persist { kvStore.set(selectedAppTheme.rawValue, forKey: Keys.selectedAppTheme) } }
    }

    /// Custom accent color stored as a 6-char lowercase hex string, or nil for the preset default.
    var customAccentHex: String? {
        didSet {
            persist {
                if let hex = customAccentHex {
                    kvStore.set(hex, forKey: Keys.customAccentHex)
                } else {
                    kvStore.removeObject(forKey: Keys.customAccentHex)
                }
            }
        }
    }

    /// Custom background override — replaces the preset gradient when not `.none`.
    var customBackgroundKind: CustomBackgroundKind {
        didSet { persist { kvStore.set(customBackgroundKind.rawValue, forKey: Keys.customBackgroundKind) } }
    }

    /// Hexes for the custom background: 1 entry for `.solid`, 2–3 for `.gradient`.
    var customBackgroundHexes: [String] {
        didSet { persist { kvStore.set(customBackgroundHexes, forKey: Keys.customBackgroundHexes) } }
    }

    /// Scrim opacity over a custom background photo (0…0.8).
    var customBackgroundDim: Double {
        didSet { persist { kvStore.set(customBackgroundDim, forKey: Keys.customBackgroundDim) } }
    }

    /// Blur radius in points over a custom background photo (0…20).
    var customBackgroundBlur: Double {
        didSet { persist { kvStore.set(customBackgroundBlur, forKey: Keys.customBackgroundBlur) } }
    }

    /// UUID bumped on each new photo pick. Identity for the decoded-image cache.
    /// The image file itself never syncs (iCloud KVS 1 MB cap) — a device with
    /// this set but no file falls back to the preset gradient.
    var customBackgroundImageRevision: String? {
        didSet {
            persist {
                if let rev = customBackgroundImageRevision {
                    kvStore.set(rev, forKey: Keys.customBackgroundImageRevision)
                } else {
                    kvStore.removeObject(forKey: Keys.customBackgroundImageRevision)
                }
            }
        }
    }

    // MARK: - Color scheme override

    var appColorScheme: AppColorScheme {
        didSet { persist { kvStore.set(appColorScheme.rawValue, forKey: Keys.appColorScheme) } }
    }

    // MARK: - Resume last story

    /// How the app resumes the last opened story on cold launch. Only read at
    /// launch — changing it has no live effect this session.
    var resumeMode: ResumeMode {
        didSet { persist { kvStore.set(resumeMode.rawValue, forKey: Keys.resumeMode) } }
    }

    // MARK: - Curated sources

    /// When true, the "loading may take a moment" banner is permanently hidden.
    var hideCuratedLoadingBanner: Bool {
        didSet { persist { kvStore.set(hideCuratedLoadingBanner, forKey: Keys.hideCuratedLoadingBanner) } }
    }

    /// Which built-in curated sources are enabled (stored by rawValue).
    var enabledBuiltInCuratedSources: Set<String> {
        didSet {
            persist { kvStore.set(Array(enabledBuiltInCuratedSources), forKey: Keys.enabledBuiltInCuratedSources) }
        }
    }

    /// User-added custom curated feed URLs.
    var customCuratedFeeds: [CustomCuratedFeed] {
        didSet {
            persist {
                if let data = try? JSONEncoder().encode(customCuratedFeeds) {
                    kvStore.set(data, forKey: Keys.customCuratedFeeds)
                }
            }
        }
    }

    // MARK: - Cache & offline

    /// Cache size cap in megabytes. Mirrored into DiskCache on change.
    var cacheSizeCapMB: Int {
        didSet {
            persist { kvStore.set(cacheSizeCapMB, forKey: Keys.cacheSizeCapMB) }
            Task { await DiskCache.shared.setSizeCap(cacheSizeCapMB * 1024 * 1024) }
        }
    }

    /// When true, enabled feeds are refreshed + their items prefetched on launch/foreground (WiFi only).
    var backgroundFeedPrefetch: Bool {
        didSet { persist { kvStore.set(backgroundFeedPrefetch, forKey: Keys.backgroundFeedPrefetch) } }
    }

    /// Sub-toggle: also extract + cache article bodies during background prefetch (heavier).
    var backgroundPrefetchArticles: Bool {
        didSet { persist { kvStore.set(backgroundPrefetchArticles, forKey: Keys.backgroundPrefetchArticles) } }
    }

    /// Remembered feed selection for the "Prepare for offline" sheet.
    var offlineDownloadCategories: [StoryCategory] {
        didSet { persist { kvStore.set(offlineDownloadCategories.map(\.rawValue), forKey: Keys.offlineDownloadCategories) } }
    }

    /// Remembered download depth (stories per feed) for "Prepare for offline".
    var offlineDownloadDepth: Int {
        didSet { persist { kvStore.set(offlineDownloadDepth, forKey: Keys.offlineDownloadDepth) } }
    }

    /// "Frequent Flyer": surfaces a one-tap airplane shortcut in the feed toolbar that
    /// opens Prepare-for-offline, for travellers who download often.
    var frequentFlyerEnabled: Bool {
        didSet { persist { kvStore.set(frequentFlyerEnabled, forKey: Keys.frequentFlyerEnabled) } }
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
        static let feedEntranceStyle            = "LN_feedEntranceStyle"
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
        static let glassComments                = "LN_glassComments"
        static let wordsOfWisdom                = "LN_wordsOfWisdom"
        static let iPadReaderLayout             = "LN_iPadReaderLayout"
        static let showReadLaterBadge           = "LN_showReadLaterBadge"
        static let selectedAppTheme             = "LN_selectedAppTheme"
        static let customAccentHex              = "LN_customAccentHex"
        static let customBackgroundKind          = "LN_customBackgroundKind"
        static let customBackgroundHexes         = "LN_customBackgroundHexes"
        static let customBackgroundDim           = "LN_customBackgroundDim"
        static let customBackgroundBlur          = "LN_customBackgroundBlur"
        static let customBackgroundImageRevision = "LN_customBackgroundImageRevision"
        static let appColorScheme               = "LN_appColorScheme"
        static let resumeMode                   = "LN_resumeMode"
        static let cacheSizeCapMB             = "LN_cacheSizeCapMB"
        static let backgroundFeedPrefetch     = "LN_backgroundFeedPrefetch"
        static let backgroundPrefetchArticles = "LN_backgroundPrefetchArticles"
        static let offlineDownloadCategories  = "LN_offlineDownloadCategories"
        static let offlineDownloadDepth        = "LN_offlineDownloadDepth"
        static let frequentFlyerEnabled        = "LN_frequentFlyerEnabled"
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
        // Must list every persisted key: any key absent here is silently dropped on
        // upgrade (the user's old UserDefaults value is never copied into the KV store).
        // Keep this in sync with `Keys` — DESLOPPIFY M1.
        let allKeys: [String] = [
            Keys.autoLoadReplyCount, Keys.maxAutoExpandDepth,
            Keys.maxConcurrentFetchesWifi, Keys.maxConcurrentFetchesCellular,
            Keys.enabledOptionalTabs, Keys.tabOrder,
            Keys.commentRenderingStyle, Keys.hideCuratedLoadingBanner,
            Keys.enabledBuiltInCuratedSources, Keys.customCuratedFeeds,
            Keys.feedCategoryOrder, Keys.enabledFeedCategories, Keys.feedEntranceStyle,
            Keys.tapAction, Keys.swipeLeftAction, Keys.swipeRightAction,
            Keys.defaultLinkOpen, Keys.commentLinkOpen, Keys.readerLinkOpen,
            Keys.hnThreadLinkOpen,
            Keys.hiddenPostsExpiry, Keys.readBehaviour,
            Keys.readerShowImagesByDefault, Keys.safariReaderMode, Keys.codeWrapLines,
            Keys.glassComments, Keys.wordsOfWisdom, Keys.iPadReaderLayout,
            Keys.showReadLaterBadge,
            Keys.selectedAppTheme, Keys.customAccentHex, Keys.appColorScheme,
            Keys.customBackgroundKind, Keys.customBackgroundHexes,
            Keys.customBackgroundDim, Keys.customBackgroundBlur,
            Keys.customBackgroundImageRevision,
            Keys.resumeMode,
            Keys.cacheSizeCapMB, Keys.backgroundFeedPrefetch, Keys.backgroundPrefetchArticles,
            Keys.offlineDownloadCategories, Keys.offlineDownloadDepth, Keys.frequentFlyerEnabled,
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
        isApplyingExternalChanges = true
        defer { isApplyingExternalChanges = false }
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
            case Keys.feedEntranceStyle:
                feedEntranceStyle = FeedEntranceStyle(rawValue: kvStore.string(forKey: key) ?? "") ?? .drip
            case Keys.tapAction:
                tapAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .openComments
            case Keys.swipeLeftAction:
                swipeLeftAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .favourite
            case Keys.swipeRightAction:
                swipeRightAction = StoryAction(rawValue: kvStore.string(forKey: key) ?? "") ?? .saveLater
            case Keys.defaultLinkOpen:
                let raw = kvStore.string(forKey: key) ?? ""
                let migrated = raw == "browser" ? LinkOpenMode.inAppSafari.rawValue : raw
                defaultLinkOpen = LinkOpenMode(rawValue: migrated) ?? .reader
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
                readerShowImagesByDefault = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.safariReaderMode:
                safariReaderMode = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.codeWrapLines:
                codeWrapLines = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.glassComments:
                glassComments = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.wordsOfWisdom:
                wordsOfWisdom = kvStore.bool(forKey: key)
            case Keys.iPadReaderLayout:
                iPadReaderLayout = IPadReaderLayout(rawValue: kvStore.string(forKey: key) ?? "") ?? .sideBySide
            case Keys.showReadLaterBadge:
                // kvStore.bool(forKey:) returns false for absent keys; this setting defaults to true
                showReadLaterBadge = (kvStore.object(forKey: key) as? Bool) ?? true
            case Keys.selectedAppTheme:
                selectedAppTheme = AppThemePreset(rawValue: kvStore.string(forKey: key) ?? "") ?? .standard
            case Keys.customAccentHex:
                customAccentHex = kvStore.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 }
            case Keys.customBackgroundKind:
                customBackgroundKind = CustomBackgroundKind(rawValue: kvStore.string(forKey: key) ?? "") ?? .none
            case Keys.customBackgroundHexes:
                customBackgroundHexes = (kvStore.array(forKey: key) as? [String]) ?? []
            case Keys.customBackgroundDim:
                customBackgroundDim = (kvStore.object(forKey: key) as? Double) ?? 0.35
            case Keys.customBackgroundBlur:
                customBackgroundBlur = (kvStore.object(forKey: key) as? Double) ?? 0
            case Keys.customBackgroundImageRevision:
                customBackgroundImageRevision = kvStore.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 }
            case Keys.appColorScheme:
                appColorScheme = AppColorScheme(rawValue: kvStore.string(forKey: key) ?? "") ?? .system
            case Keys.resumeMode:
                resumeMode = ResumeMode(rawValue: kvStore.string(forKey: key) ?? "") ?? .prompt
            case Keys.cacheSizeCapMB:
                cacheSizeCapMB = (kvStore.object(forKey: key) as? Int) ?? 150
            case Keys.backgroundFeedPrefetch:
                backgroundFeedPrefetch = kvStore.bool(forKey: key)
            case Keys.backgroundPrefetchArticles:
                backgroundPrefetchArticles = kvStore.bool(forKey: key)
            case Keys.offlineDownloadCategories:
                let raw = (kvStore.array(forKey: key) as? [String]) ?? StoryCategory.defaults.map(\.rawValue)
                offlineDownloadCategories = raw.compactMap(StoryCategory.init(rawValue:))
            case Keys.offlineDownloadDepth:
                offlineDownloadDepth = (kvStore.object(forKey: key) as? Int) ?? 50
            case Keys.frequentFlyerEnabled:
                frequentFlyerEnabled = kvStore.bool(forKey: key)
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

        let rawEntranceStyle = kvStore.string(forKey: Keys.feedEntranceStyle) ?? FeedEntranceStyle.drip.rawValue
        feedEntranceStyle = FeedEntranceStyle(rawValue: rawEntranceStyle) ?? .drip

        let rawTap = kvStore.string(forKey: Keys.tapAction) ?? StoryAction.openComments.rawValue
        tapAction = StoryAction(rawValue: rawTap) ?? .openComments

        let rawSwipeLeft = kvStore.string(forKey: Keys.swipeLeftAction) ?? StoryAction.favourite.rawValue
        swipeLeftAction = StoryAction(rawValue: rawSwipeLeft) ?? .favourite

        let rawSwipeRight = kvStore.string(forKey: Keys.swipeRightAction) ?? StoryAction.saveLater.rawValue
        swipeRightAction = StoryAction(rawValue: rawSwipeRight) ?? .saveLater

        let rawLinkOpen = kvStore.string(forKey: Keys.defaultLinkOpen) ?? LinkOpenMode.reader.rawValue
        let migratedLinkOpen = rawLinkOpen == "browser" ? LinkOpenMode.inAppSafari.rawValue : rawLinkOpen
        defaultLinkOpen = LinkOpenMode(rawValue: migratedLinkOpen) ?? .reader
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

        // kvStore.bool(forKey:) returns false for absent keys; these settings default to true
        readerShowImagesByDefault = (kvStore.object(forKey: Keys.readerShowImagesByDefault) as? Bool) ?? true
        safariReaderMode = (kvStore.object(forKey: Keys.safariReaderMode) as? Bool) ?? true
        codeWrapLines = (kvStore.object(forKey: Keys.codeWrapLines) as? Bool) ?? true
        glassComments = (kvStore.object(forKey: Keys.glassComments) as? Bool) ?? true
        wordsOfWisdom = kvStore.bool(forKey: Keys.wordsOfWisdom)

        let rawIPadReaderLayout = kvStore.string(forKey: Keys.iPadReaderLayout) ?? IPadReaderLayout.sideBySide.rawValue
        iPadReaderLayout = IPadReaderLayout(rawValue: rawIPadReaderLayout) ?? .sideBySide

        showReadLaterBadge = (kvStore.object(forKey: Keys.showReadLaterBadge) as? Bool) ?? true

        let rawTheme = kvStore.string(forKey: Keys.selectedAppTheme) ?? AppThemePreset.standard.rawValue
        selectedAppTheme = AppThemePreset(rawValue: rawTheme) ?? .standard

        customAccentHex = kvStore.string(forKey: Keys.customAccentHex).flatMap { $0.isEmpty ? nil : $0 }

        let rawBackgroundKind = kvStore.string(forKey: Keys.customBackgroundKind) ?? CustomBackgroundKind.none.rawValue
        customBackgroundKind = CustomBackgroundKind(rawValue: rawBackgroundKind) ?? .none
        customBackgroundHexes = (kvStore.array(forKey: Keys.customBackgroundHexes) as? [String]) ?? []
        customBackgroundDim = (kvStore.object(forKey: Keys.customBackgroundDim) as? Double) ?? 0.35
        customBackgroundBlur = (kvStore.object(forKey: Keys.customBackgroundBlur) as? Double) ?? 0
        customBackgroundImageRevision = kvStore.string(forKey: Keys.customBackgroundImageRevision).flatMap { $0.isEmpty ? nil : $0 }

        let rawColorScheme = kvStore.string(forKey: Keys.appColorScheme) ?? AppColorScheme.system.rawValue
        appColorScheme = AppColorScheme(rawValue: rawColorScheme) ?? .system

        let rawResumeMode = kvStore.string(forKey: Keys.resumeMode) ?? ResumeMode.prompt.rawValue
        resumeMode = ResumeMode(rawValue: rawResumeMode) ?? .prompt

        cacheSizeCapMB = (kvStore.object(forKey: Keys.cacheSizeCapMB) as? Int) ?? 150
        backgroundFeedPrefetch = kvStore.bool(forKey: Keys.backgroundFeedPrefetch)
        backgroundPrefetchArticles = kvStore.bool(forKey: Keys.backgroundPrefetchArticles)
        let rawOfflineCats = (kvStore.array(forKey: Keys.offlineDownloadCategories) as? [String])
            ?? StoryCategory.defaults.map(\.rawValue)
        offlineDownloadCategories = rawOfflineCats.compactMap(StoryCategory.init(rawValue:))
        offlineDownloadDepth = (kvStore.object(forKey: Keys.offlineDownloadDepth) as? Int) ?? 50
        frequentFlyerEnabled = kvStore.bool(forKey: Keys.frequentFlyerEnabled)

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
