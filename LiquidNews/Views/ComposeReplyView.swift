// ComposeReplyView.swift
// Simple reply composer presented as a modal sheet.

import SwiftUI

extension Notification.Name {
    static let replyPosted = Notification.Name("LN_replyPosted")
}

struct ComposeReplyView: View {
    let parentId: Int

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 15

    @State private var text = ""
    @State private var isPosting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.system(size: bodySize))
                    .foregroundStyle(.primary)
                    .frame(minHeight: 140)
                    .padding(14)
                    .glassCard()
                    .accessibilityLabel("Reply text")

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Reply")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isPosting {
                    ProgressView().tint(.white)
                } else {
                    Button("Post") {
                        Task { await submit() }
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        isPosting = true
        error = nil
        do {
            try await HNAuthService.shared.reply(parentId: parentId, text: text)
            NotificationCenter.default.post(name: .replyPosted, object: nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isPosting = false
        }
    }
}
