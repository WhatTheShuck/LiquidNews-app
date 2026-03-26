// FavouritesView.swift
// List of all stories the user has hearted, mirroring StoriesListView's layout.

import SwiftUI

struct FavouritesView: View {

    @State private var viewModel = FavouritesViewModel()
    @State private var selectedStory: HNItem?

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                LoadingView()
            } else if let msg = viewModel.errorMessage, viewModel.stories.isEmpty {
                ErrorView(message: msg) {
                    Task { await viewModel.load(ids: store.favouriteIDs) }
                }
            } else if store.favouriteIDs.isEmpty {
                emptyState
            } else {
                favouritesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(AppTab.favourites.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(ids: store.favouriteIDs)
        }
        // Re-fetch whenever the user favourites/unfavourites from elsewhere in the app.
        .onChange(of: store.favouriteIDs) { _, newIDs in
            Task { await viewModel.load(ids: newIDs) }
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                StoryDetailView(story: story)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - Stories list

    private var favouritesList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                    Button {
                        selectedStory = story
                    } label: {
                        StoryRowView(story: story, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.remove(id: story.id)
                        } label: {
                            Label("Unfavourite", systemImage: "heart.slash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await viewModel.load(ids: store.favouriteIDs)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.favourites.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("No favourites yet")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Heart a story to save it here.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { FavouritesView() }
        .preferredColorScheme(.dark)
}
