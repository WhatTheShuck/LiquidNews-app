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

    func load(ids: Set<Int>) async {
        guard !ids.isEmpty else {
            stories = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await HNAPIService.shared.items(ids: Array(ids))
            stories = sorted(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
