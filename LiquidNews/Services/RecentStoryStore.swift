// RecentStoryStore.swift
// Device-local store of the single most recent story the user opened, used to
// power the "resume where you left off" banner. Mirrors the SavedPostsStore.shared
// singleton pattern, but persists to local UserDefaults (NOT iCloud KV): resume is
// intentionally per-device. Stores the title so the banner renders with no fetch.

import Foundation
import Observation

@Observable
final class RecentStoryStore {

    static let shared = RecentStoryStore()

    private let defaults: UserDefaults
    private let key = "LN_lastStory"

    /// The last story opened on this device, or nil if none / cleared.
    private(set) var lastStory: RecentStory?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(RecentStory.self, from: data) {
            lastStory = decoded
        }
    }

    /// Stores `{ id, title, savedAt: .now }`. No-op when the item has no usable
    /// (non-blank) title — jobs/edge items — so the banner always has text to show.
    func record(_ story: HNItem) {
        guard let title = story.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }
        let recent = RecentStory(id: story.id, title: title, savedAt: .now)
        lastStory = recent
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: key)
        }
    }

    /// Removes the stored story. Wired into SavedPostsStore.clearHistory().
    func clear() {
        lastStory = nil
        defaults.removeObject(forKey: key)
    }
}
