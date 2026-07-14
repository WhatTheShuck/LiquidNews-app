// StoriesViewModel.swift
// Manages which stories are loaded and handles paging.

import Foundation
import Observation
import SwiftUI

nonisolated enum StoryCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case top      = "Top"
    case new      = "New"
    case best     = "Best"
    case ask      = "Ask HN"
    case show     = "Show HN"
    case jobs     = "Jobs"
    case classic  = "Classic"
    case active   = "Active"
    case shownew  = "Show New"
    case asknew   = "Ask New"
    case noob     = "Noob"
    case launches = "Launches"
    case pool     = "Pool"

    var id: String { rawValue }

    /// The default set shown on first launch, in order.
    static let defaults: [StoryCategory] = [.top, .new, .best, .ask, .show]
}

@Observable
final class StoriesViewModel {

    // MARK: - View-visible state

    var stories: [HNItem] = []
    var isLoading = false       // true during initial/refresh load — shows full-screen spinner
    var isPaginating = false    // true while fetching the next page — shows inline spinner
    var errorMessage: String?
    var selectedCategory: StoryCategory = .top

    /// Gates the card entrance animation to load events. A generation opens
    /// whenever the feed is populated wholesale (initial load, category switch,
    /// pull-to-refresh) — never for pagination appends.
    let entrance = FeedEntranceCoordinator()

    // MARK: - Paging

    private let pageSize = 20
    private var allIDs: [Int] = []
    private var loadedCount = 0

    // MARK: - Public interface

    /// Load the first page for a category. Resets all state first.
    func load(category: StoryCategory) async {
        selectedCategory = category
        stories = []
        allIDs = []
        loadedCount = 0
        errorMessage = nil

        // Phase 1: instant cached snapshot, if any.
        if let cachedIDs = await HNCache.shared.cachedFeed(category), !cachedIDs.isEmpty {
            allIDs = cachedIDs
            let end = min(pageSize, cachedIDs.count)
            let cached = await HNCache.shared.cachedItems(ids: cachedIDs.prefix(end))
            // Generation opens as the content lands (not at call start), so a
            // slow read can't eat into the entrance-animation window.
            entrance.beginGeneration()
            stories = cached
            loadedCount = end
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
            let ids = try await HNAPIService.shared.storyIDs(for: category)
            await HNCache.shared.storeFeed(ids, category: category, fillSource: .readThrough)
            allIDs = ids
            let end = min(pageSize, ids.count)
            let fresh = try await HNAPIService.shared.items(ids: Array(ids[..<end]))
            for item in fresh { await HNCache.shared.storeItem(item, fillSource: .readThrough, pinned: false) }
            let reconciled = CacheReconciler.reconcile(displayed: stories, fresh: fresh)
            if stories.isEmpty {
                // Nothing cached: this is the initial population. Unanimated —
                // the entrance modifier animates each card individually, and a
                // surrounding transaction would make lazily-realised rows fly in.
                entrance.beginGeneration()
                stories = reconciled
            } else {
                // Cached snapshot already showing (same generation).
                replaceStories(with: reconciled)
            }
            loadedCount = end
        } catch {
            report(error)
        }
    }

    /// Called from the scroll view when the user approaches the bottom.
    func loadNextPage() async {
        // Don't fire while already loading or paginating, and stop at the end.
        guard !isLoading, !isPaginating, loadedCount < allIDs.count else { return }
        isPaginating = true
        defer { isPaginating = false }
        await appendPage()
    }

    /// Pull-to-refresh. Unlike `load`, this keeps the current stories on
    /// screen while fetching: clearing them would swap the List out for the
    /// skeleton view, and SwiftUI cancels the `.refreshable` task when the
    /// List leaves the hierarchy — surfacing a spurious "cancelled" error.
    /// New content replaces the old atomically on success.
    func refresh() async {
        // Nothing on screen to preserve (e.g. the first load failed),
        // so a full resetting load is fine here.
        guard !stories.isEmpty else {
            await load(category: selectedCategory)
            return
        }

        do {
            let ids = try await HNAPIService.shared.storyIDs(for: selectedCategory)
            let end = min(pageSize, ids.count)
            let newItems = try await HNAPIService.shared.items(ids: Array(ids[..<end]))
            await HNCache.shared.storeFeed(ids, category: selectedCategory, fillSource: .readThrough)
            for item in newItems { await HNCache.shared.storeItem(item, fillSource: .readThrough, pinned: false) }
            allIDs = ids
            // A refresh is a load event: rows that survive keep their identity
            // (no re-entrance), genuinely new rows cascade in.
            entrance.beginGeneration()
            replaceStories(with: newItems)
            loadedCount = end
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    // MARK: - Private

    /// Replaces the displayed stories while rows are already on screen.
    ///
    /// Animated only when the row set and order are unchanged (pure field
    /// updates — heights glide, nothing is inserted). Any structural change is
    /// applied unanimated: a transaction over a List insertion makes the new
    /// cells fly in from the top (the landmine documented in FeedEntrance),
    /// and genuinely new rows get their motion from the entrance modifier
    /// instead.
    private func replaceStories(with newStories: [HNItem]) {
        if newStories.map(\.id) == stories.map(\.id) {
            withAnimation(.smooth) {
                stories = newStories
            }
        } else {
            stories = newStories
        }
    }

    /// Records an error for display unless it's a task cancellation.
    private func report(_ error: Error) {
        guard !error.isCancellation else { return }
        errorMessage = error.localizedDescription
    }

    /// Fetches and appends the next slice of allIDs. No loading guards —
    /// callers are responsible for setting appropriate flags before calling.
    private func appendPage() async {
        let end = min(loadedCount + pageSize, allIDs.count)
        guard loadedCount < end else { return }
        let pageIDs = Array(allIDs[loadedCount..<end])

        do {
            let newItems = try await HNAPIService.shared.items(ids: pageIDs)
            for item in newItems { await HNCache.shared.storeItem(item, fillSource: .readThrough, pinned: false) }
            // Pagination is never a load event: a fast page 2 can land while
            // the entrance window from the initial load is still open, so
            // pre-mark these rows to keep them out of the cascade.
            entrance.markSettled(newItems.map(\.id))
            stories.append(contentsOf: newItems)
            loadedCount = end
        } catch {
            report(error)
        }
    }
}
