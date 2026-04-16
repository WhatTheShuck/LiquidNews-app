// ReadabilityArticle.swift
// The structured article content returned by the extraction pipeline.

import Foundation

struct ReadabilityArticle {
    /// Page / article title. Falls back to document.title if og:title is absent.
    let title: String
    /// Author name(s), if discoverable in the page.
    let byline: String?
    /// The article's main body as an HTML string, ready to inject into a template.
    let content: String
    /// Short description (meta description or og:description).
    let excerpt: String?
    /// Site / publication name (og:site_name or hostname).
    let siteName: String?
    /// Original URL — used as the WKWebView base URL so relative links resolve.
    let url: URL
}
