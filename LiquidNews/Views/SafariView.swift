// SafariView.swift
// UIViewControllerRepresentable wrapper around SFSafariViewController.
// Used for the "Open in Browser" action — gives the user a full Safari
// experience (Reader Mode, content blockers, autofill) without leaving
// the app.

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var readerMode: Bool = UserSettings.shared.safariReaderMode
    /// Called when the user taps the controller's native "Done" button. Required for
    /// inline embeds (the reader's fallback), where Done has no presenting controller to
    /// dismiss. Also required for SafariView presented as a sheet *over another sheet*:
    /// UIKit auto-dismisses Safari but leaves SwiftUI's `.sheet(item:)` binding stale,
    /// which makes SwiftUI collapse the parent sheet too — pass a closure that clears the
    /// binding. Only a top-level (non-nested) sheet can safely leave this nil.
    var onFinish: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = readerMode
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: (() -> Void)?

        init(onFinish: (() -> Void)?) {
            self.onFinish = onFinish
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinish?()
        }
    }
}
