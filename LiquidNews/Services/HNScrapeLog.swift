// HNScrapeLog.swift
// Single breakage signal for HN HTML scraping.
//
// HN has no public API for votes, flags, replies, or several feed categories, so those
// paths string-match HN's unversioned markup (see `HNAuthService` and
// `HNAPIService.parseHNStoryIDs`). When HN tweaks its HTML, a parser silently returns
// nil/[] and the action quietly does nothing. Every parser routes its empty result
// through here so there is one greppable place — filter the log by category
// `hn-markup` to notice breakage.

import Foundation
import os

enum HNScrapeLog {
    private static let logger = Logger(subsystem: "com.liquidnews.app", category: "hn-markup")

    /// Record that a scrape parser found nothing where it expected a match — the most
    /// likely fingerprint of an HN markup change. `parser` names the call site; `context`
    /// adds any disambiguating detail (e.g. the item ID or endpoint).
    static func parseReturnedEmpty(_ parser: StaticString, context: String = "") {
        logger.error("HN markup may have changed — \(parser, privacy: .public) parsed no match \(context, privacy: .public)")
    }
}
