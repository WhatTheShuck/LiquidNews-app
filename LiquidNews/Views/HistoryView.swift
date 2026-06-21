// HistoryView.swift
// Timestamped list of stories the user has opened, newest first.
// Uses local snapshots stored in SavedPostsStore — no network needed.

import SwiftUI

struct HistoryView: View {

    @State private var selectedStory: HNItem?
    @State private var showingClearConfirm = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.iPadNavModel) private var navModel

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if store.readHistory.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle(AppTab.history.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !store.readHistory.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear last 24 hours", role: .destructive) {
                            let cutoff = Date().addingTimeInterval(-86_400)
                            store.clearHistory(before: cutoff)
                        }
                        Button("Clear last 7 days", role: .destructive) {
                            let cutoff = Date().addingTimeInterval(-7 * 86_400)
                            store.clearHistory(before: cutoff)
                        }
                        Button("Clear all history", role: .destructive) {
                            showingClearConfirm = true
                        }
                    } label: {
                        Label("Clear", systemImage: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear all read history?",
            isPresented: $showingClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                store.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - History list

    private var historyList: some View {
        List {
            ForEach(store.readHistory) { entry in
                Button {
                    // Re-open from snapshot data — we don't re-fetch from API
                    let item = HNItem(
                        id:          entry.id,
                        type:        .story,
                        by:          entry.by,
                        time:        nil,
                        title:       entry.title,
                        url:         entry.url,
                        score:       entry.score,
                        descendants: nil,
                        text:        nil,
                        kids:        nil,
                        deleted:     nil,
                        dead:        nil
                    )
                    if let navModel {
                        navModel.select(item, mode: .comments)
                    } else {
                        selectedStory = item
                    }
                } label: {
                    HistoryRowView(entry: entry)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.removeHistoryEntry(id: entry.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: AppTab.history.systemImage,
            title: "No history yet",
            message: "Stories you open will appear here."
        )
    }
}

// MARK: - History row

private struct HistoryRowView: View {
    let entry: ReadHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Domain badge
            if let url = entry.url, let host = URL(string: url)?.host {
                let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                    Text(domain)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.accentMuted, in: Capsule())
            }

            Text(entry.title ?? "Untitled")
                .font(AppTheme.titleFont(15))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                if let score = entry.score {
                    MetaBadge(icon: "arrow.up", value: "\(score)")
                }
                if let by = entry.by {
                    MetaBadge(icon: "person", value: by)
                }
                Spacer()
                Text(entry.readAt, style: .relative)
                    .font(AppTheme.captionFont(11))
                    .foregroundStyle(.tertiary)
                + Text(" ago")
                    .font(AppTheme.captionFont(11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .glassCard()
    }
}

#Preview {
    NavigationStack { HistoryView() }
}
