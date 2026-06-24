// IPadPageSheet.swift
// Presents sheet content full-page on iPad rather than as a centered form sheet.
// Gated on the device idiom (not horizontalSizeClass) because an iPad form sheet
// reports a *compact* horizontal size class, which would defeat a size-class gate.
//
// `presentationSizing(.page)` alone isn't enough here: these sheets are presented
// from StoryDetailView, which on iPad lives inside the NavigationSplitView detail
// column — and those columns report a *compact* horizontal size class. iPadOS 18+
// silently downgrades `.page` to `.form` sizing whenever the presenting context is
// compact, so the sheet came up as a small centered card. Overriding the size class
// to `.regular` on the presentation removes that downgrade and lets `.page` apply.

import SwiftUI
import UIKit

private struct IPadPageSheet: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .presentationSizing(.page)
                .environment(\.horizontalSizeClass, .regular)
        } else {
            content
        }
    }
}

extension View {
    /// On iPad, present this sheet content full-page. No-op on iPhone.
    func iPadPageSheet() -> some View { modifier(IPadPageSheet()) }
}
