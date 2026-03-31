// CommentRenderMode.swift
// Controls how comment text is parsed and rendered in CommentView.
// Three levels: plain text, text with tappable links, or full rich rendering.

import Foundation
import SwiftUI

// MARK: - Render mode

enum CommentRenderMode: String, CaseIterable {
    case textOnly      = "textOnly"       // plain text, full URLs preserved (no truncation)
    case textWithLinks = "textWithLinks"  // plain text + tappable orange links
    case rich          = "rich"           // full HTML: bold, italic, code blocks, links

    var label: String {
        switch self {
        case .textOnly:      "Text Only"
        case .textWithLinks: "Text + Links"
        case .rich:          "Full"
        }
    }

    var subtitle: String {
        switch self {
        case .textOnly:      "Plain text, full URLs shown"
        case .textWithLinks: "Plain text with tappable links"
        case .rich:          "Formatting, code blocks, links"
        }
    }

    var systemImage: String {
        switch self {
        case .textOnly:      "text.alignleft"
        case .textWithLinks: "link"
        case .rich:          "textformat.alt"
        }
    }
}

// MARK: - Text + Links rendering

extension String {
    /// Converts HN HTML into an `AttributedString` with tappable links in HN orange.
    /// Other HTML tags are stripped to plain text. Long URLs are shown in full (extracted
    /// from the anchor `href`, since HN truncates display text for long URLs).
    var htmlWithLinks: AttributedString {
        // Convert <p> tags to paragraph breaks before processing anchors
        let html = replacingOccurrences(of: "<p>", with: "\n\n")

        var result = AttributedString()

        // Match <a href="URL">display text</a>
        let pattern = #"<a\s[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return AttributedString(html.htmlStripped)
        }

        let nsHtml = html as NSString
        var lastEnd = 0

        for match in regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length)) {
            // ── Plain text before this anchor ──
            if match.range.location > lastEnd {
                let pre = nsHtml.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                let plain = pre.hnTagsStripped()
                if !plain.isEmpty { result += AttributedString(plain) }
            }

            // ── Extract href and display text ──
            let href = match.range(at: 1).location != NSNotFound
                ? nsHtml.substring(with: match.range(at: 1))
                : ""

            let rawDisplay = match.range(at: 2).location != NSNotFound
                ? nsHtml.substring(with: match.range(at: 2)).hnTagsStripped()
                : ""

            // HN truncates long URL display text with "…" — use the full href in that case
            let displayText: String
            if href.hasPrefix("http") && (rawDisplay.hasSuffix("…") || rawDisplay.hasSuffix("...") || rawDisplay.isEmpty) {
                displayText = href
            } else {
                displayText = rawDisplay.isEmpty ? href : rawDisplay
            }

            // ── Build the tappable link span ──
            var linkAS = AttributedString(displayText)
            if let url = URL(string: href) {
                linkAS.link = url
            }
            linkAS[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = AppTheme.accent
            result += linkAS

            lastEnd = match.range.upperBound
        }

        // ── Remaining text after the last anchor ──
        if lastEnd < nsHtml.length {
            let tail = nsHtml.substring(from: lastEnd).hnTagsStripped()
            if !tail.isEmpty { result += AttributedString(tail) }
        }

        return result
    }
}

// MARK: - Shared HTML stripping helper

private extension String {
    /// Strips all remaining HTML tags and decodes common HTML entities.
    /// Used internally when building attributed strings.
    func hnTagsStripped() -> String {
        var s = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return s
    }
}
