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
    /// Extra top padding (in points) added to the article body so its content
    /// clears an overlaid control strip. Used by the side-by-side floating chrome,
    /// where the glass buttons sit above the page rather than in a nav bar.
    var topInset: Double = 0

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
            document.body.style.paddingTop = '\(28 + Int(topInset))px';
            // Image pages (Imgur galleries) keep their images regardless of the global
            // toggle; only article pages honour the no-images class.
            if (!document.body.classList.contains('image-page')) {
                document.body.classList.toggle('no-images', !\(showImagesJS));
            }

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

    /// Request to present the full-screen Quick Look image viewer. Set by the
    /// coordinator once gallery images have downloaded to temp files; cleared by
    /// ArticleReaderView's fullScreenCover on dismiss.
    struct ImagePreviewRequest: Identifiable, Equatable {
        let id = UUID()
        let fileURLs: [URL]
        let startIndex: Int
    }
    var pendingImagePreview: ImagePreviewRequest? = nil

    /// True while gallery images are downloading after an image tap, so the view can
    /// show a brief loading overlay instead of a blank wait.
    var isPreparingImagePreview: Bool = false

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

// MARK: - Chrome style

/// How the reader exposes its controls.
enum ReaderChromeStyle {
    case toolbar    // nav-bar buttons — iPhone sheet and the iPad replace path
    case floating   // glass-circle buttons overlaid on the pane — side-by-side
}

// MARK: - View

struct ArticleReaderView: View {
    let url: URL
    let chromeStyle: ReaderChromeStyle
    private let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var readerState = ReaderState()
    @State private var preferences: ReaderPreferences
    @State private var showReaderOptions = false
    @State private var isPreparingReport = false
    /// Shows a brief banner when extraction fails and the reader falls back to
    /// the original page in Safari, so the swap doesn't read as a broken reader.
    @State private var showReaderUnavailableToast = false
    @State private var readerLinkSafariURL: IdentifiableURL?
    @State private var readerLinkReaderURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @State private var wisdomQuote: String
    @State private var linkedHNStory: HNItem?

    init(url: URL, chromeStyle: ReaderChromeStyle = .toolbar, onClose: (() -> Void)? = nil) {
        self.url = url
        self.chromeStyle = chromeStyle
        self.onClose = onClose
        let prefs = ReaderPreferences()
        prefs.showImages = UserSettings.shared.readerShowImagesByDefault
        // Floating chrome overlays glass buttons on the page; pad the article down
        // so its title/first paragraph start below them instead of underneath.
        prefs.topInset = chromeStyle == .floating ? 64 : 0
        _preferences = State(initialValue: prefs)
        _wisdomQuote = State(initialValue: WordsOfWisdom.random)
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

    /// Switches between the reader and its Safari fallback. When extraction fails we
    /// render Safari *in place of* the reader rather than presenting it over the top —
    /// otherwise the blank, scene-attached WKWebView stays visible behind the sheet.
    private var readerContent: some View {
        Group {
            if isFailed {
                // ZStack (not .overlay on the safe-area-ignoring SafariView) so the
                // banner lays out inside the safe area instead of under the status bar.
                ZStack(alignment: .top) {
                    SafariView(url: url, onFinish: closeReader)
                        .ignoresSafeArea()

                    if showReaderUnavailableToast {
                        ReaderUnavailableBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            } else {
                readerBody
            }
        }
        .onChange(of: isFailed) { _, failed in
            if failed { showReaderUnavailable() }
        }
    }

    private var readerBody: some View {
        ZStack {
            // WKWebView is always present and scene-attached
            ReaderWebView(url: url, state: readerState)
                .ignoresSafeArea()

            // Overlay hides the raw page during loading and extraction
            if showOverlay {
                loadingOverlay
                    .transition(.opacity)
            }

            // Brief overlay while a tapped image's gallery downloads before Quick Look.
            if readerState.isPreparingImagePreview {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showOverlay)
        .sectionIntroCoach(.readerAppearance)
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
            if chromeStyle == .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        closeReader()
                    }
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

                        openInSafariButtons

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
        }
        .overlay(alignment: .top) {
            if chromeStyle == .floating {
                floatingControls
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
            // Clear the binding when Safari's Done button fires. The reader is itself a
            // sheet, so leaving this stale after UIKit auto-dismisses lets SwiftUI collapse
            // the reader alongside Safari.
            SafariView(url: item.url, onFinish: { readerLinkSafariURL = nil })
        }
        .sheet(item: $readerLinkReaderURL) { item in
            NavigationStack {
                ArticleReaderView(url: item.url)
            }
        }
        .sheet(isPresented: $showReaderOptions) {
            ReaderOptionsSheet(preferences: preferences)
                .presentationDetents([.height(StoreService.shared.isThemesUnlocked ? 380 : 300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .fullScreenCover(item: $readerState.pendingImagePreview) { request in
            QuickLookPreview(fileURLs: request.fileURLs, startIndex: request.startIndex)
                .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    /// Dismisses the reader, honouring an explicit `onClose` (used where the
    /// environment `dismiss` is a no-op, e.g. an iPad split-view detail column).
    private func closeReader() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// Escape-hatch entries for when the reader renders the page poorly. Neither
    /// closes the reader: in-app Safari opens over the top as a sheet (reusing the
    /// reader-link sheet), and Safari hands off to the system browser.
    ///
    /// Both actions drive SwiftUI presentation directly from the Menu button —
    /// setting the sheet item synchronously and using the `openURL` environment
    /// action — exactly like StoryDetailView's "More" menu. Routing the work through
    /// `DispatchQueue.main.asyncAfter` / `UIApplication.shared.open` instead mutates
    /// state outside SwiftUI's transaction and leaves the Menu's context-menu
    /// interaction in a bad state, which crashes deterministically with
    /// NSInternalInconsistencyException 'unexpected start state' when the autorelease
    /// pool drains. The async defer can't fix that — it's not a timing race.
    @ViewBuilder
    private var openInSafariButtons: some View {
        Button {
            readerLinkSafariURL = IdentifiableURL(url)
        } label: {
            Label("Open in In-App Safari", systemImage: "safari")
        }
        Button {
            openURL(url)
        } label: {
            Label("Open in Safari", systemImage: "arrow.up.right.square")
        }
    }

    /// Briefly surfaces a banner explaining the reader fell back to the original
    /// page, then auto-dismisses it.
    private func showReaderUnavailable() {
        withAnimation(.easeOut(duration: 0.25)) { showReaderUnavailableToast = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeIn(duration: 0.25)) { showReaderUnavailableToast = false }
        }
    }

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

            // Release builds get a polished, on-brand skeleton animation only.
            // Debug builds additionally surface the phase label and extraction log.
            VStack(spacing: 20) {
                ReaderLoadingAnimation()

                if settings.wordsOfWisdom && !wisdomQuote.isEmpty {
                    Text("\u{201C}\(wisdomQuote)\u{201D}")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }

                #if DEBUG
                Text(phaseLabel)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

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

    // MARK: - Floating controls

    @ViewBuilder
    private var floatingControls: some View {
        HStack(alignment: .top) {
            ReaderToolbarButton(icon: "xmark", enabled: true) {
                closeReader()
            }
            .glassEffect(in: Circle())

            Spacer()

            HStack(spacing: 8) {
                ReaderToolbarButton(icon: "textformat.size", enabled: readerState.isSuccess) {
                    showReaderOptions = true
                }
                .glassEffect(in: Circle())

                ReaderToolbarButton(icon: "arrow.clockwise", enabled: readerState.isSuccess) {
                    readerState.reloadArticle()
                }
                .glassEffect(in: Circle())

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
                    openInSafariButtons
                    Divider()
                    Button {
                        Task { await reportReaderIssue() }
                    } label: {
                        Label("Report Reader Issue", systemImage: "exclamationmark.bubble")
                    }
                    .disabled(isPreparingReport)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .glassEffect(in: Circle())
                .disabled(!readerState.isSuccess)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Loading animation
//
// A shimmering article-skeleton placeholder shown while the reader extracts.
// It previews the shape of an article (site label → title → body lines) with an
// accent-coloured highlight sweeping diagonally across it, so the wait reads as
// "laying out your article" rather than a generic spinner. On-brand and
// intentionally lightweight — pure SwiftUI shapes, one repeating animation.
private struct ReaderLoadingAnimation: View {
    /// Drives the highlight sweep. Animates from off-screen-left to off-screen-right.
    @State private var sweep: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { AppTheme.accent }

    /// Relative widths (0–1) of the faux body lines.
    private let lineWidths: [CGFloat] = [1.0, 0.92, 0.97, 0.78, 0.95, 0.6]

    var body: some View {
        skeleton
            .frame(maxWidth: 300)
            .overlay { if !reduceMotion { highlight } }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    sweep = 2
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Loading article")
    }

    /// The faint document outline — also reused as the mask for the highlight,
    /// so the sweep only paints over the bars, never the gaps.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 13) {
            bar(0.32, height: 9, color: accent.opacity(0.55))   // site label

            VStack(alignment: .leading, spacing: 9) {           // title
                bar(0.85, height: 17, color: .white.opacity(0.16))
                bar(0.62, height: 17, color: .white.opacity(0.16))
            }
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 10) {          // body
                ForEach(lineWidths.indices, id: \.self) { i in
                    bar(lineWidths[i], height: 8, color: .white.opacity(0.10))
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highlight: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, accent.opacity(0.7), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.55)
            .blur(radius: 8)
            .offset(x: sweep * geo.size.width)
        }
        .mask(skeleton)
        .allowsHitTesting(false)
    }

    private func bar(_ widthFraction: CGFloat, height: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(color)
                .frame(width: geo.size.width * widthFraction, height: height)
        }
        .frame(height: height)
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
            // Horizontal scroll so the full swatch row never overflows the sheet
            // width on narrow devices (8 themes don't fit edge-to-edge on small phones).
            optionsSection("Theme") {
                ScrollView(.horizontal, showsIndicators: false) {
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
                    }
                    // Vertical breathing room so the lock badge / selection ring
                    // aren't clipped by the ScrollView's content bounds.
                    .padding(.vertical, 2)
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

// MARK: - Reader-unavailable banner

/// Transient notice shown over the Safari fallback when extraction fails, so the
/// silent swap from reader → original page reads as intentional, not broken.
private struct ReaderUnavailableBanner: View {
    var body: some View {
        Label("Reader mode unavailable — showing the original page", systemImage: "safari")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
            .padding(.top, 12)
            .padding(.horizontal, 16)
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
