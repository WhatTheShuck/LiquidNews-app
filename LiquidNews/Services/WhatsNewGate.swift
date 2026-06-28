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
}
