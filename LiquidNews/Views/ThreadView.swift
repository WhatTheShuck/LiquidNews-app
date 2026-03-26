// ThreadView.swift
// Focused thread drill-down: shows a root comment with all its replies
// loaded inline. Presented when the user taps "Continue thread" at the
// depth threshold in the main comment list.

import SwiftUI

struct ThreadView: View {
    let rootComment: HNItem
    let depth: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                // Root comment (always depth 0 in this focused view)
                CommentView(comment: rootComment, depth: 0, maxDepth: .max)
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
