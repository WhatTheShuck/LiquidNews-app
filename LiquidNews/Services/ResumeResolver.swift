// ResumeResolver.swift
// Pure resolution of the single subordinate "continue elsewhere" hint shown
// beneath the local resume primary, plus the snapshot→display mapping. Kept
// view- and store-free so the rules are exhaustively unit-testable.

import Foundation

enum ResumeResolver {

    /// 7 days, in seconds — the freshness window for an other-device hint.
    private static let freshnessWindow: TimeInterval = 7 * 24 * 60 * 60

    /// The single hint to show beneath the local primary, or nil.
    /// nil when there is no local primary, or no cloud entry is a different
    /// install, a different story, and still fresh.
    ///
    /// Note: there is deliberately no "already read" suppression. Read state
    /// (`SavedPostsStore.readIDs`) syncs across devices, so the very act of
    /// opening a story on another device — which is exactly what makes it a hint
    /// candidate — would mark it read everywhere and suppress the hint on every
    /// device. The `id != local.id` dedup and freshness window are the guards.
    static func hint(local: RecentStory?,
                     cloud: [RecentStory],
                     thisInstallID: String,
                     now: Date) -> ResumeEntry? {
        guard let local else { return nil }
        let candidate = cloud
            .filter { $0.installID != thisInstallID }
            .filter { $0.id != local.id }
            .filter { now.timeIntervalSince($0.savedAt) <= freshnessWindow }
            .max(by: { $0.savedAt < $1.savedAt })
        guard let candidate else { return nil }
        return entry(from: candidate, isThisDevice: false)
    }

    /// Maps a stored snapshot to the banner's display model.
    static func entry(from story: RecentStory, isThisDevice: Bool) -> ResumeEntry {
        let kind = story.deviceKind ?? .other
        return ResumeEntry(
            id: story.id,
            title: story.title,
            savedAt: story.savedAt,
            isThisDevice: isThisDevice,
            deviceName: kind.label,
            deviceSymbol: kind.symbol
        )
    }
}
