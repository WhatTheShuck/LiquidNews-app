// SavedPostsStore.swift
// Central store for all user-generated local data:
//   • favourites  — hearted stories (IDs in UserDefaults)
//   • saved       — read-later bookmarks (IDs in UserDefaults)
//   • hiddenPosts — posts dismissed from feeds (JSON snapshots on disk)
//   • readHistory — timestamped read events (JSON snapshots on disk)
//
// Export / import: UserDataExport wraps everything into one Codable struct.

import Foundation
import Observation

@Observable
final class SavedPostsStore {

    static let shared = SavedPostsStore()

    // MARK: - Stored state

    private(set) var favouriteIDs: Set<Int> = []
    private(set) var savedIDs: Set<Int> = []

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

    // MARK: - UserDefaults keys (simple ID arrays)

    private let favouritesKey = "LN_favourites"
    private let savedKey      = "LN_saved"

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
        favouriteIDs = Set(ud.array(forKey: favouritesKey) as? [Int] ?? [])
        savedIDs     = Set(ud.array(forKey: savedKey)      as? [Int] ?? [])
        loadHiddenPosts()
        loadHistory()
    }

    // MARK: - Favourites

    func toggleFavourite(_ id: Int) {
        if favouriteIDs.contains(id) { favouriteIDs.remove(id) } else { favouriteIDs.insert(id) }
        UserDefaults.standard.set(Array(favouriteIDs), forKey: favouritesKey)
    }

    func isFavourite(_ id: Int) -> Bool { favouriteIDs.contains(id) }

    // MARK: - Saved (read later)

    func toggleSaved(_ id: Int) {
        if savedIDs.contains(id) { savedIDs.remove(id) } else { savedIDs.insert(id) }
        UserDefaults.standard.set(Array(savedIDs), forKey: savedKey)
    }

    func isSaved(_ id: Int) -> Bool { savedIDs.contains(id) }

    // MARK: - Hidden posts

    func hide(_ item: HNItem) {
        guard !hiddenIDs.contains(item.id) else { return }
        let entry = HiddenPostEntry(
            id:       item.id,
            hiddenAt: Date(),
            title:    item.title,
            url:      item.url,
            by:       item.by
        )
        hiddenPosts.insert(entry, at: 0)
        hiddenIDs.insert(item.id)
        saveHiddenPosts()
    }

    func unhide(_ id: Int) {
        guard hiddenIDs.contains(id) else { return }
        hiddenPosts.removeAll { $0.id == id }
        hiddenIDs.remove(id)
        saveHiddenPosts()
    }

    func isHidden(_ id: Int) -> Bool { hiddenIDs.contains(id) }

    /// Removes all hidden post entries.
    func clearHidden() {
        hiddenPosts = []
        hiddenIDs = []
        saveHiddenPosts()
    }

    /// Removes hidden entries older than the given date.
    func clearHidden(before date: Date) {
        hiddenPosts.removeAll { $0.hiddenAt < date }
        hiddenIDs = Set(hiddenPosts.map(\.id))
        saveHiddenPosts()
    }

    /// Applies the user's chosen auto-expiry setting to hidden posts.
    func applyHiddenPostsExpiry(_ expiry: HiddenPostsExpiry) {
        guard let cutoff = expiry.cutoffDate else { return }
        clearHidden(before: cutoff)
    }

    // MARK: - Read history

    func recordRead(_ item: HNItem) {
        if readHistory.first?.id == item.id { return }
        let entry = ReadHistoryEntry(
            id:     item.id,
            readAt: Date(),
            title:  item.title,
            url:    item.url,
            by:     item.by,
            score:  item.score
        )
        readHistory.insert(entry, at: 0)
        readIDs.insert(item.id)
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
    }

    func clearHistory(before date: Date) {
        readHistory.removeAll { $0.readAt < date }
        readIDs = Set(readHistory.map(\.id))
        saveHistory()
    }

    // MARK: - Export / Import

    /// Exports all user data.
    func exportData() throws -> Data {
        try encode(UserDataExport(
            version:      1,
            exportedAt:   Date(),
            favouriteIDs: Array(favouriteIDs),
            savedIDs:     Array(savedIDs),
            hiddenPosts:  hiddenPosts,
            readHistory:  readHistory
        ))
    }

    /// Exports favourites as a plain sorted JSON array of HN story IDs.
    func exportFavourites() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(favouriteIDs.sorted())
    }

    /// Exports saved posts as a plain sorted JSON array of HN story IDs.
    func exportSaved() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(savedIDs.sorted())
    }

    /// Exports read history only.
    func exportHistory() throws -> Data {
        try encode(UserDataExport(
            version:      1,
            exportedAt:   Date(),
            favouriteIDs: [],
            savedIDs:     [],
            hiddenPosts:  [],
            readHistory:  readHistory
        ))
    }

    /// Exports hidden posts only.
    func exportHidden() throws -> Data {
        try encode(UserDataExport(
            version:      1,
            exportedAt:   Date(),
            favouriteIDs: [],
            savedIDs:     [],
            hiddenPosts:  hiddenPosts,
            readHistory:  []
        ))
    }

    private func encode(_ export: UserDataExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// Merges or replaces the store with data from a previously exported JSON blob.
    func importData(_ data: Data, replacing: Bool = false) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(UserDataExport.self, from: data)

        if replacing {
            favouriteIDs = Set(export.favouriteIDs)
            savedIDs     = Set(export.savedIDs)
            hiddenPosts  = export.hiddenPosts
            hiddenIDs    = Set(export.hiddenPosts.map(\.id))
            readHistory  = export.readHistory
            readIDs      = Set(export.readHistory.map(\.id))
        } else {
            favouriteIDs.formUnion(export.favouriteIDs)
            savedIDs.formUnion(export.savedIDs)

            // Merge hidden: keep newest hiddenAt per id
            var mergedHidden = Dictionary(grouping: hiddenPosts + export.hiddenPosts, by: \.id)
                .values
                .compactMap { entries in entries.max(by: { $0.hiddenAt < $1.hiddenAt }) }
            mergedHidden.sort { $0.hiddenAt > $1.hiddenAt }
            hiddenPosts = mergedHidden
            hiddenIDs   = Set(hiddenPosts.map(\.id))

            // Merge history: keep newest readAt per id
            var mergedHistory = Dictionary(grouping: readHistory + export.readHistory, by: \.id)
                .values
                .compactMap { entries in entries.max(by: { $0.readAt < $1.readAt }) }
            mergedHistory.sort { $0.readAt > $1.readAt }
            readHistory = Array(mergedHistory.prefix(maxHistoryCount))
            readIDs     = Set(readHistory.map(\.id))
        }

        UserDefaults.standard.set(Array(favouriteIDs), forKey: favouritesKey)
        UserDefaults.standard.set(Array(savedIDs),     forKey: savedKey)
        saveHiddenPosts()
        saveHistory()
    }

    // MARK: - Legacy / pins

    private let pinsKey = "LN_pins"
    private(set) var pinnedIDs: Set<Int> = []

    func togglePin(_ id: Int) {
        if pinnedIDs.contains(id) { pinnedIDs.remove(id) } else { pinnedIDs.insert(id) }
        UserDefaults.standard.set(Array(pinnedIDs), forKey: pinsKey)
    }

    func isPinned(_ id: Int) -> Bool { pinnedIDs.contains(id) }

    // MARK: - Private persistence

    private func loadHiddenPosts() {
        guard let data = try? Data(contentsOf: Self.hiddenFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([HiddenPostEntry].self, from: data) {
            hiddenPosts = loaded
            hiddenIDs   = Set(loaded.map(\.id))
        }
    }

    private func saveHiddenPosts() {
        writeJSON(hiddenPosts, to: Self.hiddenFileURL)
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

    private func saveHistory() {
        writeJSON(readHistory, to: Self.historyFileURL)
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
}
