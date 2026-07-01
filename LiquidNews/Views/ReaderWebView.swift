// ReaderWebView.swift
// The WKWebView bridge: the UIViewRepresentable, its Coordinator, and the
// two-phase Readability.js navigation delegate, plus the bundled Readability.js
// source cache. Extracted from ArticleReaderView (DESLOPPIFY M4) with no
// behaviour change.

import SwiftUI
import UIKit
import WebKit
import os

// MARK: - Readability.js cache
// Loaded once from the bundle on first use; synchronous file I/O at startup is
// negligible for a bundled resource but doing it once avoids re-reading the disk
// on every article open.
private enum ReadabilitySource {
    static let js: String? = {
        guard let url = Bundle.main.url(forResource: "Readability", withExtension: "js") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }()
}

// MARK: - WKWebView bridge

struct ReaderWebView: UIViewRepresentable {
    let url: URL
    let state: ReaderState

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all

        // Disable page scripts. WKWebView will stop waiting for external <script src>
        // downloads and inline script execution before firing didFinish — which is the
        // main source of the ~60s delay. evaluateJavaScript (our Readability injection)
        // is not affected by this flag; it bypasses the page content script policy.
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1)

        wv.addObserver(context.coordinator, forKeyPath: "estimatedProgress",
                       options: .new, context: nil)
        wv.addObserver(context.coordinator, forKeyPath: "canGoBack",
                       options: .new, context: nil)

        // Wire up reload so the toolbar can restart extraction from scratch.
        // Capture wv.url at call time (not setup time) so reloading after
        // navigating to a linked page re-extracts that page, not the original URL.
        let coord = context.coordinator
        state.reloadAction = { [weak coord, weak wv] in
            guard let coord, let wv else { return }
            let currentURL = wv.url          // nil if loadHTMLString baseURL was nil
            coord.reset()
            coord.loadBlocking(wv, targetURL: currentURL)
        }

        // Apply resource-blocking rules before loading so images/fonts/media
        // are never fetched — not just hidden. Then kick off the page load.
        context.coordinator.loadBlocking(wv)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}

    static func dismantleUIView(_ wv: WKWebView, coordinator: Coordinator) {
        wv.removeObserver(coordinator, forKeyPath: "estimatedProgress")
        wv.removeObserver(coordinator, forKeyPath: "canGoBack")
        wv.navigationDelegate = nil
        wv.uiDelegate = nil
    }
}

// MARK: - Coordinator

extension ReaderWebView {
    final class Coordinator: NSObject, WKUIDelegate {
        let url: URL
        let state: ReaderState
        /// Incremented on every reset so in-flight Tasks can detect they are stale.
        private var loadGeneration = 0
        /// True after the first page load finishes and extraction begins.
        private(set) var hasExtracted = false
        /// True after the reader HTML has been loaded (second navigation).
        private(set) var readerHTMLLoaded = false
        /// True while the reader is showing an Imgur gallery (set in loadImgur, cleared
        /// in reset). Gates image tap/long-press routing so normal articles are never hijacked.
        private var isImgurGallery = false
        /// The gallery's ordered image URLs — the membership gate for tap/menu routing.
        private var galleryImages: [URL] = []
        /// The original Imgur post URL, for the "Open on Imgur" action.
        private var galleryPageURL: URL?

        init(url: URL, state: ReaderState) {
            self.url = url
            self.state = state
        }

        /// Resets extraction flags so the full two-phase flow can run again.
        /// Incrementing `loadGeneration` invalidates any in-flight async Tasks
        /// that belong to the previous load — they check this value before
        /// touching the WKWebView or updating state.
        func reset() {
            loadGeneration += 1
            hasExtracted = false
            readerHTMLLoaded = false
            isImgurGallery = false
            galleryImages = []
            galleryPageURL = nil
            Task { @MainActor [weak self] in
                self?.state.userHasNavigatedInline = false
                self?.state.pendingImagePreview = nil
                self?.state.isPreparingImagePreview = false
            }
        }

        /// Entry point for loading.
        ///
        /// Fast path — URLSession:
        ///   Fetches the raw HTML bytes directly (no JavaScript execution, no sub-resource
        ///   loading). The HTML is handed to WKWebView via loadHTMLString so didFinish fires
        ///   almost immediately. Works for server-rendered articles (the vast majority of
        ///   HN links).
        ///
        /// Slow path — WKWebView:
        ///   Used when the URLSession fetch fails or the server responds with non-HTML
        ///   (e.g. a redirect to a login page). Resource blocking rules are applied so
        ///   images/fonts/media are dropped at the network layer.
        /// - Parameter targetURL: The URL to load. Defaults to the original article URL.
        ///   Pass `wv.url` on reload so that navigating to a linked page and reloading
        ///   re-extracts that page rather than reverting to the original article.
        func loadBlocking(_ wv: WKWebView, targetURL: URL? = nil) {
            let loadURL  = targetURL ?? url
            let gen      = loadGeneration          // capture before going async

            // Imgur image pages resolve to a gallery directly — before the extraction
            // content-rule-lists are added below, so the gallery's <img> tags are
            // never blocked. A resolver miss falls through to the normal flow.
            if ImgurResolver.handles(loadURL) {
                Task { [weak self] in
                    guard let content = await ImgurResolver.resolve(loadURL) else {
                        await MainActor.run { [weak self] in
                            guard let self, self.loadGeneration == gen else { return }
                            self.loadStandard(wv, loadURL: loadURL, gen: gen)
                        }
                        return
                    }
                    await MainActor.run { [weak self] in
                        guard let self, self.loadGeneration == gen else { return }
                        self.loadImgur(wv, url: loadURL, content: content)
                    }
                }
                return
            }
            loadStandard(wv, loadURL: loadURL, gen: gen)
        }

        private func loadStandard(_ wv: WKWebView, loadURL: URL, gen: Int) {
            Task {
                async let rulesTask = ExtractionRuleCache.shared.get()
                async let htmlTask  = fetchHTML(from: loadURL)

                let (rules, result) = await (rulesTask, htmlTask)

                await MainActor.run { [weak self] in
                    guard let self, self.loadGeneration == gen else { return }   // stale load

                    // Always clear first so a rapid reload never double-adds rules.
                    wv.configuration.userContentController.removeAllContentRuleLists()
                    if let rules {
                        wv.configuration.userContentController.add(rules)
                    }

                    if let (html, finalURL) = result {
                        state.addLog("⚡ Fast path — loading HTML directly")
                        wv.loadHTMLString(html, baseURL: finalURL)
                    } else {
                        state.addLog("🌐 Slow path — loading via WebKit")
                        wv.load(URLRequest(url: loadURL))
                    }
                }
            }
        }

        /// Fetches the page's raw HTML via URLSession with a mobile Safari user-agent.
        /// Returns `(html, finalURL)` on success, `nil` if the request fails or the
        /// response is not HTML (e.g. JSON API, login redirect).
        private func fetchHTML(from fetchURL: URL) async -> (String, URL)? {
            var request = URLRequest(url: fetchURL, timeoutInterval: 10)
            // Realistic mobile Safari UA so sites serve their standard HTML
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
                "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
                "Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue(
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                forHTTPHeaderField: "Accept"
            )
            request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")

            guard
                let (data, response) = try? await URLSession.shared.data(for: request),
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode),
                let mime = http.mimeType, mime.contains("html"),
                let html = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .isoLatin1)
            else { return nil }

            // Use the final URL after any redirects as the base for relative links
            let finalURL = response.url ?? fetchURL
            return (html, finalURL)
        }

        override func observeValue(forKeyPath keyPath: String?,
                                   of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?,
                                   context: UnsafeMutableRawPointer?) {
            guard let wv = object as? WKWebView else { return }
            switch keyPath {
            case "estimatedProgress":
                let p = wv.estimatedProgress
                Task { @MainActor [weak self] in
                    guard let self, case .loading = self.state.phase else { return }
                    self.state.phase = .loading(progress: p)
                }
            case "canGoBack":
                let back = wv.canGoBack
                Task { @MainActor [weak self] in
                    self?.state.canGoBack = back
                }
            default:
                break
            }
        }
    }
}

extension ReaderWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !hasExtracted {
            // Phase 1 complete — run Readability
            hasExtracted = true
            Task { @MainActor [weak self] in
                await self?.runExtraction(on: webView)
            }
        } else if !readerHTMLLoaded {
            // Phase 2 complete — reader HTML is rendered, lift the overlay
            readerHTMLLoaded = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Brief settle so the reader HTML finishes painting before reveal
                try? await Task.sleep(for: .milliseconds(150))
                // Store the WKWebView reference so preferences can be applied live
                self.state.webView = webView
                self.state.phase = .success
            }
        } else {
            // A back/forward navigation completed while the reader is fully loaded.
            // backList.count == 1 means only the phase-1 raw page is behind the
            // reader HTML — the user has navigated back to the reader root.
            // backList.count > 1 means there are still inline pages behind the
            // current page. Mirror that state into userHasNavigatedInline so the
            // back button hides at the reader root and shows while browsing inline.
            let hasInlineHistory = webView.backForwardList.backList.count > 1
            Task { @MainActor [weak self] in
                self?.state.userHasNavigatedInline = hasInlineHistory
            }
        }
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        Task { @MainActor [weak self] in
            self?.state.addLog("❌ \(error.localizedDescription)")
            self?.state.phase = .failed
        }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        Task { @MainActor [weak self] in
            self?.state.addLog("❌ \(error.localizedDescription)")
            self?.state.phase = .failed
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Imgur gallery image tap → full-screen Quick Look. Gate on membership in the
        // gallery's own images so normal articles with an imgur link are never hijacked.
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           isImgurGallery,
           galleryImages.contains(url) {
            decisionHandler(.cancel)
            presentImagePreview(tapped: url)   // nonisolated; kicks its own @MainActor Task
            return
        }

        // HN thread links are always intercepted regardless of the interceptLinks setting
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           HNURLRouter.isHNItemURL(url) {
            decisionHandler(.cancel)
            Task { @MainActor [weak self] in
                self?.state.pendingHNLinkURL = url
            }
            return
        }

        guard
            navigationAction.navigationType == .linkActivated,
            let url = navigationAction.request.url,
            state.interceptLinks
        else {
            if navigationAction.navigationType == .linkActivated {
                Task { @MainActor [weak self] in
                    self?.state.userHasNavigatedInline = true
                }
            }
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        Task { @MainActor [weak self] in
            self?.state.pendingLinkURL = url
        }
    }

    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let url = elementInfo.linkURL else {
            completionHandler(nil)
            return
        }

        // Imgur gallery image → per-image action menu (membership-gated).
        if isImgurGallery, galleryImages.contains(url) {
            let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }

                let save = UIAction(title: "Save to Photos",
                                    image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
                    self?.saveImageToPhotos(url)
                }
                let share = UIAction(title: "Share…",
                                     image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    self?.shareImage(url)
                }
                let copy = UIAction(title: "Copy Image",
                                    image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                    self?.copyImage(url)
                }
                let openImgur = UIAction(title: "Open on Imgur",
                                         image: UIImage(systemName: "safari")) { [weak self] _ in
                    guard let self, let page = self.galleryPageURL else { return }
                    DispatchQueue.main.async { self.state.pendingDirectLink = .inAppSafari(page) }
                }

                return UIMenu(title: "", children: [save, share, copy, openImgur])
            }
            completionHandler(config)
            return
        }

        if HNURLRouter.isHNItemURL(url) {
            let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                guard let self else { return nil }

                let inApp = UIAction(
                    title: "Open in LiquidNews",
                    image: UIImage(systemName: "apps.iphone")
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.state.pendingHNAction = .open(url, .inApp)
                    }
                }

                let safari = UIAction(
                    title: "Open in Safari",
                    image: UIImage(systemName: "arrow.up.right.square")
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.state.pendingHNAction = .open(url, .safari)
                    }
                }

                let share = UIAction(
                    title: "Share…",
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.state.pendingHNAction = .open(url, .ask)
                    }
                }

                return UIMenu(title: "HN Thread", children: [inApp, safari, share])
            }
            completionHandler(config)
            return
        }

        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let inline = UIAction(
                title: "Open Inline",
                image: UIImage(systemName: "arrow.turn.down.right")
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.state.pendingDirectLink = .inline(url) }
            }

            let inAppSafari = UIAction(
                title: "Open in In-App Safari",
                image: UIImage(systemName: "safari")
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.state.pendingDirectLink = .inAppSafari(url) }
            }

            let safari = UIAction(
                title: "Open in Safari",
                image: UIImage(systemName: "arrow.up.right.square")
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.state.pendingDirectLink = .safari(url) }
            }

            return UIMenu(title: url.host ?? "", children: [inline, inAppSafari, safari])
        }

        completionHandler(config)
    }

    // MARK: - Imgur gallery

    /// Loads an Imgur gallery directly, bypassing Readability and the length gate.
    /// Clears content-rule-lists so the <img> tags are not blocked, marks extraction
    /// done, then loadHTMLString with baseURL = the Imgur page URL so reloadAction's
    /// wv.url capture matches the normal path. The existing phase-2 didFinish lifts
    /// the overlay and sets .success.
    @MainActor
    private func loadImgur(_ wv: WKWebView, url pageURL: URL, content: ImgurContent) {
        state.addLog("🖼️ Imgur — \(content.images.count) image(s)")
        isImgurGallery = true
        galleryImages = content.images
        galleryPageURL = pageURL
        wv.configuration.userContentController.removeAllContentRuleLists()
        hasExtracted = true   // skip phase-1 Readability; next didFinish is phase 2
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: pageURL)
        wv.loadHTMLString(html, baseURL: pageURL)
    }

    /// Downloads the gallery to temp files, then presents Quick Look opened on the
    /// tapped image. Generation-guarded so a download finishing after navigation away
    /// cannot present over the wrong page.
    private func presentImagePreview(tapped url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let gen = self.loadGeneration
            let images = self.galleryImages
            self.state.isPreparingImagePreview = true
            let files = await ImgurImageActions.localFiles(for: images)
            guard self.loadGeneration == gen else { return }
            self.state.isPreparingImagePreview = false
            // Locate the tapped image's downloaded file to compute the start index,
            // adjusted for any dropped failures. If the tapped image failed, don't present.
            guard
                let tappedFile = await ImgurImageActions.localFile(for: url),
                let startIndex = files.firstIndex(of: tappedFile)
            else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return
            }
            guard self.loadGeneration == gen, !files.isEmpty else { return }
            self.state.pendingImagePreview = ReaderState.ImagePreviewRequest(
                fileURLs: files, startIndex: startIndex)
        }
    }

    private func saveImageToPhotos(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let gen = self.loadGeneration
            guard let image = await ImgurImageActions.image(for: url) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            guard self.loadGeneration == gen else { return }
            let ok = await ImgurImageActions.saveToPhotos(image)
            if ok {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func copyImage(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let gen = self.loadGeneration
            guard let image = await ImgurImageActions.image(for: url) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            guard self.loadGeneration == gen else { return }
            UIPasteboard.general.image = image
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func shareImage(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let gen = self.loadGeneration
            guard let file = await ImgurImageActions.localFile(for: url) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            guard self.loadGeneration == gen else { return }
            HNURLRouter.presentShareSheet(activityItems: [file])
        }
    }

    // MARK: - Extraction

    @MainActor
    private func runExtraction(on webView: WKWebView) async {
        state.addLog("Page loaded — injecting Readability")
        state.phase = .extracting

        guard let readabilitySource = ReadabilitySource.js else {
            state.addLog("❌ Readability.js not found in bundle")
            state.phase = .failed
            return
        }

        // Apply any domain-specific preprocessing (strip selectors, content focus, etc.)
        let currentURL = webView.url ?? url
        let siteRule   = SiteRules.match(url: currentURL)
        if siteRule != nil {
            state.addLog("📐 Applying site rule for \(currentURL.host ?? "?")")
        }

        let fullScript = readabilitySource + "\n" + Self.extractionScript(preprocessing: siteRule?.preprocessingJS ?? "")

        let raw: Any?
        do {
            raw = try await withCheckedThrowingContinuation { continuation in
                webView.evaluateJavaScript(fullScript) { value, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: value as Any) }
                }
            }
        } catch {
            state.addLog("❌ JS error: \(error.localizedDescription)")
            state.phase = .failed
            return
        }

        guard
            let jsonString = raw as? String,
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            state.addLog("❌ Could not parse output (got \(type(of: raw)))")
            state.phase = .failed
            return
        }

        if let error = json["error"] as? String {
            state.addLog("❌ Readability: \(error)")
            state.phase = .failed
            return
        }

        let content  = json["content"]  as? String ?? ""
        let length   = json["length"]   as? Int    ?? 0
        let title    = json["title"]    as? String ?? webView.title ?? ""
        let byline   = json["byline"]   as? String
        let siteName = json["siteName"] as? String

        guard length >= 200 else {
            state.addLog("⚠️ Content too short (\(length) chars) — falling back")
            state.phase = .failed
            return
        }

        state.addLog("✓ \(length) chars — rendering reader")

        // Use the WKWebView's actual URL (which follows redirects) as baseURL so
        // relative image/link hrefs in the extracted content resolve correctly.
        // Falls back to the coordinator's stored URL if webView.url is nil.
        let resolvedBase = webView.url ?? url
        let html = ReaderHTMLBuilder.article(title: title, byline: byline,
                                            siteName: siteName, content: content,
                                            baseURL: resolvedBase)
        // Remove extraction-phase blocking rules before loading the reader HTML.
        // The rules were applied only to speed up the initial fetch — keeping them
        // active in Phase 2 would prevent images from ever loading, even when the
        // user enables them. CSS (.no-images) controls visibility from here on.
        webView.configuration.userContentController.removeAllContentRuleLists()
        // Load the reader HTML into the same WKWebView — triggers second didFinish
        webView.loadHTMLString(html, baseURL: resolvedBase)
    }

    // MARK: - JavaScript

    /// Builds the extraction script, optionally inserting site-specific preprocessing
    /// before Readability runs.  If `preprocessing` returns early via a `return` statement
    /// (useDirectContent rules), Readability is bypassed entirely.
    private static func extractionScript(preprocessing: String = "") -> String {
        """
        (function () {
            try {
                if (typeof Readability === 'undefined') {
                    return JSON.stringify({ error: 'Readability class not defined' });
                }

                // Site-specific DOM preprocessing (injected by SiteRules)
                \(preprocessing)

                var clone = document.cloneNode(true);
                var article = new Readability(clone, {
                    classesToPreserve: ['caption', 'code', 'pre', 'highlight'],
                }).parse();

                if (!article) {
                    return JSON.stringify({ error: 'Readability returned null' });
                }

                function meta(name) {
                    var el = document.querySelector(
                        'meta[property="' + name + '"], meta[name="' + name + '"]'
                    );
                    return el ? el.getAttribute('content') : null;
                }

                var siteName = article.siteName
                    || meta('og:site_name')
                    || location.hostname.replace(/^www\\./, '');

                var excerpt = article.excerpt || meta('og:description') || meta('description') || null;
                if (excerpt) excerpt = excerpt.slice(0, 280);

                return JSON.stringify({
                    title:    article.title    || document.title,
                    byline:   article.byline   || null,
                    content:  article.content  || '',
                    excerpt:  excerpt,
                    siteName: siteName,
                    length:   article.length   || 0,
                });
            } catch (e) {
                return JSON.stringify({ error: e.message });
            }
        })();
        """
    }

}


// MARK: - Resource blocker
// Compiled once and reused for every extraction — blocks images, media, and fonts
// at the network level so the WKWebView only fetches HTML, scripts, and stylesheets.
// This is the main lever for reducing extraction time on image-heavy pages.
private actor ExtractionRuleCache {
    static let shared = ExtractionRuleCache()

    private var cached: WKContentRuleList?

    func get() async -> WKContentRuleList? {
        if let cached { return cached }
        let json = """
        [{
            "trigger": {
                "url-filter": ".*",
                "resource-type": ["image", "media", "font", "raw", "svg-document", "script"]
            },
            "action": { "type": "block" }
        }]
        """
        cached = try? await WKContentRuleListStore.default()
            .compileContentRuleList(forIdentifier: "LNExtraction", encodedContentRuleList: json)
        return cached
    }
}
