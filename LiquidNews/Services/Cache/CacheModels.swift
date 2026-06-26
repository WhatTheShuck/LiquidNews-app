// CacheModels.swift
// Pure value types for the persistent cache and the in-memory index "brain".
// No disk or network here — all logic is unit-testable in isolation.

import Foundation

nonisolated enum CacheKind: String, Codable, Sendable {
    case item, article, feed
}

nonisolated struct CacheKey: Hashable, Codable, Sendable {
    let kind: CacheKind
    let id: String

    static func item(_ id: Int) -> CacheKey { CacheKey(kind: .item, id: String(id)) }
    static func article(_ id: Int) -> CacheKey { CacheKey(kind: .article, id: String(id)) }
    static func feed(_ category: StoryCategory) -> CacheKey { CacheKey(kind: .feed, id: category.rawValue) }

    /// Stable, collision-free dictionary/file key, e.g. "item:123".
    var storageID: String { "\(kind.rawValue):\(id)" }
}

nonisolated enum FillSource: String, Codable, Sendable {
    case readThrough, readLater, backgroundPrefetch, offlineDownload, favourite
}

nonisolated struct CacheEntry: Codable, Sendable {
    let key: CacheKey
    var byteSize: Int
    var fetchedAt: Date
    var lastAccessed: Date
    var accessCount: Int
    var pinned: Bool
    var fillSource: FillSource
}

nonisolated struct CacheIndex: Codable, Sendable {

    /// Keyed by `CacheKey.storageID`.
    private(set) var entries: [String: CacheEntry] = [:]

    var totalBytes: Int { entries.values.reduce(0) { $0 + $1.byteSize } }

    mutating func upsert(key: CacheKey, byteSize: Int, fillSource: FillSource, pinned: Bool, now: Date) {
        if var existing = entries[key.storageID] {
            existing.byteSize = byteSize
            existing.fetchedAt = now
            existing.lastAccessed = now
            existing.fillSource = fillSource
            existing.pinned = pinned || existing.pinned   // never silently un-pin on refresh
            entries[key.storageID] = existing
        } else {
            entries[key.storageID] = CacheEntry(
                key: key, byteSize: byteSize, fetchedAt: now,
                lastAccessed: now, accessCount: 0, pinned: pinned, fillSource: fillSource
            )
        }
    }

    mutating func recordAccess(_ key: CacheKey, now: Date) {
        guard var entry = entries[key.storageID] else { return }
        entry.accessCount += 1
        entry.lastAccessed = now
        entries[key.storageID] = entry
    }

    mutating func setPinned(_ pinned: Bool, for key: CacheKey) {
        guard var entry = entries[key.storageID] else { return }
        entry.pinned = pinned
        entries[key.storageID] = entry
    }

    mutating func remove(_ key: CacheKey) {
        entries.removeValue(forKey: key.storageID)
    }

    /// Returns, in eviction order (least-recently-accessed first), the unpinned keys
    /// that must be removed to bring `totalBytes` under `cap`. Pinned entries are never
    /// returned, even if pinned content alone exceeds the cap.
    func evictionOrder(cap: Int) -> [CacheKey] {
        guard totalBytes > cap else { return [] }
        let unpinned = entries.values
            .filter { !$0.pinned }
            .sorted { $0.lastAccessed < $1.lastAccessed }

        var running = totalBytes
        var toEvict: [CacheKey] = []
        for entry in unpinned where running > cap {
            toEvict.append(entry.key)
            running -= entry.byteSize
        }
        return toEvict
    }
}
