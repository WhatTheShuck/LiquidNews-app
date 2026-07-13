// Log.swift
// Central `os.Logger` categories for the app. Replaces ad-hoc `print()` calls so
// diagnostics are filterable in Console.app / `log stream` and are automatically
// omitted from release builds by the unified logging system (unlike raw `print`,
// which ships to stdout in release).

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "LiquidNews"

    /// Reader-mode extraction and WKWebView pipeline.
    static let reader = Logger(subsystem: subsystem, category: "reader")
    /// StoreKit product loading and transaction handling.
    static let store = Logger(subsystem: subsystem, category: "store")
    /// iCloud saved-posts merge/export.
    static let sync = Logger(subsystem: subsystem, category: "sync")
    /// Alternate app-icon swapping.
    static let appIcon = Logger(subsystem: subsystem, category: "appIcon")
    /// Feed loading and pagination.
    static let feed = Logger(subsystem: subsystem, category: "feed")
    /// Keychain reads/writes.
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    /// HN HTML-scrape breakage signal (see `HNScrapeLog`).
    static let hnMarkup = Logger(subsystem: subsystem, category: "hn-markup")
}
