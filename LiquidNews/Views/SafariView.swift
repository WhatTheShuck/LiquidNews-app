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

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = readerMode
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
