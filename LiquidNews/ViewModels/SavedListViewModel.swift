// SavedListViewModel.swift
// Shared cache-first, revalidate-and-pin load flow for the saved-list view
// models (Favourites, Read Later). Both render an instant local snapshot, then
// refresh from the network when online and pin the result so the list — the
// app's headline offline feature — stays available with no connection.

import Foundation

/// A view model backing a saved-story list that loads cache-first and pins its
/// results. Conformers supply the cache `fillSource` and a sort; the two-phase
/// `load(ids:)` flow is provided by the default implementation below.
protocol SavedListViewModel: AnyObject {
    var stories: [HNItem] { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }

    /// Which cache bucket refreshed items are pinned under.
    var fillSource: FillSource { get }

    /// Orders items for display. Called for both the cached snapshot and the
    /// revalidated result.
    func sortStories(_ items: [HNItem]) -> [HNItem]
}

extension SavedListViewModel {

    /// Loads the saved stories cache-first so the list renders instantly and
    /// offline, then revalidates online and pins the refreshed snapshot.
    func load(ids: Set<Int>) async {
        guard !ids.isEmpty else {
            stories = []
            return
        }
        errorMessage = nil

        // Phase 1: instant local snapshot.
        let cached = await HNCache.shared.cachedItems(ids: ids)
        if !cached.isEmpty {
            stories = sortStories(cached)
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
            for item in fetched {
                await HNCache.shared.storeItem(item, fillSource: fillSource, pinned: true)
            }
            stories = sortStories(fetched)
        } catch {
            // Only surface real failures, and only when there's nothing to show.
            if !error.isCancellation, stories.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
