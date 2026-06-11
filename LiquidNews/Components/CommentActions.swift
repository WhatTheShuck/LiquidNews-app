// CommentActions.swift
// Reusable long-press confirmation-dialog content for a single comment.
// Used by CommentView.
//
// This is a content @ViewBuilder, not a wrapping View — callers attach it
// via `.confirmationDialog(...) { CommentActions(...) }` so the dialog chrome
// stays under each caller's control.

import SwiftUI
import UIKit

struct CommentActions: View {
    let comment: HNItem
    let effectiveMode: CommentRenderMode
    let hasUpvoted: Bool

    /// Closure called when the user toggles their vote. Receives the *new* upvoted state.
    var onToggleUpvote: () -> Void
    var onReply: () -> Void
    /// Switch the comment to plain-text rendering.
    var onSetTextOnly: () -> Void
    /// Clear any per-comment render override.
    var onRestoreFullRendering: () -> Void
    var onFlag: () -> Void

    private var isLoggedIn: Bool { HNAuthService.shared.isLoggedIn }

    var body: some View {
        Group {
            if isLoggedIn {
                Button(hasUpvoted ? "Unvote" : "Upvote", action: onToggleUpvote)
                Button("Reply", action: onReply)
            }

            Button("Copy Text") {
                UIPasteboard.general.string = comment.text?.htmlStripped ?? ""
            }

            let hnURL = URL(string: "https://news.ycombinator.com/item?id=\(comment.id)")!
            ShareLink(item: hnURL)

            if effectiveMode != .textOnly {
                Button("View as Plain Text", action: onSetTextOnly)
            } else {
                Button("Restore Full Rendering", action: onRestoreFullRendering)
            }

            if isLoggedIn {
                Button("Flag", role: .destructive, action: onFlag)
            }

            Button("Cancel", role: .cancel) {}
        }
    }
}
