// CuratedViewModel.swift
// Thin view-facing layer over CuratedStore + UserSettings.
// The store owns all data/cache logic; this just bridges it to the view.

import Foundation

@Observable
final class CuratedViewModel {

    private let store    = CuratedStore.shared
    private let settings = UserSettings.shared

    var entries:         [CuratedEntry] { store.entries }
    var isLoadingInitial: Bool          { store.isLoadingInitial }
    var isRefreshing:     Bool          { store.isRefreshing }
    var isLoadingMore:    Bool          { store.isLoadingMore }
    var canLoadMore:      Bool          { store.canLoadMore }
    var error:            String?       { store.error }

    func load() async {
        await store.initialLoad(settings: settings)
    }

    func refresh() async {
        await store.refresh(settings: settings)
    }

    func loadMore() async {
        await store.loadMore()
    }
}
