// RegularSizeClass.swift
// Forces the hosting view controller(s) of this subtree to report a *regular*
// horizontal size class at the UIKit level.
//
// Why this exists: NavigationSplitView gives each column its own UIViewController
// whose traitCollection is *compact*, even when the window is regular-width. UIKit
// decides sheet sizing (page vs. small form) from that controller's real traits —
// and SwiftUI's `.environment(\.horizontalSizeClass, .regular)` does NOT change a
// controller's traitCollection, so `presentationSizing(.page)` flashed page then
// "smooshed" back to form as UIKit settled on the compact trait. `traitOverrides`
// (iOS 17+) is the only lever that overrides a controller's inherited traits, so we
// set it on the presenting ancestors here.

import SwiftUI
import UIKit

private struct RegularSizeClassController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.applyOverrides()
    }

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyOverrides()
        }

        /// Walk up the controller hierarchy and override every ancestor that
        /// reports compact back to regular. This targets the spuriously-compact
        /// NavigationSplitView column controller(s); the genuinely-regular window
        /// root and split container are left untouched. `traitOverrides` outranks
        /// inherited traits, so it sticks even when the split re-lays out.
        func applyOverrides() {
            var node: UIViewController? = parent
            while let current = node {
                if current.traitCollection.horizontalSizeClass == .compact {
                    current.traitOverrides.horizontalSizeClass = .regular
                }
                node = current.parent
            }
        }
    }
}

extension View {
    /// Restores a regular horizontal size class for sheet presentation when this
    /// view lives inside a NavigationSplitView column (which spuriously reports
    /// compact). Apply on the detail column so `presentationSizing(.page)` sheets
    /// presented from within it size as page sheets instead of small form sheets.
    func forceRegularSizeClassForPresentations() -> some View {
        background(RegularSizeClassController())
    }
}
