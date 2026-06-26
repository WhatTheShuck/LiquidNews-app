// ReadLaterViewModel.swift
// Loads HNItem objects for all read-later IDs and manages sort order.

import Foundation
import Observation

enum ReadLaterSort: CaseIterable {
    case dateSaved
    case score
    case storyAge

    var label: String {
        switch self {
        case .dateSaved: return "Date Saved"
        case .score:     return "HN Score"
        case .storyAge:  return "Story Age"
        }
    }
}

@Observable
final class ReadLaterViewModel {

    var stories: [HNItem] = []
    var isLoading = false
    var errorMessage: String? = nil
    var sort: ReadLaterSort = .dateSaved

    private let store = SavedPostsStore.shared

    /// Loads the saved stories cache-first so the list renders instantly and offline.
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
            stories = sorted(cached)
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
            // Pin the refreshed snapshot so saved stories stay available offline.
            for item in fetched {
                await HNCache.shared.storeItem(item, fillSource: .readLater, pinned: true)
            }
            stories = sorted(fetched)
        } catch {
            if stories.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    /// Re-sorts the already-loaded stories array without a network call.
    func applySort() {
        stories = sorted(stories)
    }

    func remove(id: Int) {
        store.toggleReadLater(id)
        stories.removeAll { $0.id == id }
    }

    private func sorted(_ items: [HNItem]) -> [HNItem] {
        switch sort {
        case .dateSaved:
            return items.sorted {
                let a = store.readLaterDates[$0.id]?.timeIntervalSince1970 ?? 0
                let b = store.readLaterDates[$1.id]?.timeIntervalSince1970 ?? 0
                return a > b
            }
        case .score:
            return items.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        case .storyAge:
            return items.sorted { ($0.time ?? 0) > ($1.time ?? 0) }
        }
    }
}
