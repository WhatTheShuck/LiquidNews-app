// CoachMarkStore.swift
// Local (per-device) read/write of coach-mark "seen" flags. Wraps an injectable
// UserDefaults so the gating is unit-testable without touching @AppStorage in views.

import Foundation

final class CoachMarkStore {
    static let shared = CoachMarkStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasSeen(_ mark: CoachMark) -> Bool {
        defaults.bool(forKey: mark.storageKey)
    }

    func markSeen(_ mark: CoachMark) {
        defaults.set(true, forKey: mark.storageKey)
    }

    func seenMarks() -> Set<CoachMark> {
        Set(CoachMark.allCases.filter { hasSeen($0) })
    }

    /// Clears every flag so "Replay tips" can show the hints again.
    func replayAll() {
        for mark in CoachMark.allCases {
            defaults.removeObject(forKey: mark.storageKey)
        }
    }
}
