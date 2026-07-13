// FavouritesViewModel.swift
// Loads HNItem objects for all favourited IDs and keeps the list in sync
// when the user adds or removes favourites from anywhere in the app.

import Foundation
import Observation

@Observable
final class FavouritesViewModel: SavedListViewModel {

    var stories: [HNItem] = []
    var isLoading = false
    var errorMessage: String? = nil

    let fillSource: FillSource = .favourite

    /// Newest-first by post time.
    func sortStories(_ items: [HNItem]) -> [HNItem] {
        items.sorted { ($0.time ?? 0) > ($1.time ?? 0) }
    }

    /// Removes a single story from the visible list and unfavourites it in the store.
    func remove(id: Int) {
        SavedPostsStore.shared.toggleFavourite(id)
        stories.removeAll { $0.id == id }
    }
}
