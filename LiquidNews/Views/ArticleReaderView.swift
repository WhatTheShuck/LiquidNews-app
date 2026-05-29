// ArticleReaderView.swift
// Native reader mode using Mozilla's Readability.js.
//
// Architecture — why WKWebView is in the view hierarchy, not hidden:
//   A WKWebView created off-screen (not attached to a live UIWindowScene) causes
//   the Web Content process to fail its sandbox extension bootstrap on device,
//   preventing page loads entirely. Keeping the WKWebView as a real view (covered
//   by a loading overlay) avoids this completely — the scene connection is
//   established automatically by SwiftUI's hosting infrastructure.
//
// Two-phase navigation:
//   Phase 1 — WKWebView loads the URL normally. A loading overlay hides the
//              raw page. On didFinish, Readability.js is injected and run.
//   Phase 2 — Extracted HTML is loaded back into the same WKWebView via
//              loadHTMLString. On the second didFinish the overlay lifts,
//              revealing the clean reader view.
//
//   If anything fails, a SafariView sheet is presented as a fallback.

import SwiftUI
import UIKit
import WebKit

// MARK: - Reader preferences

enum ReaderTheme: String, CaseIterable, Equatable {
    case dark, light, sepia, warm
    // Premium cases
    case oled
    case terminal
    case solarized
    case paper

    var label: String {
        switch self {
        case .dark:      return "Dark"
        case .light:     return "Light"
        case .sepia:     return "Sepia"
        case .warm:      return "Warm"
        case .oled:      return "OLED"
        case .terminal:  return "Terminal"
        case .solarized: return "Solarized"
        case .paper:     return "Paper"
        }
    }

    /// CSS hex value for the page background
    var background: String {
        switch self {
        case .dark:      return "#0f0f1a"
        case .light:     return "#ffffff"
        case .sepia:     return "#f5f1e8"
        case .warm:      return "#1a1815"
        case .oled:      return "#000000"
        case .terminal:  return "#0d1a0d"
        case .solarized: return "#002b36"
        case .paper:     return "#f8f4e8"
        }
    }

    /// CSS hex value for body text
    var text: String {
        switch self {
        case .dark:      return "#e8e8ee"
        case .light:     return "#1a1a1a"
        case .sepia:     return "#3a3019"
        case .warm:      return "#ddd8cc"
        case .oled:      return "#e8e8ee"
        case .terminal:  return "#33ff66"
        case .solarized: return "#839496"
        case .paper:     return "#3a3019"
        }
    }

    /// CSS hex value for dimmed / secondary text
    var dim: String {
        switch self {
        case .dark:      return "#8888aa"
        case .light:     return "#6b6b7a"
        case .sepia:     return "#7a7060"
        case .warm:      return "#9a9080"
        case .oled:      return "#6666aa"
        case .terminal:  return "#1a8832"
        case .solarized: return "#586e75"
        case .paper:     return "#7a7060"
        }
    }

    /// CSS hex value for headings (needs separate control on light backgrounds)
    var heading: String {
        switch self {
        case .dark:      return "#ffffff"
        case .light:     return "#111111"
        case .sepia:     return "#2a2012"
        case .warm:      return "#ece7dc"
        case .oled:      return "#ffffff"
        case .terminal:  return "#66ff88"
        case .solarized: return "#93a1a1"
        case .paper:     return "#2a2012"
        }
    }

    /// CSS rgba for subtle borders
    var border: String {
        isLight ? "rgba(0,0,0,0.12)" : "rgba(255,255,255,0.10)"
    }

    /// CSS rgba for code block backgrounds
    var codeBg: String {
        isLight ? "rgba(0,0,0,0.05)" : "rgba(255,255,255,0.06)"
    }

    /// SwiftUI color for the theme swatch circle
    var swatchColor: Color {
        switch self {
        case .dark:      return Color(red: 0.06, green: 0.06, blue: 0.10)
        case .light:     return Color.white
        case .sepia:     return Color(red: 0.96, green: 0.95, blue: 0.91)
        case .warm:      return Color(red: 0.10, green: 0.10, blue: 0.08)
        case .oled:      return Color.black
        case .terminal:  return Color(red: 0.05, green: 0.10, blue: 0.05)
        case .solarized: return Color(red: 0.00, green: 0.17, blue: 0.21)
        case .paper:     return Color(red: 0.97, green: 0.96, blue: 0.91)
        }
    }

    /// True for light-background themes — used to pick checkmark colour
    var isLight: Bool { self == .light || self == .sepia || self == .paper }

    var isPremium: Bool {
        switch self {
        case .oled, .terminal, .solarized, .paper: return true
        default: return false
        }
    }
}

enum ReaderFont: String, CaseIterable, Equatable {
    case system = "System"
    case serif  = "Serif"
    case mono   = "Mono"

    var cssFamily: String {
        switch self {
        case .system: return "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"
        case .serif:  return "Georgia, 'Times New Roman', serif"
        case .mono:   return "'SF Mono', ui-monospace, Menlo, monospace"
        }
    }

    /// Font used to render the label in its own typeface
    var displayFont: Font {
        switch self {
        case .system: return .system(size: 15)
        case .serif:  return .custom("Georgia", size: 15)
        case .mono:   return .system(size: 14, design: .monospaced)
        }
    }
}

@Observable
final class ReaderPreferences {
    var theme: ReaderTheme  = .dark
    var fontSize: Double    = 18
    var fontFamily: ReaderFont = .system
    var showImages: Bool    = false
    /// Custom text color override. nil = use theme default.
    var textColor: Color?
    /// Custom heading color override. nil = use theme default.
    var headingColor: Color?

    static let minFontSize: Double = 14
    static let maxFontSize: Double = 26

    /// JS injected into the WKWebView to apply all preferences live.
    ///
    /// IMPORTANT: font-family values contain single quotes (e.g. 'Helvetica Neue'),
    /// so the --font property value must use double-quote JS string delimiters.
    /// Using single quotes there causes a syntax error that silently kills the
    /// entire IIFE, preventing all preference changes from taking effect.
    var applyScript: String {
        let showImagesJS = showImages ? "true" : "false"
        return """
        (function () {
            var root = document.documentElement;
            root.style.fontSize = '\(Int(fontSize))px';
            root.style.setProperty('--bg',      '\(theme.background)');
            root.style.setProperty('--text',    '\(textColorCSS)');
            root.style.setProperty('--dim',     '\(theme.dim)');
            root.style.setProperty('--heading', '\(headingColorCSS)');
            root.style.setProperty('--border',  '\(theme.border)');
            root.style.setProperty('--code-bg', '\(theme.codeBg)');
            root.style.setProperty('--font', "\(fontFamily.cssFamily)");
            document.body.style.backgroundColor = '\(theme.background)';
            document.body.className = \(showImagesJS) ? '' : 'no-images';

            if (\(showImagesJS)) {
                // Resolve lazy-loaded images — many sites use data-src / data-lazy-src
                // instead of src, relying on JS scroll handlers to swap them in.
                // Since we disable page JS, we fix these up manually.
                document.querySelectorAll('img').forEach(function (img) {
                    var lazy = img.getAttribute('data-src')
                        || img.getAttribute('data-lazy-src')
                        || img.getAttribute('data-original')
                        || img.getAttribute('data-image');
                    if (lazy) { img.src = lazy; }
                });
            }
        })();
        """
    }

    private var textColorCSS: String {
        if let color = textColor {
            return "#\(color.toHexString())"
        }
        return theme.text
    }

    private var headingColorCSS: String {
        if let color = headingColor {
            return "#\(color.toHexString())"
        }
        return theme.heading
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

// MARK: - Direct link intent

/// User-chosen action from the long-press context menu on a link.
/// Enum with associated values avoids tuple-Equatable limitations with .onChange(of:).
enum PendingDirectLink: Equatable {
    case inline(URL)
    case inAppSafari(URL)
    case safari(URL)
}

/// Action chosen from the HN-link long-press context menu in the reader.
/// Enum with associated values avoids tuple-Equatable limitations with .onChange(of:).
enum PendingHNAction: Equatable {
    case open(URL, HNLinkMode)
}

// MARK: - State

@Observable
@MainActor
final class ReaderState {
    enum Phase {
        case loading(progress: Double)
        case extracting
        case success
        case failed
    }
    var phase: Phase = .loading(progress: 0)
    var log: [String] = []

    /// Set after phase-2 load completes so preferences can be applied live.
    weak var webView: WKWebView?

    /// Called by the toolbar's reload button to restart the full extraction flow.
    var reloadAction: (() -> Void)?

    /// When true, the WKNavigationDelegate intercepts .linkActivated navigations
    /// instead of allowing them inline.
    var interceptLinks: Bool = false

    /// Set by the coordinator when a link is intercepted; cleared by the view
    /// after routing.
    var pendingLinkURL: URL? = nil

    /// Set by the long-press context menu; cleared by ArticleReaderView after routing.
    var pendingDirectLink: PendingDirectLink? = nil

    /// Set by the coordinator when a tapped link is an HN item URL; cleared by ArticleReaderView.
    var pendingHNLinkURL: URL? = nil

    /// Set by the coordinator when the user picks an action from the HN long-press menu; cleared by ArticleReaderView.
    var pendingHNAction: PendingHNAction? = nil

    /// KVO-updated: true when the WKWebView's back/forward list has a prior entry.
    var canGoBack: Bool = false

    /// Set to true the first time the user follows an inline link; reset on article reload.
    var userHasNavigatedInline: Bool = false

    var isSuccess: Bool {
        if case .success = phase { return true }
        return false
    }

    func addLog(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.append("[\(ts)] \(message)")
        print("[ArticleReader] \(message)")
    }

    func applyPreferences(_ prefs: ReaderPreferences) {
        guard let wv = webView, case .success = phase else { return }
        wv.evaluateJavaScript(prefs.applyScript) { _, error in
            if let error { print("[ArticleReader] applyScript error: \(error)") }
        }
    }

    func reloadArticle() {
        phase = .loading(progress: 0)
        webView = nil
        reloadAction?()
    }
}

// MARK: - View

struct ArticleReaderView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var readerState = ReaderState()
    @State private var preferences: ReaderPreferences
    @State private var showReaderOptions = false
    @State private var isPreparingReport = false
    @State private var readerLinkSafariURL: IdentifiableURL?
    @State private var readerLinkReaderURL: IdentifiableURL?
    @State private var fallbackSafariURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @State private var linkedHNStory: HNItem?

    init(url: URL) {
        self.url = url
        let prefs = ReaderPreferences()
        prefs.showImages = UserSettings.shared.readerShowImagesByDefault
        _preferences = State(initialValue: prefs)
    }

    var body: some View {
        readerContent
            .onChange(of: readerState.pendingHNLinkURL) { _, url in
                guard let url else { return }
                readerState.pendingHNLinkURL = nil
                handlePendingHNLinkURL(url)
            }
            .onChange(of: readerState.pendingHNAction) { _, action in
                guard let action else { return }
                readerState.pendingHNAction = nil
                handlePendingHNAction(action)
            }
            .sheet(item: $linkedHNStory) { story in
                NavigationStack { StoryDetailView(story: story) }
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(.glassCornerRadius)
            }
    }

    private var readerContent: some View {
        ZStack {
            // WKWebView is always present and scene-attached
            ReaderWebView(url: url, state: readerState)
                .ignoresSafeArea()

            // Overlay hides the raw page during loading and extraction
            if showOverlay {
                loadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showOverlay)
        .safeAreaInset(edge: .bottom) {
            if readerState.canGoBack && readerState.userHasNavigatedInline {
                HStack {
                    ReaderToolbarButton(icon: "chevron.left", enabled: true) {
                        readerState.webView?.goBack()
                    }
                    .glassEffect(in: Circle())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showReaderOptions = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .disabled(!readerState.isSuccess)

                Menu {
                    Button {
                        preferences.showImages.toggle()
                    } label: {
                        Label(
                            preferences.showImages ? "Hide Images" : "Show Images",
                            systemImage: preferences.showImages ? "photo.fill" : "photo"
                        )
                    }

                    Divider()

                    Button {
                        Task { await reportReaderIssue() }
                    } label: {
                        Label("Report Reader Issue", systemImage: "exclamationmark.bubble")
                    }
                    .disabled(isPreparingReport)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(!readerState.isSuccess)

                Button {
                    readerState.reloadArticle()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!readerState.isSuccess)
            }
        }
        // Re-apply preferences whenever they change or after a reload
        .onChange(of: preferences.theme)      { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: preferences.fontSize)   { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: preferences.fontFamily) { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: preferences.showImages)    { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: preferences.textColor)    { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: preferences.headingColor) { _, _ in readerState.applyPreferences(preferences) }
        .onChange(of: readerState.isSuccess) { _, success in
            if success { readerState.applyPreferences(preferences) }
        }
        .onChange(of: isFailed) { _, failed in
            if failed { fallbackSafariURL = IdentifiableURL(url) }
        }
        .onAppear {
            updateReaderLinkInterception()
        }
        .onChange(of: settings.readerLinkOpen) { _, _ in
            updateReaderLinkInterception()
        }
        .onChange(of: readerState.pendingLinkURL) { _, url in
            guard let url else { return }
            readerState.pendingLinkURL = nil
            switch settings.readerLinkOpen {
            case .inAppSafari:
                readerLinkSafariURL = IdentifiableURL(url)
            case .reader:
                readerLinkReaderURL = IdentifiableURL(url)
            case .safari:
                UIApplication.shared.open(url)
            case .inline:
                break
            }
        }
        .onChange(of: readerState.pendingDirectLink) { _, value in
            guard let intent = value else { return }
            readerState.pendingDirectLink = nil
            switch intent {
            case .inline(let url):
                readerState.webView?.load(URLRequest(url: url))
            case .inAppSafari(let url):
                readerLinkSafariURL = IdentifiableURL(url)
            case .safari(let url):
                UIApplication.shared.open(url)
            }
        }
        .sheet(item: $readerLinkSafariURL) { item in
            SafariView(url: item.url)
        }
        .sheet(item: $readerLinkReaderURL) { item in
            NavigationStack {
                ArticleReaderView(url: item.url)
            }
        }
        .sheet(item: $fallbackSafariURL, onDismiss: { dismiss() }) { item in
            SafariView(url: item.url)
        }
        .sheet(isPresented: $showReaderOptions) {
            ReaderOptionsSheet(preferences: preferences)
                .presentationDetents([.height(StoreService.shared.isThemesUnlocked ? 380 : 300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - Helpers

    private var showOverlay: Bool {
        switch readerState.phase {
        case .loading, .extracting: return true
        case .success, .failed: return false
        }
    }

    private var isFailed: Bool {
        if case .failed = readerState.phase { return true }
        return false
    }

    private func updateReaderLinkInterception() {
        readerState.interceptLinks = (settings.readerLinkOpen != .inline)
    }

    private func handlePendingHNLinkURL(_ url: URL) {
        guard let id = HNURLRouter.itemID(from: url) else { return }
        Task { @MainActor in linkedHNStory = try? await HNAPIService.shared.item(id: id) }
    }

    private func handlePendingHNAction(_ action: PendingHNAction) {
        switch action {
        case .open(let url, let mode):
            switch mode {
            case .inApp:
                guard let id = HNURLRouter.itemID(from: url) else { return }
                Task { @MainActor in linkedHNStory = try? await HNAPIService.shared.item(id: id) }
            case .safari:
                UIApplication.shared.open(url)
            case .ask:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                HNURLRouter.presentShareSheet(for: url)
            }
        }
    }

    // MARK: - Report issue

    private func reportReaderIssue() async {
        isPreparingReport = true
        defer { isPreparingReport = false }

        let hnURL = await fetchHNItemURL(for: url)
        let device = UIDevice.current
        let body = """
        Article URL: \(url.absoluteString)
        HN Item: \(hnURL ?? "Not found")

        Device: \(device.model)
        iOS: \(device.systemVersion)

        --- Describe the issue below ---

        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "issues@what-the-shuck.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Reader Issue"),
            URLQueryItem(name: "body", value: body)
        ]
        guard let mailURL = components.url else { return }
        await UIApplication.shared.open(mailURL)
    }

    private func fetchHNItemURL(for articleURL: URL) async -> String? {
        let query = articleURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let apiURL = URL(string: "https://hn.algolia.com/api/v1/search?query=\(query)&restrictSearchableAttributes=url") else { return nil }
        guard
            let (data, _) = try? await URLSession.shared.data(from: apiURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hits = json["hits"] as? [[String: Any]],
            let first = hits.first,
            let objectID = first["objectID"] as? String
        else { return nil }
        return "https://news.ycombinator.com/item?id=\(objectID)"
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white.opacity(0.5))

                Text(phaseLabel)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                #if DEBUG
                if !readerState.log.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(readerState.log, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(12)
                    }
                    .frame(maxWidth: 340, maxHeight: 180)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }
                #endif
            }
            .padding(24)
        }
    }

    private var phaseLabel: String {
        switch readerState.phase {
        case .loading:    return "Loading page…"
        case .extracting: return "Extracting with Readability…"
        case .success, .failed: return ""
        }
    }
}

// MARK: - WKWebView bridge

private struct ReaderWebView: UIViewRepresentable {
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
            Task { @MainActor [weak self] in
                self?.state.userHasNavigatedInline = false
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
        if let rule = siteRule {
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
        let html = Self.buildHTML(title: title, byline: byline,
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

    // MARK: - HTML template

    private static func buildHTML(title: String, byline: String?,
                                   siteName: String?, content: String,
                                   baseURL: URL) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }

        return """
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

    // MARK: - CSS
    // Colours match AppTheme: accent = rgb(255,107,20), bg = indigo-to-near-black.
    // CSS custom properties (--bg, --text, --dim, --heading, --border, --code-bg, --font)
    // are overridden live via JS when the user changes preferences in the reader toolbar.
    private static let readerCSS = """
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
    table {
        border-collapse: collapse; width: 100%; margin: 1.2em 0;
        font-size: 0.9rem; display: block; overflow-x: auto;
    }
    th, td { padding: 8px 14px; border: 1px solid var(--border); text-align: left; }
    th { background: var(--code-bg); color: var(--heading); font-weight: 600; }
    /* Images are hidden by default; JS removes this class when the user toggles them on */
    .no-images img,
    .no-images video,
    .no-images figure { display: none !important; }
    """
}

// MARK: - Reader options sheet

private struct ReaderOptionsSheet: View {
    @Bindable var preferences: ReaderPreferences
    @State private var store = StoreService.shared
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Text Size ──────────────────────────────────────────────
            optionsSection("Text Size") {
                HStack(spacing: 12) {
                    Button {
                        preferences.fontSize = max(ReaderPreferences.minFontSize, preferences.fontSize - 1)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(preferences.fontSize <= ReaderPreferences.minFontSize)

                    Slider(
                        value: $preferences.fontSize,
                        in: ReaderPreferences.minFontSize...ReaderPreferences.maxFontSize,
                        step: 1
                    )
                    .tint(AppTheme.accent)

                    Button {
                        preferences.fontSize = min(ReaderPreferences.maxFontSize, preferences.fontSize + 1)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(preferences.fontSize >= ReaderPreferences.maxFontSize)

                    Text("\(Int(preferences.fontSize))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 26, alignment: .trailing)
                }
            }

            Divider().padding(.horizontal, 20)

            // ── Theme ──────────────────────────────────────────────────
            optionsSection("Theme") {
                HStack(spacing: 14) {
                    ForEach(ReaderTheme.allCases, id: \.rawValue) { theme in
                        ZStack(alignment: .topTrailing) {
                            ThemeSwatchButton(
                                theme: theme,
                                isSelected: preferences.theme == theme
                            ) {
                                if theme.isPremium && !store.isThemesUnlocked {
                                    showPaywall = true
                                } else {
                                    preferences.theme = theme
                                }
                            }
                            if theme.isPremium && !store.isThemesUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Color.black.opacity(0.6), in: Circle())
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    Spacer()
                }
            }

            Divider().padding(.horizontal, 20)

            // ── Font ───────────────────────────────────────────────────
            optionsSection("Font") {
                HStack(spacing: 8) {
                    ForEach(ReaderFont.allCases, id: \.rawValue) { font in
                        FontOptionButton(
                            font: font,
                            isSelected: preferences.fontFamily == font
                        ) {
                            preferences.fontFamily = font
                        }
                    }
                }
            }
            if store.isThemesUnlocked {
                Divider().padding(.horizontal, 20)

                optionsSection("Colors") {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            ColorPicker("", selection: Binding(
                                get: { preferences.textColor ?? Color(hexString: preferences.theme.text) ?? .white },
                                set: { preferences.textColor = $0 }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 44, height: 32)
                            Text("Text")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            if preferences.textColor != nil {
                                Button("Reset") { preferences.textColor = nil }
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .buttonStyle(.plain)
                            }
                        }

                        VStack(spacing: 4) {
                            ColorPicker("", selection: Binding(
                                get: { preferences.headingColor ?? Color(hexString: preferences.theme.heading) ?? .white },
                                set: { preferences.headingColor = $0 }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 44, height: 32)
                            Text("Heading")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            if preferences.headingColor != nil {
                                Button("Reset") { preferences.headingColor = nil }
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .buttonStyle(.plain)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PremiumPaywallView(focused: StoreService.ProductID.themes)
            }
            .presentationCornerRadius(.glassCornerRadius)
        }
    }

    @ViewBuilder
    private func optionsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            content()
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Theme swatch

private struct ThemeSwatchButton: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.swatchColor)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().strokeBorder(
                                isSelected ? AppTheme.accent : Color.primary.opacity(0.18),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.isLight ? Color.black : Color.white)
                    }
                }

                Text(theme.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Font option button

private struct FontOptionButton: View {
    let font: ReaderFont
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(font.rawValue)
                .font(font.displayFont)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    isSelected ? AppTheme.accentMuted : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? AppTheme.accent : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .foregroundStyle(isSelected ? AppTheme.accent : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar button

/// Individual icon button used in glass toolbar pills.
private struct ReaderToolbarButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(enabled ? Color.primary : Color.primary.opacity(0.25))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ArticleReaderView(url: URL(string: "https://paulgraham.com/taste.html")!)
    }
}
