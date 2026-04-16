// SavedView.swift
// Stories the user has bookmarked to read later.

import SwiftUI

struct SavedView: View {

    @State private var viewModel = SavedViewModel()
    @State private var selectedStory: HNItem?
    @State private var settings = UserSettings.shared

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                LoadingView()
            } else if let msg = viewModel.errorMessage, viewModel.stories.isEmpty {
                ErrorView(message: msg) {
                    Task { await viewModel.load(ids: store.savedIDs) }
                }
            } else if store.savedIDs.isEmpty {
                emptyState
            } else {
                savedList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(AppTab.saved.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(ids: store.savedIDs)
        }
        .onChange(of: store.savedIDs) { _, newIDs in
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

    // MARK: - List

    private var savedList: some View {
        List {
            ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                Button {
                    selectedStory = story
                } label: {
                    StoryRowView(story: story, rank: index + 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.remove(id: story.id)
                    } label: {
                        Label("Remove", systemImage: "bookmark.slash")
                    }
                    .tint(.gray)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.toggleFavourite(story.id)
                    } label: {
                        Label(
                            store.isFavourite(story.id) ? "Unfavourite" : "Favourite",
                            systemImage: store.isFavourite(story.id) ? "heart.slash" : "heart"
                        )
                    }
                    .tint(store.isFavourite(story.id) ? .gray : .orange)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await viewModel.load(ids: store.savedIDs)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: AppTab.saved.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("Nothing saved yet")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Bookmark a story to read it later.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { SavedView() }
        .preferredColorScheme(.dark)
}
