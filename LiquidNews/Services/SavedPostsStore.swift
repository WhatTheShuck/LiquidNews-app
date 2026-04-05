// SavedPostsStore.swift
// Manages locally-saved favourites and pinned posts using UserDefaults.
//
// @Observable lets SwiftUI track reads of `favouriteIDs` and `pinnedIDs`
// so views automatically re-render when a post is saved/unsaved.

import Foundation
import Observation

@Observable
final class SavedPostsStore {

    static let shared = SavedPostsStore()

    // MARK: - Stored state

    /// IDs the user has favourited (heart icon)
    var favouriteIDs: Set<Int> = []

    /// IDs the user has pinned
    var pinnedIDs: Set<Int> = []

    /// IDs the user has saved for reading later
    var savedIDs: Set<Int> = []

    // MARK: - UserDefaults keys

    private let favouritesKey = "LN_favourites"
    private let pinsKey = "LN_pins"
    private let savedKey = "LN_saved"

    private init() {
        // Hydrate from disk on launch
        favouriteIDs = Set(UserDefaults.standard.array(forKey: favouritesKey) as? [Int] ?? [])
        pinnedIDs    = Set(UserDefaults.standard.array(forKey: pinsKey) as? [Int] ?? [])
        savedIDs     = Set(UserDefaults.standard.array(forKey: savedKey) as? [Int] ?? [])
    }

    // MARK: - Actions

    func toggleFavourite(_ id: Int) {
        if favouriteIDs.contains(id) {
            favouriteIDs.remove(id)
        } else {
            favouriteIDs.insert(id)
        }
        persist()
    }

    func togglePin(_ id: Int) {
        if pinnedIDs.contains(id) {
            pinnedIDs.remove(id)
        } else {
            pinnedIDs.insert(id)
        }
        persist()
    }

    func toggleSaved(_ id: Int) {
        if savedIDs.contains(id) {
            savedIDs.remove(id)
        } else {
            savedIDs.insert(id)
        }
        persist()
    }

    func isFavourite(_ id: Int) -> Bool { favouriteIDs.contains(id) }
    func isPinned(_ id: Int)    -> Bool { pinnedIDs.contains(id) }
    func isSaved(_ id: Int)     -> Bool { savedIDs.contains(id) }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(Array(favouriteIDs), forKey: favouritesKey)
        UserDefaults.standard.set(Array(pinnedIDs), forKey: pinsKey)
        UserDefaults.standard.set(Array(savedIDs), forKey: savedKey)
    }
}
