// ImgurResolver.swift
// Turns an Imgur URL into an ImgurContent (title + ordered, validated image URLs)
// without an Imgur API key. Direct images resolve with no network; post/album/gallery
// pages are re-fetched with a crawler user-agent to obtain og: meta tags.

import Foundation

struct ImgurContent: Equatable {
    let title: String?
    let images: [URL]
}

enum ImgurResolver {

    /// True when the URL's host is exactly `imgur.com` or a subdomain of it
    /// (www, i, m, …). Matches on a dot boundary so `notimgur.com` is rejected.
    static func handles(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "imgur.com" || host.hasSuffix(".imgur.com")
    }

    /// Still-image extensions Imgur serves directly. `.gifv`/`.mp4` are excluded
    /// (video, out of scope for v1).
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp"]

    /// Returns the URL unchanged when it is a direct still-image URL
    /// (`i.imgur.com/{id}.{ext}`), otherwise nil.
    static func directImage(for url: URL) -> URL? {
        guard url.host?.lowercased() == "i.imgur.com" else { return nil }
        guard imageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }

    /// True when `url` is safe to place into an `<img src>`: http(s) and a host
    /// suffixed to `imgur.com`. Blocks crafted `og:image` values (javascript:, data:,
    /// foreign hosts) from injecting markup.
    static func isValidImageURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return false }
        guard let host = url.host?.lowercased(),
              host == "imgur.com" || host.hasSuffix(".imgur.com")
        else { return false }
        return true
    }

    typealias Fetch = (URLRequest) async -> (Data, URLResponse)?

    private static let crawlerUserAgent =
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"

    /// Resolves an Imgur URL into title + validated image URLs, or nil on a miss.
    /// - Direct images return immediately with no network.
    /// - Post/album/gallery pages are fetched with a crawler UA and parsed for og: tags.
    static func resolve(_ url: URL, fetch: Fetch = ImgurResolver.defaultFetch) async -> ImgurContent? {
        if let direct = directImage(for: url) {
            return ImgurContent(title: nil, images: [direct])
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(crawlerUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")

        guard
            let (data, response) = await fetch(request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
        else { return nil }

        if let content = parseOpenGraph(html) { return content }

        // og miss: try constructing a direct image URL from a classic post id.
        if let id = classicPostID(from: url),
           let constructed = URL(string: "https://i.imgur.com/\(id).jpg"),
           await imageExists(constructed, fetch: fetch) {
            return ImgurContent(title: nil, images: [constructed])
        }
        return nil
    }

    /// Extracts `og:title` and all `og:image` tags (deduped, document order). Only
    /// images that pass `isValidImageURL` are kept. Returns nil when no valid image.
    static func parseOpenGraph(_ html: String) -> ImgurContent? {
        let title = ogContent(property: "og:title", in: html)

        var images: [URL] = []
        var seen = Set<String>()
        for value in ogContents(property: "og:image", in: html) {
            guard let url = URL(string: value), isValidImageURL(url) else { continue }
            let key = url.absoluteString
            if seen.insert(key).inserted { images.append(url) }
        }

        guard !images.isEmpty else { return nil }
        return ImgurContent(title: title, images: images)
    }

    /// All `content` values for `<meta property="...">` tags, in document order.
    private static func ogContents(property: String, in html: String) -> [String] {
        // Matches: <meta property="og:image" content="VALUE"> with either attribute
        // order and single or double quotes.
        let patterns = [
            "<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(property)[\"']",
        ]
        var results: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            else { continue }
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, let r = Range(match.range(at: 1), in: html) else { return }
                results.append(htmlDecode(String(html[r])))
            }
        }
        return results
    }

    private static func ogContent(property: String, in html: String) -> String? {
        ogContents(property: property, in: html).first
    }

    /// Minimal HTML-entity decode for attribute values (Imgur escapes & in URLs/titles).
    private static func htmlDecode(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// The post id from a classic `imgur.com/{id}` URL where the id IS the image
    /// hash (5–7 alphanumerics). Returns nil for `/a/`, `/gallery/`, `/t/`, `/user/`
    /// and for the `i.imgur.com` direct-image host.
    static func classicPostID(from url: URL) -> String? {
        guard let host = url.host?.lowercased(),
              host == "imgur.com" || (host.hasSuffix(".imgur.com") && host != "i.imgur.com")
        else { return nil }
        let id = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard id.range(of: "^[A-Za-z0-9]{5,7}$", options: .regularExpression) != nil
        else { return nil }
        return id
    }

    /// HEAD/GET-validates a constructed direct-image URL through the fetch seam:
    /// true only when the response is a 2xx with an `image/*` content type.
    private static func imageExists(_ url: URL, fetch: Fetch) async -> Bool {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(crawlerUserAgent, forHTTPHeaderField: "User-Agent")
        guard
            let (_, response) = await fetch(request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            (http.mimeType ?? "").hasPrefix("image/")
        else { return false }
        return true
    }

    /// Default production fetch: executes the request on the shared URLSession.
    static func defaultFetch(_ request: URLRequest) async -> (Data, URLResponse)? {
        try? await URLSession.shared.data(for: request)
    }
}
