// ReaderState.swift
// Observable state driving the reader view: load phase, the WKWebView handle,
// pending link/HN/image intents, and the chrome-style enum. Extracted from
// ArticleReaderView (DESLOPPIFY M4) with no behaviour change.

import SwiftUI
import WebKit
import os

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
        Logger.reader.debug("\(message, privacy: .public)")
    }

    func applyPreferences(_ prefs: ReaderPreferences) {
        guard let wv = webView, case .success = phase else { return }
        wv.evaluateJavaScript(prefs.applyScript) { _, error in
            if let error { Logger.reader.error("applyScript error: \(error.localizedDescription, privacy: .public)") }
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
