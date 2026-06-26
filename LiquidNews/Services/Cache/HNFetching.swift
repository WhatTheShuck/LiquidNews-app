// HNFetching.swift
// Network seam for the cache layer: lets HNCache, the reconciler's callers, and the
// offline-download coordinator run against an injected fake in tests, with HNAPIService
// as the production implementation.

import Foundation

protocol HNFetching: Sendable {
    func item(id: Int) async throws -> HNItem
    func items(ids: [Int]) async throws -> [HNItem]
    func storyIDs(for category: StoryCategory) async throws -> [Int]
}

extension HNAPIService: HNFetching {}
