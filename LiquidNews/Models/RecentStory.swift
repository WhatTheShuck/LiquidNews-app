// RecentStory.swift
// The minimal snapshot of the last story the user opened, used
// to render the resume banner instantly without a network fetch. Persisted
// locally (authoritative, offline) AND, per-device, to iCloud KV so another
// device can offer it as a "continue elsewhere" hint. See RecentStoryStore.

import Foundation

struct RecentStory: Codable, Equatable {
    let id: Int
    let title: String
    let savedAt: Date
    /// Which install wrote this snapshot. nil for legacy local values written
    /// before cloud sync existed; first `record` after upgrade restamps it.
    var installID: String? = nil
    /// The originating device class. nil for legacy local values.
    var deviceKind: DeviceKind? = nil
}
