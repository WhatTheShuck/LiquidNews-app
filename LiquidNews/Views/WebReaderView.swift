// WebReaderView.swift
// In-app web reader built on WKWebView with a liquid glass bottom toolbar.
//
// Architecture note: WKWebView is UIKit, so we bridge it to SwiftUI using
// UIViewRepresentable. The Coordinator acts as the delegate and KVO observer,
// then pushes updates back to WebViewState (which is @Observable so SwiftUI
// re-renders when it changes).

import SwiftUI
import WebKit

// MARK: - State

/// Holds all observable WKWebView state and exposes action methods.
/// Created once in WebReaderView and passed down to the representable.
@Observable
final class WebViewState {
    var progress: Double = 0
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var pageTitle: String = ""

    // Weak reference — WKWebView is owned by UIKit, not by us
    weak var webView: WKWebView?

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }

    /// Reload if idle, stop if currently loading
    func reloadOrStop() {
        if isLoading {
            webView?.stopLoading()
        } else {
            webView?.reload()
        }
    }

    var currentURL: URL? { webView?.url }

    /// Injects or removes a minimal reader-mode stylesheet without reloading.
    func setReaderMode(_ enabled: Bool) {
        let js = enabled ? """
        var s = document.createElement('style');
        s.id = '_lnReader';
        s.textContent = [
          'body { max-width: 680px !important; margin: 40px auto !important;',
          '       padding: 0 24px !important; font-size: 18px !important;',
          '       line-height: 1.75 !important; background: #0d0d0d !important;',
          '       color: #ececec !important; }',
          'header, nav, footer, aside, [class*="ad-"], [class*="-ad"],',
          '[id*="sidebar"], [class*="sidebar"], [class*="banner"]',
          '{ display: none !important; }'
        ].join(' ');
        if (!document.getElementById('_lnReader')) { document.head.appendChild(s); }
        """ : """
        var s = document.getElementById('_lnReader');
        if (s) s.remove();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - UIViewRepresentable

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    let state: WebViewState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        // Swipe left/right to go back/forward — feels native
        webView.allowsBackForwardNavigationGestures = true

        // KVO — observe the properties we care about
        let keys = ["estimatedProgress", "canGoBack", "canGoForward", "title", "isLoading"]
        for key in keys {
            webView.addObserver(context.coordinator, forKeyPath: key,
                                options: .new, context: nil)
        }

        // Give WebViewState a handle so it can call goBack() etc.
        state.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Nothing to do — all updates flow through state
    }

    // Called automatically when the view is removed from the hierarchy;
    // we must remove KVO observers or the app will crash.
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        let keys = ["estimatedProgress", "canGoBack", "canGoForward", "title", "isLoading"]
        for key in keys {
            webView.removeObserver(coordinator, forKeyPath: key)
        }
    }

    // MARK: - Coordinator

    /// NSObject subclass that acts as WKNavigationDelegate and KVO observer.
    /// It's a class (not struct) so UIKit can hold a reference to it.
    final class Coordinator: NSObject, WKNavigationDelegate {
        let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        // KVO — called whenever an observed keyPath changes value
        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard let webView = object as? WKWebView else { return }
            // Always update UI on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch keyPath {
                case "estimatedProgress":
                    self.state.progress = webView.estimatedProgress
                case "canGoBack":
                    self.state.canGoBack = webView.canGoBack
                case "canGoForward":
                    self.state.canGoForward = webView.canGoForward
                case "title":
                    self.state.pageTitle = webView.title ?? ""
                case "isLoading":
                    self.state.isLoading = webView.isLoading
                default:
                    break
                }
            }
        }
    }
}

// MARK: - The full reader view

struct WebReaderView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var state = WebViewState()
    @State private var showingShareSheet = false
    @State private var readerMode = false

    var body: some View {
        ZStack(alignment: .top) {
            // Web content extends under the nav bar so the glass blends into the page
            WebViewRepresentable(url: url, state: state)
                .ignoresSafeArea()

            // Thin progress bar that grows left-to-right while loading
            if state.isLoading {
                ProgressBar(progress: state.progress)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Hide the nav bar fill — iOS 26 applies liquid glass to each item group
        // automatically. Adding our own background would double-layer the glass.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // ── Leading: dismiss ──
            // .cancellationAction gets the system glass group treatment (leading position)
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
            }

            // ── Trailing: reader mode toggle ──
            ToolbarItem(placement: .topBarTrailing) {
                Button(readerMode ? "Exit Reader" : "Reader",
                       systemImage: readerMode ? "textformat.alt" : "textformat") {
                    readerMode.toggle()
                    state.setReaderMode(readerMode)
                }
            }
        }
        // Floating glass pill controls above the home indicator
        .safeAreaInset(edge: .bottom) {
            glassBottomBar
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareURL = state.currentURL {
                ShareSheet(items: [shareURL])
            }
        }
    }

    // MARK: - Glass bottom toolbar

    // Floating pill groups — not a full-width bar. Liquid glass design language
    // uses discrete, shape-fitted glass surfaces rather than edge-to-edge bands.
    private var glassBottomBar: some View {
        HStack(spacing: 16) {
            // ── Back / Forward pill ──
            HStack(spacing: 0) {
                ReaderToolbarButton(icon: "chevron.left", enabled: state.canGoBack) {
                    state.goBack()
                }
                ReaderToolbarButton(icon: "chevron.right", enabled: state.canGoForward) {
                    state.goForward()
                }
            }
            .glassEffect(in: Capsule())

            // ── Reload / Stop pill ──
            ReaderToolbarButton(
                icon: state.isLoading ? "xmark" : "arrow.clockwise",
                enabled: true
            ) {
                state.reloadOrStop()
            }
            .glassEffect(in: Circle())

            // ── Share pill ──
            ReaderToolbarButton(icon: "square.and.arrow.up", enabled: true) {
                showingShareSheet = true
            }
            .glassEffect(in: Circle())
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Sub-components

/// Thin accent-colored bar that fills proportionally to page load progress
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            AppTheme.accent
                .frame(width: geo.size.width * progress, height: 3)
                .animation(.linear(duration: 0.1), value: progress)
        }
        .frame(height: 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Individual icon button for the bottom toolbar
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

/// Thin UIKit bridge for the system share sheet.
/// SwiftUI's `ShareLink` only works with `Transferable` types; for a raw URL
/// with the system activity picker, UIActivityViewController is simpler.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        WebReaderView(url: URL(string: "https://news.ycombinator.com")!)
    }
    .preferredColorScheme(.dark)
}
