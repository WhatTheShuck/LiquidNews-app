// SavedViewModel.swift
// Loads HNItem objects for all saved-for-later IDs.

import Foundation
import Observation

@Observable
final class SavedViewModel {

    var stories: [HNItem] = []
    var isLoading = false
    var errorMessage: String? = nil

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

    func remove(id: Int) {
        SavedPostsStore.shared.toggleSaved(id)
        stories.removeAll { $0.id == id }
    }
}
