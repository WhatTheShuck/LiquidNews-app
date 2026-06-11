// StoriesViewModel.swift
// Manages which stories are loaded and handles paging.

import Foundation
import Observation

enum StoryCategory: String, CaseIterable, Identifiable, Hashable {
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
        isLoading = true
        defer { isLoading = false }

        do {
            allIDs = try await Self.storyIDs(for: category)
            // Use the private helper that doesn't guard on isLoading,
            // because we intentionally call this while isLoading is true.
            await appendPage()
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
            let ids = try await Self.storyIDs(for: selectedCategory)
            let end = min(pageSize, ids.count)
            let newItems = try await HNAPIService.shared.items(ids: Array(ids[..<end]))
            allIDs = ids
            stories = newItems
            loadedCount = end
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    /// True for errors produced by cooperative task cancellation —
    /// not real failures, so they should never be shown to the user.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    // MARK: - Private

    /// Records an error for display unless it's a task cancellation.
    private func report(_ error: Error) {
        guard !Self.isCancellation(error) else { return }
        errorMessage = error.localizedDescription
    }

    private static func storyIDs(for category: StoryCategory) async throws -> [Int] {
        let api = HNAPIService.shared
        switch category {
        case .top:      return try await api.topStoryIDs()
        case .new:      return try await api.newStoryIDs()
        case .best:     return try await api.bestStoryIDs()
        case .ask:      return try await api.askStoryIDs()
        case .show:     return try await api.showStoryIDs()
        case .jobs:     return try await api.jobStoryIDs()
        case .classic:  return try await api.webStoryIDs(endpoint: "classic")
        case .active:   return try await api.webStoryIDs(endpoint: "active")
        case .shownew:  return try await api.webStoryIDs(endpoint: "shownew")
        case .asknew:   return try await api.webStoryIDs(endpoint: "asknew")
        case .noob:     return try await api.webStoryIDs(endpoint: "noobstories")
        case .launches: return try await api.webStoryIDs(endpoint: "launches")
        case .pool:     return try await api.webStoryIDs(endpoint: "pool")
        }
    }

    /// Fetches and appends the next slice of allIDs. No loading guards —
    /// callers are responsible for setting appropriate flags before calling.
    private func appendPage() async {
        let end = min(loadedCount + pageSize, allIDs.count)
        guard loadedCount < end else { return }
        let pageIDs = Array(allIDs[loadedCount..<end])

        do {
            let newItems = try await HNAPIService.shared.items(ids: pageIDs)
            stories.append(contentsOf: newItems)
            loadedCount = end
        } catch {
            report(error)
        }
    }
}
