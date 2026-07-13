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
import os

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
                    .glassSheet()
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
                .glassSheet()
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
