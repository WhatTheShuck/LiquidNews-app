// ReadLaterView.swift
// Stories the user has bookmarked to read later.

import SwiftUI

struct ReadLaterView: View {

    @State private var viewModel = ReadLaterViewModel()
    @State private var selectedStory: HNItem?
    @State private var settings = UserSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.iPadNavModel) private var navModel

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                StoriesSkeletonView()
            } else if let msg = viewModel.errorMessage, viewModel.stories.isEmpty {
                ErrorView(message: msg) {
                    Task { await viewModel.load(ids: store.readLaterIDs) }
                }
            } else if store.readLaterIDs.isEmpty {
                emptyState
            } else {
                readLaterList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground().ignoresSafeArea())
        .sectionIntroCoach(.readLaterIntro)
        .navigationTitle(AppTab.readLater.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .task {
            await viewModel.load(ids: store.readLaterIDs)
        }
        .onChange(of: store.readLaterIDs) { _, newIDs in
            Task { await viewModel.load(ids: newIDs) }
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                StoryDetailView(story: story)
            }
            .glassSheet()
        }
    }

    // MARK: - Sort menu

    private var sortMenu: some View {
        Menu {
            ForEach(ReadLaterSort.allCases, id: \.self) { option in
                Button {
                    viewModel.sort = option
                    viewModel.applySort()
                } label: {
                    if viewModel.sort == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - List

    private var readLaterList: some View {
        List {
            ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                Button {
                    RecentStoryStore.shared.record(story)
                    if let navModel {
                        navModel.select(story, mode: .comments)
                    } else {
                        selectedStory = story
                    }
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
            await viewModel.load(ids: store.readLaterIDs)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: AppTab.readLater.systemImage,
            title: "You're all caught up",
            message: "Bookmark a story to save it for later."
        )
    }
}

#Preview {
    NavigationStack { ReadLaterView() }
}
