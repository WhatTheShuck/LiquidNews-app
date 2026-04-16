// SiteRules.swift
// Per-domain extraction rules that pre-process the DOM before (or instead of) Readability.
//
// How it works:
//   Each SiteRule declares the domains it covers, optional CSS selectors for noise to
//   strip, an optional content selector to focus on, and a flag for whether to return
//   that element's HTML directly (bypassing Readability entirely).
//
//   `preprocessingJS` generates a JavaScript fragment that is injected into the
//   extraction IIFE in ArticleReaderView, just before Readability runs.  If the
//   preprocessing returns early (useDirectContent = true and the selector matched),
//   Readability is skipped completely.  If the selector is absent or not found in the
//   DOM, execution falls through to Readability as normal — so every rule degrades
//   gracefully.

import Foundation

// MARK: - Model

struct SiteRule {
    /// Matched when the URL host equals or is a subdomain of any entry.
    /// E.g. "github.com" matches "github.com" and "gist.github.com".
    let domains: [String]

    /// CSS selectors for DOM nodes to delete before extraction.
    let stripSelectors: [String]

    /// If provided, only this element's subtree is passed to Readability
    /// (or returned directly when `useDirectContent` is true).
    let contentSelector: String?

    /// When true the element's `innerHTML` is returned as the article content
    /// without running Readability — useful for sites with already-clean HTML.
    let useDirectContent: Bool

    init(
        domains: [String],
        strip: [String] = [],
        content: String? = nil,
        direct: Bool = false
    ) {
        self.domains    = domains
        stripSelectors  = strip
        contentSelector = content
        useDirectContent = direct
    }

    /// Returns true when this rule should apply to `url`.
    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return domains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }
    }

    /// JavaScript injected into the extraction IIFE before Readability runs.
    /// Selectors are injected with double-quote JS string delimiters so that
    /// CSS selectors containing single-quotes don't break the script.
    var preprocessingJS: String {
        var parts: [String] = []

        // ── Strip noise elements ──────────────────────────────────────────
        if !stripSelectors.isEmpty {
            let selList = stripSelectors
                .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
                .joined(separator: ",")
            parts.append("""
            [\(selList)].forEach(function(s){
                document.querySelectorAll(s).forEach(function(el){el.remove();});
            });
            """)
        }

        // ── Content focus ─────────────────────────────────────────────────
        guard let selector = contentSelector else { return parts.joined(separator: "\n") }
        let esc = selector.replacingOccurrences(of: "\"", with: "\\\"")

        if useDirectContent {
            // Return the element's HTML directly — skips Readability entirely.
            // Falls through to Readability if the selector isn't found.
            parts.append("""
            var _lnEl = document.querySelector("\(esc)");
            if (_lnEl) {
                return JSON.stringify({
                    title:    document.title,
                    byline:   null,
                    content:  _lnEl.innerHTML,
                    excerpt:  null,
                    siteName: location.hostname.replace(/^www\\./, ''),
                    length:   _lnEl.textContent.length
                });
            }
            """)
        } else {
            // Narrow the document body so Readability focuses on just this element.
            parts.append("""
            var _lnEl = document.querySelector("\(esc)");
            if (_lnEl) {
                document.body.innerHTML = '';
                var _wrap = document.createElement('article');
                _wrap.innerHTML = _lnEl.innerHTML;
                document.body.appendChild(_wrap);
            }
            """)
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Registry

enum SiteRules {

    /// All built-in domain rules, evaluated in order — first match wins.
    static let all: [SiteRule] = [

        // ── GitHub ────────────────────────────────────────────────────────
        // Readability frequently stumbles on GitHub's DOM — it either pulls in
        // nav chrome or marks the page as too short.  The rendered markdown body
        // is already clean HTML, so we return it directly.
        SiteRule(
            domains: ["github.com", "gist.github.com"],
            strip: ["#repository-container-header", ".repository-sidebar",
                    ".file-navigation", ".commit-tease", "nav", "header",
                    ".js-repo-filter", ".pagehead"],
            content: "article.markdown-body, #readme article.markdown-body, .blob-wrapper",
            direct: true
        ),

        // ── Wikipedia ─────────────────────────────────────────────────────
        // Strip navigational chrome, infoboxes and citation clutter; keep the
        // article prose so Readability can clean it up.
        SiteRule(
            domains: ["wikipedia.org"],
            strip: [".navbox", ".navbox-inner", ".sidebar", ".mw-editsection",
                    "#toc", ".reflist", ".references", "#catlinks",
                    ".mw-indicators", ".hatnote", ".noprint"],
            content: "#mw-content-text .mw-parser-output, #bodyContent",
            direct: false
        ),

        // ── Stack Overflow / Stack Exchange ───────────────────────────────
        // Keep the question body and the accepted (or top-voted) answer.
        SiteRule(
            domains: ["stackoverflow.com", "stackexchange.com",
                      "superuser.com", "serverfault.com", "askubuntu.com"],
            strip: [".sidebar", "#hot-network-questions", ".s-sidebarwidget",
                    ".js-dismissable-hero", ".everyonelovesstackoverflow",
                    "#answers-header", ".post-menu-share"],
            content: "#question, #answers",
            direct: false
        ),

        // ── Medium ────────────────────────────────────────────────────────
        // Remove the paywall overlay, subscription nag and navigation so
        // Readability can focus on the article prose.
        SiteRule(
            domains: ["medium.com"],
            strip: ["[data-testid='paywall']", "nav", ".metabar",
                    "[class*='overlay']", "[class*='popover']",
                    "[class*='upsell']"],
            content: "article",
            direct: false
        ),

        // ── Substack ──────────────────────────────────────────────────────
        SiteRule(
            domains: ["substack.com"],
            strip: ["header", "footer", ".subscription-widget",
                    ".paywall", ".paywall-cta"],
            content: ".post-content, article",
            direct: false
        ),

        // ── Hacker News ───────────────────────────────────────────────────
        // HN posts don't have article bodies — surface the comment thread
        // instead of failing extraction.
        SiteRule(
            domains: ["news.ycombinator.com"],
            strip: [".votelinks", ".pagetop", ".hnmore"],
            content: ".comment-tree, #hnmain",
            direct: false
        ),
    ]

    /// Returns the first rule whose domains include `url`'s host, or `nil`.
    static func match(url: URL) -> SiteRule? {
        all.first { $0.matches(url) }
    }
}
