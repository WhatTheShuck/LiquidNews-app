// UserDataModels.swift
// Shared data models for user-generated local data:
// read history entries and the export/import envelope.

import Foundation

// MARK: - Read History Entry

/// A snapshot of a story at the moment the user opened it.
/// Stored as a snapshot so that deleted/dead stories still appear in history.
struct ReadHistoryEntry: Codable, Identifiable {
    let id: Int           // HN story ID
    let readAt: Date      // when the user opened the story
    let title: String?    // title at time of reading
    let url: String?      // link at time of reading
    let by: String?       // author at time of reading
    let score: Int?       // score at time of reading
}

// MARK: - Hidden Post Entry

/// A snapshot of a story at the moment the user hid it.
/// Stored so the user can review and undo hidden posts by title.
struct HiddenPostEntry: Codable, Identifiable {
    let id: Int           // HN story ID
    let hiddenAt: Date    // when the user hid the story
    let title: String?    // snapshot title
    let url: String?      // snapshot link
    let by: String?       // snapshot author
}

// MARK: - Export / Import envelope

/// Full export of all user-generated local data.
/// Version field allows future migration if schema changes.
struct UserDataExport: Codable {
    let version: Int
    let exportedAt: Date
    let favouriteIDs: [Int]
    let readLaterIDs: [Int]
    /// ISO 8601 dates the user added each story, keyed by story ID string. nil when importing old exports.
    let readLaterDates: [String: Date]?
    let hiddenPosts: [HiddenPostEntry]
    let readHistory: [ReadHistoryEntry]

    // Map readLaterIDs to the legacy "savedIDs" JSON key so old export files
    // still decode correctly.
    enum CodingKeys: String, CodingKey {
        case version, exportedAt, favouriteIDs
        case readLaterIDs = "savedIDs"
        case readLaterDates
        case hiddenPosts, readHistory
    }
}
