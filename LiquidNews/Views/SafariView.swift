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
    /// Called when the user taps the controller's native "Done" button. Needed only
    /// when SafariView is embedded inline (not presented as a sheet root), where Done
    /// has no presenting controller to dismiss — e.g. the reader's fallback. nil for
    /// modal sheet usages, which UIKit dismisses automatically.
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
