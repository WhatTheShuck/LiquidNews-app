// CuratedView.swift
// Chronological feed of curated articles from all enabled sources.
//
// Tap behaviour mirrors the main feed:
//   - Entries with an HN item ID → fetch full HNItem → open StoryDetailView
//     (which has the "Read Article" CTA inside, just like the main feed).
//   - JSON-only entries with no HN ID → open article directly in WebReaderView.

import SwiftUI

struct CuratedView: View {

    @State private var viewModel = CuratedViewModel()
    @State private var selectedStory: HNItem?
    @State private var webReaderURL: IdentifiableURL?

    var body: some View {
        Group {
            if viewModel.isLoadingInitial && viewModel.entries.isEmpty {
                LoadingView()
            } else if let error = viewModel.error, viewModel.entries.isEmpty {
                ErrorView(message: error) {
                    Task { await viewModel.refresh() }
                }
            } else if viewModel.entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(AppTab.curated.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        // HN thread (mirrors main feed sheet presentation)
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        // Fallback for JSON-only entries that have no HN thread
        .sheet(item: $webReaderURL) { item in
            NavigationStack { WebReaderView(url: item.url) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - Entries list

    private var entriesList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        Task { await open(entry) }
                    } label: {
                        CuratedEntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    // Trigger next newsletter page when within 5 rows of the bottom.
                    .onAppear {
                        if index >= viewModel.entries.count - 5 {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 16)
                }

                if !viewModel.canLoadMore && !viewModel.entries.isEmpty && !viewModel.isLoadingInitial {
                    Text("All caught up")
                        .font(AppTheme.captionFont(12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.curated.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("Nothing curated yet")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Enable sources in Settings\nto see curated content here.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Open entry

    /// Opens the entry the same way the main feed does:
    /// HN thread first (StoryDetailView), article from within that view.
    /// Falls back to WebReaderView for entries with no HN thread.
    private func open(_ entry: CuratedEntry) async {
        if let hnID = entry.hnItemID,
           let story = try? await HNAPIService.shared.item(id: hnID) {
            selectedStory = story
        } else {
            webReaderURL = IdentifiableURL(entry.url)
        }
    }
}

// MARK: - URL sheet wrapper

struct IdentifiableURL: Identifiable {
    let id: String
    let url: URL
    init(_ url: URL) { self.id = url.absoluteString; self.url = url }
}

// MARK: - Preview

#Preview {
    NavigationStack { CuratedView() }
        .preferredColorScheme(.dark)
}
