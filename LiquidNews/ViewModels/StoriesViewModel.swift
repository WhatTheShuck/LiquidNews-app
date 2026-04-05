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
            let api = HNAPIService.shared
            allIDs = try await {
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
            }()
            // Use the private helper that doesn't guard on isLoading,
            // because we intentionally call this while isLoading is true.
            await appendPage()
        } catch {
            errorMessage = error.localizedDescription
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

    /// Pull-to-refresh.
    func refresh() async {
        await load(category: selectedCategory)
    }

    // MARK: - Private

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
            errorMessage = error.localizedDescription
        }
    }
}
