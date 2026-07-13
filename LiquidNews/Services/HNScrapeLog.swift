// HNScrapeLog.swift
// Single breakage signal for HN HTML scraping.
//
// HN has no public API for votes, flags, replies, or several feed categories, so those
// paths string-match HN's unversioned markup (see `HNAuthService` and
// `HNAPIService.parseHNStoryIDs`). When HN tweaks its HTML, a parser silently returns
// nil/[] and the action quietly does nothing. Every parser routes its empty result
// through here so there is one greppable place — filter the log by category
// `hn-markup` to notice breakage.
//
// Not every empty parse is breakage, though: an expired session renders no auth
// links, an already-voted item only carries the opposite link, gated feeds serve a
// login wall. Parsers classify those known states and report them via
// `parseEmptyExpected` (debug) so the error-level breakage signal stays trustworthy.

import Foundation
import os

enum HNScrapeLog {
    /// Record that a scrape parser found nothing where it expected a match — the most
    /// likely fingerprint of an HN markup change. `parser` names the call site; `context`
    /// adds any disambiguating detail (e.g. the item ID or endpoint).
    /// Call only after the recognised benign states have been ruled out.
    static func parseReturnedEmpty(_ parser: StaticString, context: String = "") {
        Logger.hnMarkup.error("HN markup may have changed — \(parser, privacy: .public) parsed no match \(context, privacy: .public)")
    }

    /// Record an empty parse with a recognised benign cause (expired session, vote-state
    /// desync, rate limiting, login-gated page). Debug level: visible when filtering the
    /// `hn-markup` category, but never mistaken for a markup change.
    static func parseEmptyExpected(_ parser: StaticString, reason: String) {
        Logger.hnMarkup.debug("\(parser, privacy: .public) parsed no match — expected state: \(reason, privacy: .public)")
    }
}
