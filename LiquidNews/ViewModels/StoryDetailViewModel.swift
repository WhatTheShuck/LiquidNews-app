// StoryDetailViewModel.swift
// Handles fetching top-level comments for a single story.
// Child comments are loaded lazily inside CommentView itself.

import Foundation
import Observation

@Observable
final class StoryDetailViewModel {

    var comments: [HNItem] = []
    var isLoading = false
    var errorMessage: String?

    // The story this VM was created for — kept for reference
    let story: HNItem

    init(story: HNItem) {
        self.story = story
    }

    /// Fetch the first 20 top-level comments for the story.
    func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            // Stories from search (Algolia) don't include the kids list —
            // fetch the full item from the HN API first to get it.
            let source = story.kids != nil ? story : try await HNAPIService.shared.item(id: story.id)
            guard let kids = source.kids, !kids.isEmpty else { return }
            let topLevel = Array(kids.prefix(20))
            comments = try await HNAPIService.shared.items(ids: topLevel)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
