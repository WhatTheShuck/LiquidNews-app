// SafariView.swift
// UIViewControllerRepresentable wrapper around SFSafariViewController.
// Used for the "Open in Browser" action — gives the user a full Safari
// experience (Reader Mode, content blockers, autofill) without leaving
// the app.

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
