// UserSettings.swift
// User-configurable preferences, backed by UserDefaults.
//
// @Observable so SwiftUI views re-render when settings change.
// Accessed globally via UserSettings.shared.

import Foundation
import Observation

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

    // MARK: - Init

    private enum Keys {
        static let autoLoadReplyCount  = "LN_autoLoadReplyCount"
        static let maxAutoExpandDepth  = "LN_maxAutoExpandDepth"
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register sensible defaults for first launch
        defaults.register(defaults: [
            Keys.autoLoadReplyCount: 3,
            Keys.maxAutoExpandDepth: 2,
        ])

        autoLoadReplyCount = defaults.integer(forKey: Keys.autoLoadReplyCount)
        maxAutoExpandDepth = defaults.integer(forKey: Keys.maxAutoExpandDepth)
    }
}
