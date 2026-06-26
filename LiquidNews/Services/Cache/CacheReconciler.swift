// CacheReconciler.swift
// Pure merge of freshly-fetched items into the currently-displayed list. Keeps the
// displayed order stable (so scroll position and identity are preserved) while applying
// fresh field values, dropping items gone from upstream, and appending newcomers.

import Foundation

enum CacheReconciler {

    static func reconcile(displayed: [HNItem], fresh: [HNItem]) -> [HNItem] {
        let freshByID = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })

        // 1. Displayed items still present upstream, in displayed order, with fresh fields.
        var result = displayed.compactMap { freshByID[$0.id] }

        // 2. Items new in fresh (not previously displayed), appended in fresh order.
        let displayedIDs = Set(displayed.map(\.id))
        result.append(contentsOf: fresh.filter { !displayedIDs.contains($0.id) })

        return result
    }
}
