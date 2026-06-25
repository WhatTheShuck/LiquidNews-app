// CommentBodyView.swift
// Rich-mode rendering for HN comment HTML.
//
// Splits comment HTML at <pre> boundaries so code blocks get their own
// dedicated view (scrollable, glassy, copyable) while prose segments are
// parsed via NSAttributedString for inline bold / italic / code / links.

import SwiftUI

// MARK: - Comment body

struct CommentBodyView: View {
    let html: String
    var tintColor: Color = AppTheme.accent

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 14
    @Environment(\.colorScheme) private var colorScheme

    // Parsed representation of one chunk of comment content.
    private struct Segment: Identifiable {
        let id: Int
        enum Content {
            case prose(AttributedString)
            case code(String)
            case quote(AttributedString)
        }
        let content: Content
    }

    // Shared parse cache keyed by "html:scheme" — segments embed CSS colors so they
    // are not valid across color-scheme changes.
    private static var cache: [String: [Segment]] = [:]

    private var cacheKey: String { "\(html):\(colorScheme == .light ? "l" : "d")" }

    /// nil while the first parse hasn't completed yet.
    @State private var segments: [Segment]?

    var body: some View {
        Group {
            if let segments {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { seg in
                        switch seg.content {
                        case .prose(let text):
                            Text(text)
                                .font(.system(size: bodySize))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(tintColor)
                        case .code(let code):
                            CodeBlockView(code: code)
                        case .quote(let text):
                            QuoteBlockView(text: text, tintColor: tintColor)
                        }
                    }
                }
            } else {
                // Fallback shown while parsing or if NSAttributedString parse fails.
                Text(html.htmlStripped)
                    .font(.system(size: bodySize))
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Re-runs whenever html or colorScheme changes; cache gives instant hit on revisit.
        .task(id: cacheKey) {
            if let cached = CommentBodyView.cache[cacheKey] {
                segments = cached
                return
            }
            let parsed = buildSegments(from: html)
            CommentBodyView.cache[cacheKey] = parsed
            segments = parsed
        }
    }

    // MARK: - Segment builder

    /// Splits HTML at `<pre>` blocks and converts each slice to a typed Segment.
    private func buildSegments(from html: String) -> [Segment] {
        var parts: [Segment.Content] = []
        var remaining = html

        while let openRange = remaining.range(of: "<pre>", options: .caseInsensitive) {
            // Prose before this code block
            let proseHTML = String(remaining[..<openRange.lowerBound])
            if !proseHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(contentsOf: splitByQuotes(proseHTML))
            }

            remaining = String(remaining[openRange.upperBound...])

            if let closeRange = remaining.range(of: "</pre>", options: .caseInsensitive) {
                var inner = String(remaining[..<closeRange.lowerBound])
                // Strip optional <code> wrapper that HN wraps inside <pre>
                inner = inner
                    .replacingOccurrences(of: #"(?i)^<code[^>]*>"#,  with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"(?i)</code>\s*$"#,   with: "", options: .regularExpression)
                let code = inner.htmlEntitiesDecoded()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
                if !code.isEmpty {
                    parts.append(.code(code))
                }
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                // Malformed: no closing </pre> — treat rest as a code block
                let code = remaining.htmlEntitiesDecoded().trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty { parts.append(.code(code)) }
                remaining = ""
            }
        }

        // Any prose after the last code block
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(contentsOf: splitByQuotes(remaining))
        }

        // Safety fallback: only reached if every prose chunk and every code block
        // was blank — essentially impossible in practice. Passing the full `html`
        // here is intentional; `splitByQuotes` handles arbitrary prose HTML.
        if parts.isEmpty {
            parts.append(contentsOf: splitByQuotes(html))
        }

        return parts.enumerated().map { Segment(id: $0.offset, content: $0.element) }
    }

    // MARK: - Prose parser

    /// Converts an HTML fragment into an `AttributedString` with inline formatting.
    /// Uses WebKit's HTML engine via NSAttributedString with injected CSS.
    private func parseProse(_ html: String) -> AttributedString? {
        // HN uses <p> as a paragraph separator. NSAttributedString's WebKit mode does not
        // reliably apply CSS padding/margin to <p> elements, so convert them to explicit
        // double line breaks — two <br> tags are always rendered as a blank line between
        // paragraphs regardless of CSS support.
        let processed = html
            .replacingOccurrences(of: #"(?i)</p>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)<p\b[^>]*>"#, with: "<br><br>", options: .regularExpression)
        let textColor = colorScheme == .light ? "#1C1C1E" : "#DCDCDC"
        let boldColor = colorScheme == .light ? "#000000" : "#F0F0F0"
        let styledHTML = """
        <html><head><meta charset="UTF-8"><style>
        body      { font-family: -apple-system; font-size: 14px; color: \(textColor); white-space: pre-line; }
        a         { color: #FF6B14; text-decoration: none; }
        code      { font-family: Menlo, 'SF Mono', monospace; font-size: 12.5px; }
        b, strong { font-weight: 600; color: \(boldColor); 
        }
        
        i, em     { font-style: italic; }
        </style></head><body>\(processed)</body></html>
        """
        guard let data = styledHTML.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let nsAS = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
              nsAS.length > 0
        else { return nil }

        // WebKit always appends a trailing newline — trim it.
        let trailing = nsAS.string.reversed().prefix(while: { $0.isNewline }).count
        let trimmed = trailing > 0
            ? nsAS.attributedSubstring(from: NSRange(location: 0, length: nsAS.length - trailing))
            : nsAS

        return try? AttributedString(trimmed, including: \.uiKit)
    }

    // MARK: - Quote detection helpers

    /// Splits an HTML prose fragment at <p> boundaries, returning each paragraph's
    /// inner HTML as a separate string. Handles both self-closing and paired <p></p>.
    private func paragraphFragments(from html: String) -> [String] {
        // Drop closing </p> tags — HN often omits them anyway
        let noClose = html.replacingOccurrences(
            of: #"(?i)</p>"#, with: "", options: .regularExpression)
        guard let regex = try? NSRegularExpression(
            pattern: #"<p\b[^>]*>"#, options: .caseInsensitive) else {
            return [html]
        }
        let nsStr = noClose as NSString
        var results: [String] = []
        var lastEnd = 0
        for match in regex.matches(
            in: noClose, range: NSRange(location: 0, length: nsStr.length)) {
            let fragment = nsStr.substring(
                with: NSRange(location: lastEnd,
                              length: match.range.location - lastEnd))
            if !fragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results.append(fragment)
            }
            lastEnd = match.range.upperBound
        }
        let tail = nsStr.substring(from: lastEnd)
        if !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(tail)
        }
        return results.isEmpty ? [html] : results
    }

    /// Returns true when an HTML paragraph fragment is an HN quote line (starts with &gt; or >).
    private func isQuoteParagraph(_ html: String) -> Bool {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("&gt;") || trimmed.hasPrefix(">")
    }

    /// Strips the leading > / &gt; prefix (and optional whitespace / &nbsp;) from a paragraph fragment.
    private func strippedQuotePrefix(_ html: String) -> String {
        var s = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("&gt;") { s = String(s.dropFirst(4)) }
        else if s.hasPrefix(">") { s = String(s.dropFirst(1)) }
        // Strip any leading whitespace or &nbsp; entity between the > and the content
        while s.hasPrefix(" ") || s.hasPrefix("\t") { s = String(s.dropFirst(1)) }
        if s.hasPrefix("&nbsp;") { s = String(s.dropFirst(6)) }
        return s
    }

    /// Splits a prose HTML fragment into an ordered sequence of `.prose` and `.quote`
    /// segment contents by grouping consecutive paragraphs of the same type.
    private func splitByQuotes(_ proseHTML: String) -> [Segment.Content] {
        let fragments = paragraphFragments(from: proseHTML)

        // Group consecutive same-type paragraphs
        var groups: [(isQuote: Bool, parts: [String])] = []
        for frag in fragments {
            let q = isQuoteParagraph(frag)
            if groups.last?.isQuote == q {
                groups[groups.count - 1].parts.append(frag)
            } else {
                groups.append((isQuote: q, parts: [frag]))
            }
        }

        var results: [Segment.Content] = []
        for group in groups {
            let joined: String
            if group.isQuote {
                joined = group.parts.map { strippedQuotePrefix($0) }.joined(separator: "<p>")
                if let attrStr = parseProse(joined) { results.append(.quote(attrStr)) }
            } else {
                joined = group.parts.joined(separator: "<p>")
                if let attrStr = parseProse(joined) { results.append(.prose(attrStr)) }
            }
        }
        return results
    }
}

// MARK: - Code block view

private struct CodeBlockView: View {
    let code: String

    @State private var copied = false
    @State private var settings = UserSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header bar ──
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("code")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Spacer()
                // Copy button
                Button {
                    UIPasteboard.general.string = code
                    withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.primary.opacity(0.35))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Separator between header and code area
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            // ── Code area: scrollable or wrapping ──
            if settings.codeWrapLines {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }
        }
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Quote block view

private struct QuoteBlockView: View {
    let text: AttributedString
    var tintColor: Color = AppTheme.accent

    @ScaledMetric(relativeTo: .footnote) private var quoteSize: CGFloat = 12

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1)
                .fill(tintColor.opacity(0.6))
                .frame(width: 2)

            Text(text)
                .font(.system(size: quoteSize))
                .foregroundStyle(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .tint(AppTheme.accent)
        }
    }
}

// MARK: - HTML entity decoder (file-private)

private extension String {
    func htmlEntitiesDecoded() -> String {
        self
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

// MARK: - Preview

#Preview("Rich comment with code") {
    ZStack {
        AppTheme.backgroundGradient(for: .dark).ignoresSafeArea()
        ScrollView {
            CommentBodyView(html: PreviewData.richComment.text ?? "")
                .padding()
        }
    }
}

// MARK: - Shared body renderer

/// Three-mode comment body renderer. Used by `CommentView` and the
/// self-post body in `StoryDetailView`.
@ViewBuilder
func CommentBodyContent(
    text: String,
    mode: CommentRenderMode,
    tintColor: Color = AppTheme.accent
) -> some View {
    switch mode {
    case .textOnly:
        Text(text.htmlStripped)
            .font(.system(size: 14))
            .foregroundStyle(.primary.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    case .textWithLinks:
        Text(text.htmlWithLinks)
            .font(.system(size: 14))
            .foregroundStyle(.primary.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
            .tint(AppTheme.accent)
    case .rich:
        CommentBodyView(html: text, tintColor: tintColor)
    }
}
