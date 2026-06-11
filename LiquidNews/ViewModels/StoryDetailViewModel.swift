// StoryDetailViewModel.swift
// Handles fetching the top-level comments for a single story.
//
// The recursive CommentView consumes the `comments` array; child comments are
// loaded lazily inside CommentView itself.

import Foundation
import Observation

@Observable
final class StoryDetailViewModel {

    /// Root-level comments, in display order.
    var comments: [HNItem] = []

    var isLoading = false
    var errorMessage: String?

    /// The story this VM was created for — kept for reference.
    let story: HNItem

    init(story: HNItem) {
        self.story = story
    }

    /// Fetch the first 20 top-level comments for the story.
    /// Pass `bustCache: true` after posting a reply so the fresh kids list is fetched.
    func loadComments(bustCache: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        if bustCache { HNAPIService.shared.evict(id: story.id) }

        do {
            // Stories from search (Algolia) don't include the kids list —
            // fetch the full item from the HN API first to get it.
            let source = try await HNAPIService.shared.item(id: story.id)
            guard let kids = source.kids, !kids.isEmpty else {
                comments = []
                return
            }
            let topLevel = Array(kids.prefix(20))
            var fetched = try await HNAPIService.shared.items(ids: topLevel)

            // Sort: mods first, then current user, then everyone else.
            let currentUser = HNAuthService.shared.username
            fetched.sort { a, b in
                let aMod = HNItem.moderators.contains(a.by ?? "")
                let bMod = HNItem.moderators.contains(b.by ?? "")
                let aMe = currentUser != nil && a.by == currentUser
                let bMe = currentUser != nil && b.by == currentUser
                if aMod != bMod { return aMod }
                if aMe != bMe { return aMe }
                return false
            }
            comments = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
