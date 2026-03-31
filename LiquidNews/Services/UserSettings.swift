// UserSettings.swift
// User-configurable preferences, backed by UserDefaults.
//
// @Observable so SwiftUI views re-render when settings change.
// Accessed globally via UserSettings.shared.

import Foundation
import Observation
import SwiftUI

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

    // MARK: - Curated sources

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
        static let enabledBuiltInCuratedSources = "LN_enabledBuiltInCuratedSources"
        static let customCuratedFeeds           = "LN_customCuratedFeeds"
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

        if let data = defaults.data(forKey: Keys.customCuratedFeeds),
           let feeds = try? JSONDecoder().decode([CustomCuratedFeed].self, from: data) {
            customCuratedFeeds = feeds
        } else {
            customCuratedFeeds = []
        }
    }
}
