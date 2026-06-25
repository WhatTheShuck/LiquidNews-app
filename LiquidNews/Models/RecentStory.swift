// RecentStory.swift
// The minimal snapshot of the last story the user opened on this device, used
// to render the resume banner instantly without a network fetch. Persisted
// locally (not iCloud) — "where this device left off" is intentionally
// device-local; cross-device continuity is Handoff's job.

import Foundation

struct RecentStory: Codable, Equatable {
    let id: Int
    let title: String
    let savedAt: Date
}
