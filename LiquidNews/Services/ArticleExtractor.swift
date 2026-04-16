// ArticleExtractor.swift
// Drives a hidden WKWebView to load a URL, then runs Mozilla's Readability.js
// to extract the article content — the same engine Firefox Reader View uses.
//
// Setup required:
//   Download Readability.js from https://github.com/mozilla/readability
//   and add it to the Xcode target (drag into project, tick "Add to target").
//   The extractor will log a clear error and fall back to WebReaderView if the
//   file is missing from the bundle.
//
// Threading model:
//   @MainActor-isolated. WKNavigationDelegate methods are nonisolated (WebKit
//   calls them on the main thread but Swift strict concurrency requires the
//   explicit annotation). Each hops back via Task { @MainActor in }.

import WebKit
import SwiftUI

@Observable
@MainActor
final class ArticleExtractor: NSObject {

    // MARK: - State

    enum State {
        case loading
        case success(ReadabilityArticle)
        case failed
    }

    private(set) var state: State = .loading
    /// Human-readable phase shown in the loading UI.
    private(set) var phase: String = "Initializing…"
    /// Timestamped log shown in the debug panel while loading.
    private(set) var log: [String] = []

    // MARK: - Private

    private var webView: WKWebView?
    private var targetURL: URL?
    /// Guards against multiple didFinish callbacks (redirects, iframes, etc.).
    private var hasExtracted = false
    private var timeoutTask: Task<Void, Never>?
    /// A 1×1 off-screen UIWindow that owns the WKWebView.
    /// A headless WKWebView (not in any window) causes the Web Content process
    /// to fail its sandbox bootstrapping, preventing page loads entirely.
    /// Attaching to a real UIWindow fixes this.
    private var extractionWindow: UIWindow?

    // MARK: - Public API

    func extract(from url: URL) {
        targetURL = url
        hasExtracted = false
        log = []
        phase = "Loading page…"
        state = .loading

        addLog("→ \(url.host ?? url.absoluteString)")

        // Verify Readability.js is bundled before even loading the page
        guard Bundle.main.url(forResource: "Readability", withExtension: "js") != nil else {
            addLog("❌ Readability.js not found in app bundle.")
            addLog("   Download from github.com/mozilla/readability")
            addLog("   and add it to the Xcode target.")
            state = .failed
            return
        }

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all

        let wv = makeWebView(config: config)
        wv.navigationDelegate = self
        webView = wv
        wv.load(URLRequest(url: url))

        // Give up after 20 s — some pages hang forever on didFinish.
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            await MainActor.run { [weak self] in
                guard let self, case .loading = self.state else { return }
                self.addLog("⏱ Timed out — falling back to browser")
                self.cleanup()
                self.state = .failed
            }
        }
    }

    // MARK: - Window management

    /// Creates a WKWebView and attaches it to a tiny off-screen UIWindow so the
    /// Web Content process can establish its sandbox correctly.
    private func makeWebView(config: WKWebViewConfiguration) -> WKWebView {
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            let window = UIWindow(windowScene: scene)
            // Place it off-screen so it's never visible
            window.frame = CGRect(x: -2, y: -2, width: 1, height: 1)
            window.isHidden = false
            window.addSubview(wv)
            extractionWindow = window
        } else {
            addLog("⚠️ No active scene — extraction may fail")
        }

        return wv
    }

    /// Tears down the extraction window and web view after use.
    private func cleanup() {
        webView?.navigationDelegate = nil
        webView = nil
        extractionWindow?.isHidden = true
        extractionWindow = nil
    }

    // MARK: - Extraction (called on @MainActor after didFinish)

    private func runExtraction(webView: WKWebView) async {
        guard !hasExtracted else { return }
        hasExtracted = true
        timeoutTask?.cancel()

        phase = "Extracting with Readability…"
        addLog("Page loaded — running Readability.js")

        // Load Readability.js source from bundle
        guard
            let readabilityURL = Bundle.main.url(forResource: "Readability", withExtension: "js"),
            let readabilitySource = try? String(contentsOf: readabilityURL, encoding: .utf8)
        else {
            addLog("❌ Could not read Readability.js from bundle")
            cleanup()
            state = .failed
            return
        }

        // Concatenate Readability library + our extraction call into one script.
        // Readability requires a cloned document — we must not mutate the live DOM
        // or the parse() call will be affected by the clone it makes internally.
        let fullScript = readabilitySource + "\n" + Self.extractionScript

        let jsResult: Any?
        do {
            jsResult = try await withCheckedThrowingContinuation { continuation in
                webView.evaluateJavaScript(fullScript) { value, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: value as Any)
                    }
                }
            }
        } catch {
            addLog("❌ JS error: \(error.localizedDescription)")
            cleanup()
            state = .failed
            return
        }

        guard
            let jsonString = jsResult as? String,
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            addLog("❌ Could not parse output (got \(type(of: jsResult)))")
            cleanup()
            state = .failed
            return
        }

        // Readability signals failure by returning null — we get an empty dict
        if let error = json["error"] as? String {
            addLog("❌ Readability: \(error)")
            cleanup()
            state = .failed
            return
        }

        let content = json["content"] as? String ?? ""
        let length  = json["length"]  as? Int    ?? 0

        addLog("✓ Extracted \(length) chars")

        // Bail if Readability couldn't find meaningful content
        if length < 200 {
            addLog("⚠️ Content too short (\(length) chars) — falling back")
            cleanup()
            state = .failed
            return
        }

        let article = ReadabilityArticle(
            title:    json["title"]    as? String ?? webView.title ?? "",
            byline:   json["byline"]   as? String,
            content:  content,
            excerpt:  json["excerpt"]  as? String,
            siteName: json["siteName"] as? String,
            url:      targetURL        ?? webView.url ?? URL(string: "about:blank")!
        )

        phase = "Done"
        addLog("✓ Ready — \"\(article.title.prefix(50))\"")
        cleanup()
        state = .success(article)
    }

    private func handleNavigationFailure(error: Error) {
        guard !hasExtracted else { return }
        hasExtracted = true
        timeoutTask?.cancel()
        addLog("❌ Navigation failed: \(error.localizedDescription)")
        cleanup()
        state = .failed
    }

    // MARK: - Extraction script

    // Calls the Readability API (defined by the bundled Readability.js above it).
    // Returns a JSON string on success, or a JSON object with an "error" key.
    private static let extractionScript = """
    (function () {
        try {
            if (typeof Readability === 'undefined') {
                return JSON.stringify({ error: 'Readability class not defined' });
            }

            var documentClone = document.cloneNode(true);
            var reader = new Readability(documentClone, {
                // Keep these classes so our CSS can style them properly
                classesToPreserve: ['caption', 'code', 'pre', 'highlight'],
                // Don't strip unlikely candidates too aggressively
                disableJSONLD: false,
            });

            var article = reader.parse();

            if (!article) {
                return JSON.stringify({ error: 'Readability returned null' });
            }

            // Supplement with OG metadata where Readability left fields empty
            function meta(name) {
                var el = document.querySelector(
                    'meta[property="' + name + '"], meta[name="' + name + '"]'
                );
                return el ? el.getAttribute('content') : null;
            }

            var siteName = article.siteName
                || meta('og:site_name')
                || location.hostname.replace(/^www\\./, '');

            var excerpt = article.excerpt
                || meta('og:description')
                || meta('description')
                || null;
            if (excerpt) excerpt = excerpt.slice(0, 280);

            return JSON.stringify({
                title:    article.title    || document.title,
                byline:   article.byline   || null,
                content:  article.content  || '',
                excerpt:  excerpt,
                siteName: siteName,
                lang:     article.lang     || null,
                length:   article.length   || 0,
            });
        } catch (e) {
            return JSON.stringify({ error: e.message });
        }
    })();
    """

    // MARK: - Logging

    private func addLog(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.append("[\(ts)] \(message)")
        print("[ArticleExtractor] \(message)")
    }
}

// MARK: - WKNavigationDelegate

extension ArticleExtractor: WKNavigationDelegate {

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            await self?.runExtraction(webView: webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor [weak self] in
            self?.handleNavigationFailure(error: error)
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor [weak self] in
            self?.handleNavigationFailure(error: error)
        }
    }
}
