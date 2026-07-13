// ThreadView.swift
// Focused thread drill-down: shows a root comment with all its replies
// loaded inline. Presented when the user taps "Continue thread" at the
// depth threshold in the main comment list, or opened directly via deep link.

import SwiftUI
import os

struct ThreadView: View {
    let rootComment: HNItem
    let depth: Int
    var opUsername: String? = nil
    var onShowStory: ((HNItem) -> Void)? = nil
    /// Optional explicit close action. Used where the environment `dismiss` is a
    /// no-op, e.g. an iPad split-view detail column. When nil, the ✕ button falls
    /// back to `dismiss()` (the iPhone sheet case).
    var onClose: (() -> Void)? = nil

    @State private var resolvedStory: HNItem?
    @State private var isLoadingStory = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        rootComment: HNItem,
        depth: Int,
        opUsername: String? = nil,
        story: HNItem? = nil,
        onClose: (() -> Void)? = nil,
        onShowStory: ((HNItem) -> Void)? = nil
    ) {
        self.rootComment = rootComment
        self.depth = depth
        self.opUsername = opUsername
        self.onClose = onClose
        self.onShowStory = onShowStory
        _resolvedStory = State(initialValue: story)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                CommentView(
                    comment: rootComment,
                    depth: 0,
                    maxDepth: UserSettings.shared.maxAutoExpandDepth,
                    opUsername: opUsername,
                    story: resolvedStory
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(ThemeBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    if let onClose { onClose() } else { dismiss() }
                }
            }

            ToolbarItem(placement: .principal) {
                Text(resolvedStory?.title ?? "Thread")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isLoadingStory {
                    ProgressView().scaleEffect(0.8)
                } else if let story = resolvedStory, onShowStory != nil {
                    Button {
                        onShowStory?(story)
                    } label: {
                        Label("Story", systemImage: "doc.text")
                    }
                }
            }
        }
        .task {
            guard resolvedStory == nil, rootComment.type == .comment else { return }
            isLoadingStory = true
            do {
                resolvedStory = try await HNAPIService.shared.rootStory(forItemID: rootComment.id)
            } catch {
                // Non-critical: the "Story" toolbar button just stays hidden. Log for diagnosis.
                Logger.reader.debug("ThreadView: rootStory fetch failed: \(error.localizedDescription, privacy: .public)")
            }
            isLoadingStory = false
        }
    }
}
