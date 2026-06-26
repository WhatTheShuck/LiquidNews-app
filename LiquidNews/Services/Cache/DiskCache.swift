// DiskCache.swift
// HN-agnostic, actor-isolated blob store with a persisted index, LRU eviction,
// and pinning. Stores opaque Data; callers decide encoding. Lives under
// Application Support (never the system Caches dir, which the OS may purge).

import Foundation

struct CacheUsage: Equatable, Sendable {
    let totalBytes: Int
    let itemBytes: Int
    let articleBytes: Int
    let pinnedBytes: Int
}

actor DiskCache {

    static let shared = DiskCache(
        directory: DiskCache.defaultDirectory,
        sizeCap: 150 * 1024 * 1024
    )

    private let directory: URL
    private var sizeCap: Int
    private var index: CacheIndex

    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private func blobURL(for key: CacheKey) -> URL {
        directory
            .appendingPathComponent(key.kind.rawValue, isDirectory: true)
            .appendingPathComponent(key.id)
    }

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LiquidNews/Cache", isDirectory: true)
    }

    init(directory: URL, sizeCap: Int) {
        self.directory = directory
        self.sizeCap = sizeCap
        // Ensure per-kind subdirectories exist.
        for kind in [CacheKind.item, .article, .feed] {
            try? FileManager.default.createDirectory(
                at: directory.appendingPathComponent(kind.rawValue, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        self.index = DiskCache.loadIndex(from: directory) ?? DiskCache.rebuildIndex(from: directory)
    }

    // MARK: - Public API

    func store(_ data: Data, for key: CacheKey, fillSource: FillSource, pinned: Bool) throws {
        try data.write(to: blobURL(for: key), options: .atomic)
        index.upsert(key: key, byteSize: data.count, fillSource: fillSource, pinned: pinned, now: Date())
        enforceCap()
        persistIndex()
    }

    func data(for key: CacheKey) -> Data? {
        guard let data = try? Data(contentsOf: blobURL(for: key)) else { return nil }
        index.recordAccess(key, now: Date())
        persistIndex()
        return data
    }

    func contains(_ key: CacheKey) -> Bool {
        index.entries[key.storageID] != nil
    }

    func remove(_ key: CacheKey) {
        try? FileManager.default.removeItem(at: blobURL(for: key))
        index.remove(key)
        persistIndex()
    }

    func setPinned(_ pinned: Bool, for key: CacheKey) {
        index.setPinned(pinned, for: key)
        persistIndex()
    }

    func clearUnpinned() {
        for entry in index.entries.values where !entry.pinned {
            try? FileManager.default.removeItem(at: blobURL(for: entry.key))
            index.remove(entry.key)
        }
        persistIndex()
    }

    func usage() -> CacheUsage {
        var item = 0, article = 0, pinned = 0
        for entry in index.entries.values {
            switch entry.key.kind {
            case .item, .feed: item += entry.byteSize   // feed ID-lists are tiny; group them with items
            case .article:     article += entry.byteSize
            }
            if entry.pinned { pinned += entry.byteSize }
        }
        // itemBytes (items + feeds) + articleBytes == totalBytes, so the Settings breakdown reconciles.
        return CacheUsage(totalBytes: index.totalBytes, itemBytes: item, articleBytes: article, pinnedBytes: pinned)
    }

    func setSizeCap(_ bytes: Int) {
        sizeCap = bytes
        enforceCap()
        persistIndex()
    }

    // MARK: - Private

    private func enforceCap() {
        for key in index.evictionOrder(cap: sizeCap) {
            try? FileManager.default.removeItem(at: blobURL(for: key))
            index.remove(key)
        }
    }

    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private static func loadIndex(from directory: URL) -> CacheIndex? {
        let url = directory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(CacheIndex.self, from: data)
        else { return nil }
        return index
    }

    /// Rebuilds an index by scanning the blob subdirectories. Used when the index
    /// file is missing or corrupt — never destructive to the cached blobs. Rebuilt
    /// entries are unpinned read-through (pin state can't be recovered from disk),
    /// which is acceptable: worst case a former offline download becomes LRU-eligible.
    private static func rebuildIndex(from directory: URL) -> CacheIndex {
        var index = CacheIndex()
        let now = Date()
        for kind in [CacheKind.item, .article, .feed] {
            let dir = directory.appendingPathComponent(kind.rawValue, isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for file in files {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let key = CacheKey(kind: kind, id: file.lastPathComponent)
                index.upsert(key: key, byteSize: size, fillSource: .readThrough, pinned: false, now: now)
            }
        }
        return index
    }
}
