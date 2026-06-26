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

    /// Loads the favourited stories, cache-first so the list renders instantly (and
    /// offline) without re-fetching every time. Sorted newest-first by post time.
    func load(ids: Set<Int>) async {
        guard !ids.isEmpty else {
            stories = []
            return
        }
        errorMessage = nil

        // Phase 1: instant local snapshot.
        var cached: [HNItem] = []
        for id in ids {
            if let item = await HNCache.shared.cachedItem(id: id) { cached.append(item) }
        }
        if !cached.isEmpty {
            stories = byNewest(cached)
        } else {
            isLoading = true
        }

        // Phase 2: revalidate when online; otherwise the cached snapshot stands.
        guard NetworkMonitor.shared.currentlyOnline() else {
            isLoading = false
            return
        }
        defer { isLoading = false }
        do {
            let fetched = try await HNAPIService.shared.items(ids: Array(ids))
            // Pin the refreshed snapshot so favourites stay available offline.
            for item in fetched {
                await HNCache.shared.storeItem(item, fillSource: .favourite, pinned: true)
            }
            stories = byNewest(fetched)
        } catch {
            if stories.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    private func byNewest(_ items: [HNItem]) -> [HNItem] {
        items.sorted { ($0.time ?? 0) > ($1.time ?? 0) }
    }

    /// Removes a single story from the visible list and unfavourites it in the store.
    func remove(id: Int) {
        SavedPostsStore.shared.toggleFavourite(id)
        stories.removeAll { $0.id == id }
    }
}
