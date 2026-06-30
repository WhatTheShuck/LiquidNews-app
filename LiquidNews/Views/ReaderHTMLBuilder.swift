// ReaderHTMLBuilder.swift
// Builds the reader's self-contained HTML documents (article + Imgur gallery).
// Extracted from the WKWebView Coordinator so the markup can be unit-tested.

import Foundation

enum ReaderHTMLBuilder {

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// The clean reader document for a Readability-extracted article.
    static func article(title: String, byline: String?,
                        siteName: String?, content: String,
                        baseURL: URL) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
        <style>\(readerCSS)</style>
        </head>
        <body class="no-images">
        <div class="header">
            \(siteName.map { "<p class='site'>\(esc($0))</p>" } ?? "")
            <h1>\(esc(title))</h1>
            \(byline.map { "<p class='byline'>\(esc($0))</p>" } ?? "")
        </div>
        <div class="content">
        \(content)
        </div>
        </body>
        </html>
        """
    }

    /// The reader document for an Imgur image page. Body carries class `image-page`
    /// (NOT `no-images`) so the images always render. Title is escaped (attacker-
    /// influenced og:title); image URLs are pre-validated by ImgurResolver.
    static func gallery(content: ImgurContent, baseURL: URL) -> String {
        let titleHTML = content.title.map { "<h1>\(esc($0))</h1>" } ?? ""
        let count = content.images.count
        let imgsHTML = content.images.enumerated()
            .map { index, url in
                let u = esc(url.absoluteString)
                return "<a class=\"ln-img\" href=\"\(u)\" aria-label=\"Image \(index + 1) of \(count)\"><img src=\"\(u)\" alt=\"\"></a>"
            }
            .joined(separator: "\n")
        return """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
<style>\(readerCSS)</style>
</head>
<body class="image-page">
<div class="header">
    <p class='site'>Imgur</p>
    \(titleHTML)
</div>
<div class="content">
\(imgsHTML)
</div>
</body>
</html>
"""
    }

    // Colours match AppTheme: accent = rgb(255,107,20), bg = indigo-to-near-black.
    // CSS custom properties (--bg, --text, --dim, --heading, --border, --code-bg, --font)
    // are overridden live via JS when the user changes preferences in the reader toolbar.
    static let readerCSS = """
    :root {
        --bg:      #0f0f1a;
        --text:    #e8e8ee;
        --dim:     #8888aa;
        --heading: #ffffff;
        --accent:  #ff6b14;
        --border:  rgba(255,255,255,0.10);
        --code-bg: rgba(255,255,255,0.06);
        --font:    -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
        --mono:    'SF Mono', ui-monospace, Menlo, monospace;
    }
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { background: var(--bg); font-size: 18px; }
    body {
        max-width: 680px; margin: 0 auto; padding: 28px 20px 100px;
        font-family: var(--font); font-size: 1rem; line-height: 1.78;
        color: var(--text); background: var(--bg);
        -webkit-font-smoothing: antialiased;
        word-wrap: break-word; overflow-wrap: break-word;
    }
    .header {
        margin-bottom: 28px; padding-bottom: 20px;
        border-bottom: 1px solid var(--border);
    }
    .site {
        font-size: 0.7rem; font-weight: 600; letter-spacing: 0.09em;
        text-transform: uppercase; color: var(--accent); margin-bottom: 10px;
    }
    .header h1 {
        font-size: 1.65rem; font-weight: 700; line-height: 1.25;
        color: var(--heading); margin: 0 0 10px;
    }
    .byline { font-size: 0.82rem; color: var(--dim); margin-top: 8px; }
    .content p { margin: 0.9em 0; }
    .content > p:first-child { margin-top: 0; }
    h1, h2, h3, h4, h5, h6 {
        color: var(--heading); font-weight: 700; line-height: 1.3; margin: 1.8em 0 0.5em;
    }
    h2 { font-size: 1.3rem; } h3 { font-size: 1.1rem; }
    h4, h5, h6 { font-size: 1rem; color: var(--text); }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    img, video {
        max-width: 100%; height: auto; display: block;
        border-radius: 10px; margin: 1.2em auto;
    }
    .ln-img { display: block; cursor: zoom-in; }
    figure { margin: 1.4em 0; text-align: center; }
    figcaption { font-size: 0.78rem; color: var(--dim); margin-top: 6px; font-style: italic; }
    pre {
        background: var(--code-bg); border: 1px solid var(--border);
        border-radius: 10px; padding: 16px 18px; overflow-x: auto;
        margin: 1.2em 0; font-size: 0.84rem; line-height: 1.55;
    }
    code {
        font-family: var(--mono); font-size: 0.875em;
        background: var(--code-bg); padding: 2px 6px; border-radius: 5px; color: var(--text);
    }
    pre code { background: transparent; padding: 0; font-size: inherit; color: inherit; }
    blockquote {
        border-left: 3px solid var(--accent); margin: 1.2em 0;
        padding: 8px 18px; color: var(--dim); font-style: italic;
        background: var(--code-bg); border-radius: 0 8px 8px 0;
    }
    blockquote p { margin: 0.4em 0; }
    ul, ol { padding-left: 1.6em; margin: 0.9em 0; }
    li { margin: 0.3em 0; }
    hr { border: none; border-top: 1px solid var(--border); margin: 2em 0; }
    /* Tables size to their content (max-content) but the scroll box is capped
       to the container (max-width:100%). Narrow tables therefore look natural,
       while wide tables overflow horizontally and scroll instead of crushing
       their columns into unreadable slivers. (Pinning width:100% defeats the
       overflow and is the classic responsive-table trap.) */
    table {
        display: block; width: max-content; max-width: 100%;
        border-collapse: collapse; margin: 1.2em 0; font-size: 0.9rem;
        overflow-x: auto; -webkit-overflow-scrolling: touch;
    }
    th, td {
        padding: 8px 14px; border: 1px solid var(--border);
        text-align: left; vertical-align: top;
    }
    th { background: var(--code-bg); color: var(--heading); font-weight: 600; }
    /* Subtle zebra striping keeps dense, multi-row tables readable. */
    tbody tr:nth-child(even) td { background: rgba(255,255,255,0.03); }
    caption {
        caption-side: bottom; font-size: 0.78rem; color: var(--dim);
        font-style: italic; padding-top: 6px; text-align: left;
    }
    /* Images are hidden by default; JS removes this class when the user toggles them on */
    .no-images img,
    .no-images video,
    .no-images figure { display: none !important; }
    """
}
