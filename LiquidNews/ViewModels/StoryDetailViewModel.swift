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
            await HNCache.shared.storeItem(source, fillSource: .readThrough, pinned: false)
            guard let kids = source.kids, !kids.isEmpty else {
                comments = []
                return
            }
            let topLevel = Array(kids.prefix(20))

            // Phase 1: cached comments, if present.
            var cached: [HNItem] = []
            for id in topLevel {
                if let c = await HNCache.shared.cachedItem(id: id) { cached.append(c) }
            }
            if !cached.isEmpty { comments = sortComments(cached) }

            // Phase 2: revalidate when online.
            guard NetworkMonitor.shared.currentlyOnline() else { return }
            var fetched = try await HNAPIService.shared.items(ids: topLevel)
            for c in fetched { await HNCache.shared.storeItem(c, fillSource: .readThrough, pinned: false) }
            fetched = sortComments(fetched)
            comments = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sort: mods first, then current user, then everyone else.
    private func sortComments(_ items: [HNItem]) -> [HNItem] {
        let currentUser = HNAuthService.shared.username
        return items.sorted { a, b in
            let aMod = HNItem.moderators.contains(a.by ?? "")
            let bMod = HNItem.moderators.contains(b.by ?? "")
            let aMe = currentUser != nil && a.by == currentUser
            let bMe = currentUser != nil && b.by == currentUser
            if aMod != bMod { return aMod }
            if aMe != bMe { return aMe }
            return false
        }
    }
}
