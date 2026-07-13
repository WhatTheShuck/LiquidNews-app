// SavedPostsStore.swift
// Central store for all user-generated local data:
//   • favourites    — hearted stories (IDs in NSUbiquitousKeyValueStore + UserDefaults)
//   • readLater     — read-later bookmarks (IDs + timestamps in NSUbiquitousKeyValueStore + UserDefaults)
//   • hiddenPosts   — posts dismissed from feeds (JSON snapshots on disk)
//   • readHistory   — timestamped read events (JSON snapshots on disk)
//
// Sync strategy:
//   favouriteIDs, readLaterIDs, readLaterDates → NSUbiquitousKeyValueStore (real-time, like UserSettings)
//   hiddenPosts, readHistory                   → iCloud ubiquitous container file (launch + foreground)
//
// Export / import: UserDataExport wraps everything into one Codable struct.

import Foundation
import Observation
import os

@Observable
final class SavedPostsStore {

    static let shared = SavedPostsStore()

    // MARK: - Stored state

    private(set) var favouriteIDs: Set<Int> = []
    private(set) var readLaterIDs: Set<Int> = []
    /// Maps story ID → date the user added it to Read Later.
    private(set) var readLaterDates: [Int: Date] = [:]

    /// Ordered list of hidden posts — newest first.
    private(set) var hiddenPosts: [HiddenPostEntry] = []

    /// O(1) lookup set derived from hiddenPosts.
    private(set) var hiddenIDs: Set<Int> = []

    /// Ordered read history — newest first, capped at maxHistoryCount.
    private(set) var readHistory: [ReadHistoryEntry] = []

    /// O(1) lookup set derived from readHistory.
    private(set) var readIDs: Set<Int> = []

    // MARK: - Constants

    private let maxHistoryCount = 1_000

    // MARK: - KV store (iCloud real-time sync for IDs)

    private let kvStore = NSUbiquitousKeyValueStore.default

    // MARK: - UserDefaults / KV store keys
    // The same key strings are used in both UserDefaults (local backup) and
    // NSUbiquitousKeyValueStore (sync). UserDefaults is the offline fallback;
    // KV store is the authoritative cross-device source.

    private let favouritesKey     = "LN_favourites"
    private let readLaterKey      = "LN_saved"        // key kept for backward compat
    private let readLaterDatesKey = "LN_readLaterDates"

    // MARK: - File URLs

    private static var hiddenFileURL: URL { appSupportURL(name: "LN_hidden_posts.json") }
    private static var historyFileURL: URL { appSupportURL(name: "LN_read_history.json") }

    private static func appSupportURL(name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(name)
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard

        // 1. Load local values from UserDefaults as baseline.
        let localFavs      = Set(ud.array(forKey: favouritesKey) as? [Int] ?? [])
        let localReadLater = Set(ud.array(forKey: readLaterKey)  as? [Int] ?? [])

        // 2. Refresh the KV store in-memory cache before reading.
        kvStore.synchronize()

        // 3. KV store is the authoritative cross-device source.
        //    If it has a value, use it; otherwise migrate local data into it.
        if let kvFavs = kvStore.array(forKey: favouritesKey) as? [Int] {
            favouriteIDs = Set(kvFavs)
        } else {
            favouriteIDs = localFavs
            kvStore.set(Array(localFavs), forKey: favouritesKey)
        }

        if let kvReadLater = kvStore.array(forKey: readLaterKey) as? [Int] {
            readLaterIDs = Set(kvReadLater)
        } else {
            readLaterIDs = localReadLater
            kvStore.set(Array(localReadLater), forKey: readLaterKey)
        }

        readLaterDates = loadReadLaterDates(preferKV: true)
            .filter { readLaterIDs.contains($0.key) }

        loadHiddenPosts()
        loadHistory()

        // 4. Listen for changes pushed from other devices.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] notification in self?.applyExternalIDChanges(notification) }

        // 5. Merge the iCloud file for hiddenPosts / readHistory.
        Task { await mergeFromiCloud() }
    }

    // MARK: - KV store external change handler

    private func applyExternalIDChanges(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        for key in changedKeys {
            switch key {
            case favouritesKey:
                favouriteIDs = Set(kvStore.array(forKey: key) as? [Int] ?? [])
                UserDefaults.standard.set(Array(favouriteIDs), forKey: key)

            case readLaterKey:
                readLaterIDs = Set(kvStore.array(forKey: key) as? [Int] ?? [])
                readLaterDates = readLaterDates.filter { readLaterIDs.contains($0.key) }
                UserDefaults.standard.set(Array(readLaterIDs), forKey: key)

            case readLaterDatesKey:
                if let raw = kvStore.dictionary(forKey: key) as? [String: Double] {
                    readLaterDates = Dictionary(uniqueKeysWithValues:
                        raw.compactMap { k, v -> (Int, Date)? in
                            guard let id = Int(k), readLaterIDs.contains(id) else { return nil }
                            return (id, Date(timeIntervalSince1970: v))
                        }
                    )
                    // Persist locally so it survives offline sessions.
                    let persisted = Dictionary(uniqueKeysWithValues:
                        readLaterDates.map { (String($0.key), $0.value.timeIntervalSince1970) }
                    )
                    UserDefaults.standard.set(persisted, forKey: readLaterDatesKey)
                }

            default:
                break
            }
        }
    }

    // MARK: - Favourites

    func toggleFavourite(_ id: Int) {
        let isAdding = !favouriteIDs.contains(id)
        if isAdding { favouriteIDs.insert(id) } else { favouriteIDs.remove(id) }
        let arr = Array(favouriteIDs)
        UserDefaults.standard.set(arr, forKey: favouritesKey)
        kvStore.set(arr, forKey: favouritesKey)

        // Keep a lightweight local snapshot of favourites — just the story item, pinned so
        // the Favourites list always renders offline without re-fetching. Unlike Read Later
        // we deliberately do NOT prefetch the comment thread or article body.
        if isAdding {
            Task { await HNCache.shared.prefetch(ids: [id], pinned: true, fillSource: .favourite) }
        } else {
            Task { await HNCache.shared.setPinnedItem(false, id: id) }
        }
        syncToiCloud()
    }

    func isFavourite(_ id: Int) -> Bool { favouriteIDs.contains(id) }

    // MARK: - Read Later

    func toggleReadLater(_ id: Int) {
        let isAdding = !readLaterIDs.contains(id)
        if isAdding {
            readLaterIDs.insert(id)
            readLaterDates[id] = Date()
        } else {
            readLaterIDs.remove(id)
            readLaterDates.removeValue(forKey: id)
        }
        let arr = Array(readLaterIDs)
        UserDefaults.standard.set(arr, forKey: readLaterKey)
        kvStore.set(arr, forKey: readLaterKey)
        saveReadLaterDates()

        if isAdding {
            Task { await Self.prefetchReadLater(id: id) }
        } else {
            Task {
                await HNCache.shared.setPinnedItem(false, id: id)
                await HNCache.shared.setPinnedArticle(false, id: id)
            }
        }
    }

    /// Prefetches and pins a Read Later story's item + comment thread (top-level plus
    /// two reply layers), WiFi only. Article extraction is left to read-through (it
    /// needs a main-actor WebView).
    private static func prefetchReadLater(id: Int) async {
        guard NetworkMonitor.shared.currentlyOnline() else { return }
        // Always cache+pin the story item itself, on any connection — this is the cheap
        // part and is what makes the Read Later list render offline.
        await HNCache.shared.prefetch(ids: [id], pinned: true, fillSource: .readLater)
        // The deep comment-thread walk (top-level + two reply layers) is the heavy part, so
        // gate it to WiFi to avoid a surprise cellular-data hit.
        guard NetworkMonitor.shared.currentlyOnWifi() else { return }
        if let story = try? await HNAPIService.shared.item(id: id), let kids = story.kids {
            await HNCache.shared.prefetchThread(
                rootKidIDs: Array(kids.prefix(20)),
                levels: 3,
                pinned: true,
                fillSource: .readLater
            )
        }
    }

    func isReadLater(_ id: Int) -> Bool { readLaterIDs.contains(id) }

    // MARK: - Hidden posts

    func hide(_ item: HNItem) {
        hide(id: item.id, title: item.title, url: item.url, by: item.by)
    }

    func hide(id: Int, title: String?, url: String?, by: String? = nil) {
        guard !hiddenIDs.contains(id) else { return }
        let entry = HiddenPostEntry(
            id:       id,
            hiddenAt: Date(),
            title:    title,
            url:      url,
            by:       by
        )
        hiddenPosts.insert(entry, at: 0)
        hiddenIDs.insert(id)
        saveHiddenPosts()
    }

    func unhide(_ id: Int) {
        guard hiddenIDs.contains(id) else { return }
        hiddenPosts.removeAll { $0.id == id }
        hiddenIDs.remove(id)
        saveHiddenPosts()
    }

    func isHidden(_ id: Int) -> Bool { hiddenIDs.contains(id) }

    func clearHidden() {
        hiddenPosts = []
        hiddenIDs = []
        saveHiddenPosts()
    }

    func clearHidden(before date: Date) {
        hiddenPosts.removeAll { $0.hiddenAt < date }
        hiddenIDs = Set(hiddenPosts.map(\.id))
        saveHiddenPosts()
    }

    func applyHiddenPostsExpiry(_ expiry: HiddenPostsExpiry) {
        guard let cutoff = expiry.cutoffDate else { return }
        clearHidden(before: cutoff)
    }

    // MARK: - Read history

    func recordRead(_ item: HNItem) {
        recordRead(id: item.id, title: item.title, url: item.url, by: item.by, score: item.score)
    }

    func recordRead(id: Int, title: String?, url: String?, by: String? = nil, score: Int? = nil) {
        if readHistory.first?.id == id { return }
        let entry = ReadHistoryEntry(
            id:     id,
            readAt: Date(),
            title:  title,
            url:    url,
            by:     by,
            score:  score
        )
        readHistory.insert(entry, at: 0)
        readIDs.insert(id)
        if readHistory.count > maxHistoryCount {
            let removed = readHistory.removeLast()
            if !readHistory.contains(where: { $0.id == removed.id }) {
                readIDs.remove(removed.id)
            }
        }
        saveHistory()
    }

    func isRead(_ id: Int) -> Bool { readIDs.contains(id) }

    func removeHistoryEntry(id: Int) {
        readHistory.removeAll { $0.id == id }
        readIDs.remove(id)
        saveHistory()
    }

    func clearHistory() {
        readHistory = []
        readIDs = []
        saveHistory()
        // "Where you left off" is part of reading history — clear it too.
        RecentStoryStore.shared.clear()
    }

    func clearHistory(before date: Date) {
        readHistory.removeAll { $0.readAt < date }
        readIDs = Set(readHistory.map(\.id))
        saveHistory()
    }

    // MARK: - Export / Import

    // MARK: Compact favourites export / import

    /// Parses a compact `[id1,id2,id3]` or bare `id1,id2,id3` string into an array of integers.
    /// Non-integer tokens are silently skipped. Throws if no valid IDs are found.
    static func parseIDs(from string: String) throws -> [Int] {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("[") { s.removeFirst() }
        if s.hasSuffix("]") { s.removeLast() }
        let ids = s.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard !ids.isEmpty else { throw FavouritesImportError.noValidIDs }
        return ids
    }

    func exportData() throws -> Data {
        let datesStringKeyed = Dictionary(uniqueKeysWithValues:
            readLaterDates.map { (String($0.key), $0.value) }
        )
        return try encode(UserDataExport(
            version:        1,
            exportedAt:     Date(),
            favouriteIDs:   Array(favouriteIDs),
            readLaterIDs:   Array(readLaterIDs),
            readLaterDates: datesStringKeyed,
            hiddenPosts:    hiddenPosts,
            readHistory:    readHistory
        ))
    }

    func exportFavourites() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(favouriteIDs.sorted())
    }

    func exportReadLater() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(readLaterIDs.sorted())
    }

    func exportFavouritesCompact() -> String {
        let ids = favouriteIDs.sorted()
        return (try? String(data: JSONEncoder().encode(ids), encoding: .utf8)) ?? "[]"
    }

    func importFavourites(from string: String, replacing: Bool = false) throws {
        let ids = try Self.parseIDs(from: string)
        if replacing {
            favouriteIDs = Set(ids)
        } else {
            favouriteIDs.formUnion(ids)
        }
        let arr = Array(favouriteIDs)
        UserDefaults.standard.set(arr, forKey: favouritesKey)
        kvStore.set(arr, forKey: favouritesKey)
        syncToiCloud()
    }

    func exportHistory() throws -> Data {
        try encode(UserDataExport(
            version:        1,
            exportedAt:     Date(),
            favouriteIDs:   [],
            readLaterIDs:   [],
            readLaterDates: nil,
            hiddenPosts:    [],
            readHistory:    readHistory
        ))
    }

    func exportHidden() throws -> Data {
        try encode(UserDataExport(
            version:        1,
            exportedAt:     Date(),
            favouriteIDs:   [],
            readLaterIDs:   [],
            readLaterDates: nil,
            hiddenPosts:    hiddenPosts,
            readHistory:    []
        ))
    }

    private func encode(_ export: UserDataExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    func importData(_ data: Data, replacing: Bool = false, syncCloud: Bool = true) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(UserDataExport.self, from: data)

        if replacing {
            favouriteIDs   = Set(export.favouriteIDs)
            readLaterIDs   = Set(export.readLaterIDs)
            readLaterDates = [:]   // cleared here; filled below if export includes dates
            hiddenPosts    = export.hiddenPosts
            hiddenIDs      = Set(export.hiddenPosts.map(\.id))
            readHistory    = export.readHistory
            readIDs        = Set(export.readHistory.map(\.id))
        } else {
            favouriteIDs.formUnion(export.favouriteIDs)
            readLaterIDs.formUnion(export.readLaterIDs)

            var mergedHidden = Dictionary(grouping: hiddenPosts + export.hiddenPosts, by: \.id)
                .values
                .compactMap { entries in entries.max(by: { $0.hiddenAt < $1.hiddenAt }) }
            mergedHidden.sort { $0.hiddenAt > $1.hiddenAt }
            hiddenPosts = mergedHidden
            hiddenIDs   = Set(hiddenPosts.map(\.id))

            var mergedHistory = Dictionary(grouping: readHistory + export.readHistory, by: \.id)
                .values
                .compactMap { entries in entries.max(by: { $0.readAt < $1.readAt }) }
            mergedHistory.sort { $0.readAt > $1.readAt }
            readHistory = Array(mergedHistory.prefix(maxHistoryCount))
            readIDs     = Set(readHistory.map(\.id))
        }

        // Restore dates from export; existing dates take precedence on merge.
        if let datesDict = export.readLaterDates {
            let imported = Dictionary(uniqueKeysWithValues:
                datesDict.compactMap { k, v -> (Int, Date)? in
                    guard let id = Int(k) else { return nil }
                    return (id, v)
                }
            )
            if replacing {
                readLaterDates = imported
            } else {
                for (id, date) in imported where readLaterDates[id] == nil {
                    readLaterDates[id] = date
                }
            }
        }

        UserDefaults.standard.set(Array(favouriteIDs), forKey: favouritesKey)
        UserDefaults.standard.set(Array(readLaterIDs), forKey: readLaterKey)
        saveReadLaterDates(syncCloud: false)
        saveHiddenPosts(syncCloud: false)
        saveHistory(syncCloud: false)
        if syncCloud { syncToiCloud() }
    }

    // MARK: - iCloud sync

    /// URL of the sync file in the iCloud ubiquitous container.
    /// Returns nil when iCloud is unavailable (not signed in, capability missing, etc.).
    nonisolated private var iCloudDataURL: URL? {
        FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/userdata.json")
    }

    /// Called on launch and every time the app returns to the foreground.
    /// Reads the iCloud file on a background thread (the container URL call can block),
    /// then merges with local state on the main thread.
    func mergeFromiCloud() async {
        let data = await Task.detached(priority: .background) { [self] () -> Data? in
            guard let url = iCloudDataURL else {
                Logger.sync.notice("mergeFromiCloud: iCloud container unavailable")
                return nil
            }
            // Tell iOS we want this file — no-op if already local, starts async
            // download if it's cloud-only. The read below will succeed if the file
            // is already present; if not, the next foreground refresh will catch it.
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            // Coordinated read so we never see a half-written file or race a
            // remote update landing mid-read.
            var readData: Data?
            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
                readData = try? Data(contentsOf: readURL)
            }
            if let coordError {
                Logger.sync.error("mergeFromiCloud: coordination failed: \(coordError.localizedDescription, privacy: .public)")
            }
            return readData
        }.value
        guard let data else { return }
        // importData mutates @Observable state — run on main thread.
        await MainActor.run {
            do {
                try importData(data, replacing: false, syncCloud: false)
            } catch {
                Logger.sync.error("mergeFromiCloud: importData failed: \(error.localizedDescription, privacy: .public)")
            }
            syncToiCloud()
        }
    }

    // MARK: - iCloud file write (debounced)

    /// Debounces the iCloud container write. Each mutating path calls
    /// `syncToiCloud()`; a burst (e.g. marking several stories read in a row)
    /// cancels the previously scheduled write and reschedules, so the whole burst
    /// produces a single full-dataset serialization + write instead of one per
    /// mutation. IDs already sync in real time via `NSUbiquitousKeyValueStore`, so
    /// this file write can afford to lag slightly. Flushed on backgrounding via
    /// `flushPendingSync()`.
    private var pendingSyncTask: Task<Void, Never>?
    private let syncDebounce: Duration = .milliseconds(750)

    /// Schedules a coalesced write of the current full state to the iCloud
    /// container file. Called after every local save.
    private func syncToiCloud() {
        pendingSyncTask?.cancel()
        let delay = syncDebounce
        pendingSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.pendingSyncTask = nil
            self.writeToiCloudNow()
        }
    }

    /// Forces any pending debounced write to run immediately. Call when the app is
    /// heading to the background so a queued write isn't lost.
    @MainActor
    func flushPendingSync() {
        guard pendingSyncTask != nil else { return }
        pendingSyncTask?.cancel()
        pendingSyncTask = nil
        writeToiCloudNow()
    }

    /// Serializes and writes the full dataset to the iCloud container file,
    /// coordinated via `NSFileCoordinator` so a cross-device read never sees a
    /// half-written file and a concurrent remote update isn't clobbered.
    private func writeToiCloudNow() {
        guard let data = try? exportData() else {
            Logger.sync.error("syncToiCloud: exportData() failed")
            return
        }
        guard let url = iCloudDataURL else { return }
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            var coordError: NSError?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
                do {
                    try data.write(to: writeURL, options: .atomic)
                } catch {
                    Logger.sync.error("syncToiCloud: write failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            if let coordError {
                Logger.sync.error("syncToiCloud: coordination failed: \(coordError.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Private persistence

    /// Loads readLaterDates from persistent storage.
    /// When `preferKV` is true, the KV store is checked first (it's more current on
    /// first launch after another device made changes). Falls back to UserDefaults.
    private func loadReadLaterDates(preferKV: Bool = false) -> [Int: Date] {
        var raw: [String: Double]?
        if preferKV, let kvRaw = kvStore.dictionary(forKey: readLaterDatesKey) as? [String: Double] {
            raw = kvRaw
        } else {
            raw = UserDefaults.standard.dictionary(forKey: readLaterDatesKey) as? [String: Double]
        }
        guard let raw else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v -> (Int, Date)? in
            guard let id = Int(k) else { return nil }
            return (id, Date(timeIntervalSince1970: v))
        })
    }

    private func saveReadLaterDates(syncCloud: Bool = true) {
        let raw = Dictionary(uniqueKeysWithValues:
            readLaterDates.map { (String($0.key), $0.value.timeIntervalSince1970) }
        )
        UserDefaults.standard.set(raw, forKey: readLaterDatesKey)
        kvStore.set(raw, forKey: readLaterDatesKey)
        if syncCloud { syncToiCloud() }
    }

    private func loadHiddenPosts() {
        guard let data = try? Data(contentsOf: Self.hiddenFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([HiddenPostEntry].self, from: data) {
            hiddenPosts = loaded
            hiddenIDs   = Set(loaded.map(\.id))
        }
    }

    private func saveHiddenPosts(syncCloud: Bool = true) {
        writeJSON(hiddenPosts, to: Self.hiddenFileURL)
        if syncCloud { syncToiCloud() }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: Self.historyFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([ReadHistoryEntry].self, from: data) {
            readHistory = loaded
            readIDs     = Set(loaded.map(\.id))
        }
    }

    private func saveHistory(syncCloud: Bool = true) {
        writeJSON(readHistory, to: Self.historyFileURL)
        if syncCloud { syncToiCloud() }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Debug

#if DEBUG
    /// Debug-only: wipes every iCloud and local store so the app behaves like a
    /// fresh install. Built to recover an account whose key-value store / iCloud
    /// container got into a bad state during the dev → App Store transition.
    ///
    /// Clears, in order:
    ///   1. ALL keys in NSUbiquitousKeyValueStore (favourites, read-later, and
    ///      every UserSettings preference — they share the default KV store).
    ///   2. The iCloud ubiquitous-container sync file (`Documents/userdata.json`).
    ///   3. The on-disk hidden-posts / read-history JSON snapshots.
    ///   4. The local UserDefaults mirrors so they don't re-seed the KV store.
    ///   5. In-memory state, so the UI empties immediately.
    ///
    /// The `LN_kv_migrated` flag is intentionally left set, so UserSettings does
    /// NOT re-copy stale UserDefaults values back into the cleared KV store.
    /// Relaunch the app afterwards for a fully clean slate.
    /// - Returns: A short human-readable summary of what was removed.
    @discardableResult
    func debugWipeAllStorage() -> String {
        // 1. Remove every key from the iCloud key-value store.
        let kvKeys = Array(kvStore.dictionaryRepresentation.keys)
        for key in kvKeys { kvStore.removeObject(forKey: key) }
        kvStore.synchronize()

        // 2. Delete the iCloud ubiquitous container sync file.
        var iCloudFileRemoved = false
        if let url = iCloudDataURL {
            iCloudFileRemoved = (try? FileManager.default.removeItem(at: url)) != nil
        }

        // 3. Delete the on-disk JSON snapshots.
        try? FileManager.default.removeItem(at: Self.hiddenFileURL)
        try? FileManager.default.removeItem(at: Self.historyFileURL)

        // 4. Remove the local UserDefaults mirrors (NOT the migration flag).
        let ud = UserDefaults.standard
        // LN_pins is a leftover from the deleted legacy pin feature — clear it too.
        for key in [favouritesKey, readLaterKey, readLaterDatesKey, "LN_pins"] {
            ud.removeObject(forKey: key)
        }

        // 5. Reset in-memory state so the UI updates without a relaunch.
        favouriteIDs   = []
        readLaterIDs   = []
        readLaterDates = [:]
        hiddenPosts    = []
        hiddenIDs      = []
        readHistory    = []
        readIDs        = []

        return """
        Cleared \(kvKeys.count) iCloud KV key(s).
        iCloud sync file: \(iCloudFileRemoved ? "deleted" : "not present").
        Local snapshots & defaults cleared.
        Relaunch the app to finish.
        """
    }
#endif
}
