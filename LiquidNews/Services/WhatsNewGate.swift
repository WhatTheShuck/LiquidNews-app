// WhatsNewGate.swift
// Pure decision for whether to present the version-gated What's New sheet.
// Extracted from any view so it is unit-testable.

import Foundation

enum WhatsNewGate {
    /// Show What's New only to existing users (onboarding already seen) whose last
    /// seen What's New version is older than the current bundle version. Comparison
    /// is numeric so "1.9" < "1.10". An empty stored version counts as older.
    static func shouldShow(storedVersion: String,
                           currentVersion: String,
                           hasSeenOnboarding: Bool) -> Bool {
        guard hasSeenOnboarding else { return false }
        if storedVersion.isEmpty { return true }
        return storedVersion.compare(currentVersion, options: .numeric) == .orderedAscending
    }

    /// Coach marks must stay hidden while the onboarding or version-gated What's
    /// New sheet covers the screen at launch — otherwise a hint could activate
    /// (and auto-fade, burning its "seen" flag) behind the sheet, unseen.
    static func coachMarksSuppressed(storedWhatsNewVersion: String,
                                     hasSeenOnboarding: Bool,
                                     currentVersion: String = appShortVersion) -> Bool {
        !hasSeenOnboarding
            || shouldShow(storedVersion: storedWhatsNewVersion,
                          currentVersion: currentVersion,
                          hasSeenOnboarding: hasSeenOnboarding)
    }

    /// Current bundle short version, defaulting to "1.0" if absent.
    static var appShortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
