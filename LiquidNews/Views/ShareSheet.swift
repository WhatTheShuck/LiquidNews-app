// ShareSheet.swift
// UIKit bridge for the system share sheet.
//
// SwiftUI's `ShareLink` only works with `Transferable` types; for a raw URL
// with the system activity picker, UIActivityViewController is simpler.

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
