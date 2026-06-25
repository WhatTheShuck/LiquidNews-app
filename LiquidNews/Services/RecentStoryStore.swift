// RecentStoryStore.swift
// Store of the single most recent story the user opened. Writes TWO slots:
//   • local : UserDefaults "LN_lastStory" — authoritative, offline, this device.
//   • cloud : iCloud KV  "LN_lastStory_<installID>" — this install's shared slot,
//             so other devices can offer it as a "continue elsewhere" hint.
// Each install writes ONLY its own cloud slot, so no device clobbers another's
// position. Peers' slots are decoded into `cloudStories` on launch and on
// external change. Mirrors SavedPostsStore's KV-observation pattern.

import Foundation
import Observation

/// Minimal surface of the iCloud key-value store this store needs, so tests can
/// inject an in-memory fake instead of touching the real ubiquitous store.
protocol RecentStoryKVStore: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
    func removeObject(forKey key: String)
    func keys(withPrefix prefix: String) -> [String]
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: RecentStoryKVStore {
    func setData(_ data: Data?, forKey key: String) {
        if let data { set(data, forKey: key) } else { removeObject(forKey: key) }
    }
    func keys(withPrefix prefix: String) -> [String] {
        dictionaryRepresentation.keys.filter { $0.hasPrefix(prefix) }
    }
}

@Observable
final class RecentStoryStore {

    static let shared = RecentStoryStore()

    private let defaults: UserDefaults
    private let kvStore: RecentStoryKVStore

    private let localKey = "LN_lastStory"
    private let cloudPrefix = "LN_lastStory_"
    private let installIDKey = "LN_installID"

    /// Stable per-install id. Names this device's own cloud slot and distinguishes
    /// "this device" from peers. Stored in local UserDefaults; never synced.
    let installID: String

    /// The last story opened on this device, or nil if none / cleared.
    private(set) var lastStory: RecentStory?

    /// Decoded slots written by OTHER installs (peers), refreshed on launch and
    /// on external change. Never includes this install's own slot.
    private(set) var cloudStories: [RecentStory] = []

    private var cloudKey: String { cloudPrefix + installID }

    init(defaults: UserDefaults = .standard,
         kvStore: RecentStoryKVStore = NSUbiquitousKeyValueStore.default,
         installID: String? = nil) {
        self.defaults = defaults
        self.kvStore = kvStore
        self.installID = installID ?? Self.resolveInstallID(defaults: defaults, key: installIDKey)

        if let data = defaults.data(forKey: localKey),
           let decoded = try? JSONDecoder().decode(RecentStory.self, from: data) {
            lastStory = decoded
        }
        reloadCloudStories()

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reloadCloudStories() }
    }

    private static func resolveInstallID(defaults: UserDefaults, key: String) -> String {
        if let existing = defaults.string(forKey: key) { return existing }
        let new = UUID().uuidString
        defaults.set(new, forKey: key)
        return new
    }

    /// Stores `{ id, title, savedAt: .now, installID, deviceKind }` to the local
    /// slot and this install's own cloud slot. No-op without a usable title.
    func record(_ story: HNItem) {
        guard let title = story.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }
        let recent = RecentStory(id: story.id, title: title, savedAt: .now,
                                 installID: installID, deviceKind: .current)
        lastStory = recent
        guard let data = try? JSONEncoder().encode(recent) else { return }
        defaults.set(data, forKey: localKey)
        kvStore.setData(data, forKey: cloudKey)
        kvStore.synchronize()
    }

    /// Re-decodes peers' cloud slots (every `LN_lastStory_*` key except this
    /// install's). Cheap; safe to call on launch and on every external change.
    func reloadCloudStories() {
        let decoder = JSONDecoder()
        cloudStories = kvStore.keys(withPrefix: cloudPrefix)
            .filter { $0 != cloudKey }
            .compactMap { kvStore.data(forKey: $0) }
            .compactMap { try? decoder.decode(RecentStory.self, from: $0) }
            .filter { $0.installID != installID }
    }

    /// Removes the local slot and THIS install's cloud slot only. Peers' slots
    /// are left intact — we must not wipe another device's position.
    func clear() {
        lastStory = nil
        defaults.removeObject(forKey: localKey)
        kvStore.removeObject(forKey: cloudKey)
        kvStore.synchronize()
    }
}
