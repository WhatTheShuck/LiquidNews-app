// FavouritesViewModel.swift
// Loads HNItem objects for all favourited IDs and keeps the list in sync
// when the user adds or removes favourites from anywhere in the app.

import Foundation
import Observation

@Observable
final class FavouritesViewModel {

    var stories: [HNItem] = []
    var isLoading = false
    var errorMessage: String? = nil

    // MARK: - Load

    /// Fetches the full HNItem for every ID in the favourites store.
    /// Sorted newest-first by post time.
    func load(ids: Set<Int>) async {
        guard !ids.isEmpty else {
            stories = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await HNAPIService.shared.items(ids: Array(ids))
            stories = fetched.sorted { ($0.time ?? 0) > ($1.time ?? 0) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Removes a single story from the visible list and unfavourites it in the store.
    func remove(id: Int) {
        SavedPostsStore.shared.toggleFavourite(id)
        stories.removeAll { $0.id == id }
    }
}
