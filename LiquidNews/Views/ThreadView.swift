// ThreadView.swift
// Focused thread drill-down: shows a root comment with all its replies
// loaded inline. Presented when the user taps "Continue thread" at the
// depth threshold in the main comment list.

import SwiftUI

struct ThreadView: View {
    let rootComment: HNItem
    let depth: Int

    @State private var replies: [HNItem] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    private var threadColor: Color {
        AppTheme.threadColor(depth: depth)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 10) {
                    // Root comment (always depth 0 in this focused view)
                    CommentView(comment: rootComment, depth: 0, maxDepth: .max)

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white).padding(.vertical, 32)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .glassEffect(in: Circle())
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .principal) {
                Text("Thread")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}
