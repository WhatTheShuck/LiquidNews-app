// QuickLookPreview.swift
// Full-screen, zoomable, swipeable image viewer wrapping QLPreviewController.
// Inputs are LOCAL FILE URLs (Quick Look requires file URLs) produced by
// ImgurImageActions.localFiles. Mirrors SafariView's representable pattern.

import SwiftUI
import QuickLook

struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURLs: [URL]
    let startIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(fileURLs: fileURLs) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        // Clamp so an out-of-range start index can never crash the viewer.
        let lastIndex = max(fileURLs.count - 1, 0)
        controller.currentPreviewItemIndex = min(max(startIndex, 0), lastIndex)
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.fileURLs = fileURLs
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURLs: [URL]
        init(fileURLs: [URL]) { self.fileURLs = fileURLs }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            fileURLs.count
        }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            fileURLs[index] as NSURL
        }
    }
}
