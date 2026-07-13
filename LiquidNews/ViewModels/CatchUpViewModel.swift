// CatchUpViewModel.swift
// State and business logic for the Catch-up tab.
// Fetches HN stories within a user-selected date range via Algolia.

import Foundation
import Observation
import os

// MARK: - Date range presets

enum CatchUpPreset: String, CaseIterable, Identifiable {
    case yesterday = "Yesterday"
    case week      = "This Week"
    case month     = "This Month"
    case custom    = "Custom"

    var id: String { rawValue }

    /// The (from, to) date range for preset values. Ignored for .custom.
    func dateRange() -> (from: Date, to: Date) {
        let now = Date.now
        let cal = Calendar.current
        switch self {
        case .yesterday: return (cal.date(byAdding: .day,        value: -1,  to: now)!, now)
        case .week:      return (cal.date(byAdding: .weekOfYear, value: -1,  to: now)!, now)
        case .month:     return (cal.date(byAdding: .month,      value: -1,  to: now)!, now)
        case .custom:    return (now, now) // unused — ViewModel uses customFrom/To directly
        }
    }
}

// MARK: - Sort mode

enum CatchUpSortMode: String, CaseIterable {
    case top    = "Top"
    case recent = "Recent"

    var icon: String {
        switch self {
        case .top:    "arrow.up"
        case .recent: "clock"
        }
    }
}

// MARK: - ViewModel

@Observable
final class CatchUpViewModel {

    // Controls
    var preset: CatchUpPreset = .week
    var customFrom: Date = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now)!
    var customTo:   Date = .now
    var sortMode: CatchUpSortMode = .top

    // Feed state
    var stories: [HNItem] = []
    var isLoading    = false
    var isPaginating = false
    var errorMessage: String?

    private var currentPage = 0
    private var totalPages  = 0

    // MARK: - Computed

    var effectiveDateRange: (from: Date, to: Date) {
        preset == .custom ? (customFrom, customTo) : preset.dateRange()
    }

    /// Short label shown in the compact toolbar pill when controls are scrolled away.
    var compactTitle: String {
        switch preset {
        case .yesterday: return "Yesterday · \(sortMode.rawValue)"
        case .week:      return "This Week · \(sortMode.rawValue)"
        case .month:     return "This Month · \(sortMode.rawValue)"
        case .custom:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: customFrom)) – \(fmt.string(from: customTo))"
        }
    }

    // MARK: - Loading

    func load() async {
        isLoading    = true
        errorMessage = nil
        stories      = []
        currentPage  = 0
        totalPages   = 0
        defer { isLoading = false }

        let range = effectiveDateRange
        do {
            let result = try await HNAPIService.shared.topStoriesInRange(
                from: range.from, to: range.to,
                sortByDate: sortMode == .recent,
                page: 0
            )
            stories     = result.stories
            totalPages  = result.totalPages
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadNextPage() async {
        guard !isPaginating, currentPage + 1 < totalPages else { return }
        isPaginating = true
        defer { isPaginating = false }

        let range = effectiveDateRange
        do {
            let result = try await HNAPIService.shared.topStoriesInRange(
                from: range.from, to: range.to,
                sortByDate: sortMode == .recent,
                page: currentPage + 1
            )
            stories.append(contentsOf: result.stories)
            currentPage += 1
        } catch {
            // Non-critical: pagination failure just leaves the current page in place. Log for diagnosis.
            Logger.feed.debug("CatchUp: loadNextPage failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refresh() async {
        await load()
    }
}
