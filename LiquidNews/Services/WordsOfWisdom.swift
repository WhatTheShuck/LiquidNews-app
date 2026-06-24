// WordsOfWisdom.swift
// Hand-curated goofy quotes shown on the reader loading screen when the
// "Words of Wisdom" setting is enabled. Add new quotes to `quotes`.

import Foundation

enum WordsOfWisdom {
    static let quotes: [String] = [
        "Lucky boys get pizza",
    ]

    /// A random quote, or "" if the list is somehow empty.
    static var random: String { quotes.randomElement() ?? "" }
}
