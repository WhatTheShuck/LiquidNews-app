// SearchViewModel.swift
// View model and date-filter enum for HN search via Algolia.

import Foundation
import Observation

// MARK: - Date filter

enum SearchDateFilter: String, CaseIterable, Identifiable {
    case day       = "Day"
    case threeDays = "3 Days"
    case week      = "Week"
    case month     = "Month"
    case year      = "Year"
    case custom    = "Custom"

    var id: String { rawValue }

    /// The earliest date for this filter (ignored for .custom).
    func since() -> Date {
        let cal = Calendar.current
        switch self {
        case .day:       return cal.date(byAdding: .day,        value: -1,  to: .now)!
        case .threeDays: return cal.date(byAdding: .day,        value: -3,  to: .now)!
        case .week:      return cal.date(byAdding: .weekOfYear, value: -1,  to: .now)!
        case .month:     return cal.date(byAdding: .month,      value: -1,  to: .now)!
        case .year:      return cal.date(byAdding: .year,       value: -1,  to: .now)!
        case .custom:    return .now
        }
    }
}

// MARK: - ViewModel

@Observable
final class SearchViewModel {
    var query = ""
    var dateFilter: SearchDateFilter = .week
    /// Only used when dateFilter == .custom
    var customSince: Date = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now)!

    var results: [HNItem] = []
    var isSearching = false
    var errorMessage: String?

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        let since = dateFilter == .custom ? customSince : dateFilter.since()
        do {
            results = try await HNAPIService.shared.searchStories(query: trimmed, since: since)
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }
}
