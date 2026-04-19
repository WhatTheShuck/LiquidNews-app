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

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 14

    // Parsed representation of one chunk of comment content.
    private struct Segment: Identifiable {
        let id: Int
        enum Content {
            case prose(AttributedString)
            case code(String)
        }
        let content: Content
    }

    /// nil while the first parse hasn't completed yet.
    @State private var segments: [Segment]? = nil

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
                                .tint(AppTheme.accent)
                        case .code(let code):
                            CodeBlockView(code: code)
                        }
                    }
                }
            } else {
                // Shown for a frame while the NSAttributedString parse runs.
                Text(html.htmlStripped)
                    .font(.system(size: bodySize))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Re-parse if the html ever changes (comments are immutable in practice).
        .task(id: html) {
            segments = buildSegments(from: html)
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
            if !proseHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let attrStr = parseProse(proseHTML) {
                parts.append(.prose(attrStr))
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
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let attrStr = parseProse(remaining) {
            parts.append(.prose(attrStr))
        }

        // Fallback: if splitting produced nothing, parse the whole thing as prose
        if parts.isEmpty, let attrStr = parseProse(html) {
            parts.append(.prose(attrStr))
        }

        return parts.enumerated().map { Segment(id: $0.offset, content: $0.element) }
    }

    // MARK: - Prose parser

    /// Converts an HTML fragment into an `AttributedString` with inline formatting.
    /// Uses WebKit's HTML engine via NSAttributedString with injected CSS.
    private func parseProse(_ html: String) -> AttributedString? {
        let styledHTML = """
        <html><head><meta charset="UTF-8"><style>
        body      { font-family: -apple-system; font-size: 14px; color: #DCDCDC; }
        a         { color: #FF6B14; text-decoration: none; }
        code      { font-family: Menlo, 'SF Mono', monospace; font-size: 12.5px; }
        b, strong { font-weight: 600; color: #F0F0F0; }
        i, em     { font-style: italic; }
        p         { margin: 0; padding: 0 0 8px 0; }
        </style></head><body>\(html)</body></html>
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
}

// MARK: - Code block view

private struct CodeBlockView: View {
    let code: String

    @State private var copied = false

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
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Separator between header and code area
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // ── Scrollable code area ──
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(3)
                    // Prevent text from wrapping — each source line stays on one line.
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .glassCard(cornerRadius: 12)
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
        AppTheme.backgroundGradient.ignoresSafeArea()
        ScrollView {
            CommentBodyView(html: PreviewData.richComment.text ?? "")
                .padding()
        }
    }
    .preferredColorScheme(.dark)
}
