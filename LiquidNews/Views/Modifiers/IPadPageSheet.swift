// IPadPageSheet.swift
// Presents sheet content full-page on iPad rather than as a centered form sheet.
// Gated on the device idiom (not horizontalSizeClass) because an iPad form sheet
// reports a *compact* horizontal size class, which would defeat a size-class gate.
//
// NOTE: `presentationSizing(.page)` is only honoured when the *presenting* context
// has a regular horizontal size class. These sheets are presented from inside the
// NavigationSplitView detail column, which injects a spurious *compact* size class
// into its environment — that's corrected back to .regular in DetailColumnView so
// `.page` actually takes effect here. (See DetailColumnView's size-class override.)

import SwiftUI
import UIKit

private struct IPadPageSheet: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}

extension View {
    /// On iPad, present this sheet content full-page. No-op on iPhone.
    func iPadPageSheet() -> some View { modifier(IPadPageSheet()) }
}
