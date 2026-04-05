// ThreadView.swift
// Focused thread drill-down: shows a root comment with all its replies
// loaded inline. Presented when the user taps "Continue thread" at the
// depth threshold in the main comment list.

import SwiftUI

struct ThreadView: View {
    let rootComment: HNItem
    let depth: Int
    var opUsername: String? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                // Root comment shown at depth 0 in this focused view.
                // Use the same maxDepth as the main view so "Continue thread"
                // buttons still appear for very deep replies, letting the user
                // drill down via further sheets rather than infinite nesting
                // (which would collapse the available width to nothing).
                CommentView(comment: rootComment, depth: 0, maxDepth: UserSettings.shared.maxAutoExpandDepth, opUsername: opUsername)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Thread")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}
