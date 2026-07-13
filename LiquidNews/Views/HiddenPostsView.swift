// HiddenPostsView.swift
// Shows all posts the user has hidden, allowing them to be individually
// un-hidden or cleared in bulk.

import SwiftUI

struct HiddenPostsView: View {

    @State private var selectedStory: HNItem?
    @State private var showingClearConfirm = false
    @Environment(\.colorScheme) private var colorScheme

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if store.hiddenPosts.isEmpty {
                emptyState
            } else {
                hiddenList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground().ignoresSafeArea())
        .navigationTitle("Hidden Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !store.hiddenPosts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        showingClearConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Clear all hidden posts?",
            isPresented: $showingClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { store.clearHidden() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These posts will reappear in your feeds.")
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .glassSheet()
                .iPadPageSheet()
        }
    }

    // MARK: - List

    private var hiddenList: some View {
        List {
            Section {
                Text("\(store.hiddenPosts.count) hidden \(store.hiddenPosts.count == 1 ? "post" : "posts"). Swipe right to unhide.")
                    .font(AppTheme.bodyFont(12))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
            }

            ForEach(store.hiddenPosts) { entry in
                Button {
                    // Open from snapshot — full item re-fetched when detail loads comments
                    selectedStory = HNItem(
                        id:          entry.id,
                        type:        .story,
                        by:          entry.by,
                        time:        nil,
                        title:       entry.title,
                        url:         entry.url,
                        score:       nil,
                        descendants: nil,
                        text:        nil,
                        kids:        nil,
                        deleted:     nil,
                        dead:        nil
                    )
                } label: {
                    HiddenPostRowView(entry: entry)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.unhide(entry.id)
                    } label: {
                        Label("Unhide", systemImage: "eye")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.unhide(entry.id)
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
        VStack(spacing: 14) {
            Image(systemName: "eye.slash")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("No hidden posts")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.primary)
            Text("Posts you hide will appear here.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Hidden post row

private struct HiddenPostRowView: View {
    let entry: HiddenPostEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Untitled")
                    .font(AppTheme.titleFont(14))
                    .foregroundStyle(.primary.opacity(0.6))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let by = entry.by {
                        Text(by)
                            .font(AppTheme.captionFont(11))
                            .foregroundStyle(.tertiary)
                    }
                    if let url = entry.url, let host = URL(string: url)?.host {
                        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                        Text(domain)
                            .font(AppTheme.captionFont(11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("\(entry.hiddenAt, style: .relative) ago")
                        .font(AppTheme.captionFont(11))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard()
    }
}

#Preview {
    NavigationStack { HiddenPostsView() }
}
