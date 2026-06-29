// FavouritesView.swift
// List of all stories the user has hearted, mirroring StoriesListView's layout.

import SwiftUI

struct FavouritesView: View {

    @State private var viewModel = FavouritesViewModel()
    @State private var selectedStory: HNItem?
    @State private var readerURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.iPadNavModel) private var navModel

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                StoriesSkeletonView()
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
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .sectionIntroCoach(.favouritesIntro)
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
        .sheet(item: $readerURL) { item in
            NavigationStack {
                ArticleReaderView(url: item.url)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
        }
    }

    // MARK: - Actions

    private func performAction(_ action: StoryAction, story: HNItem) {
        if DetailMode.forSelection(action: action, hasURL: story.url != nil) != nil {
            RecentStoryStore.shared.record(story)
        }
        // iPad split view: route navigation actions into the detail column.
        // Side-effect actions (favourite/saveLater/hide/none) fall through to
        // the existing switch so swipe actions keep working unchanged.
        if let navModel, let mode = DetailMode.forSelection(action: action, hasURL: story.url != nil) {
            if action == .openSafari, let urlString = story.url, let url = URL(string: urlString) {
                openURL(url)
            }
            navModel.select(story, mode: mode)
            return
        }
        switch action {
        case .openComments:
            selectedStory = story
        case .openBrowser:
            guard let urlString = story.url, let url = URL(string: urlString) else { selectedStory = story; return }
            safariURL = IdentifiableURL(url)
        case .openReader:
            guard let urlString = story.url, let url = URL(string: urlString) else { selectedStory = story; return }
            readerURL = IdentifiableURL(url)
        case .openSafari:
            if let urlString = story.url, let url = URL(string: urlString) { openURL(url) } else { selectedStory = story }
        case .favourite:
            store.toggleFavourite(story.id)
        case .saveLater:
            store.toggleReadLater(story.id)
        case .hide:
            store.hide(story)
        case .none:
            break
        }
    }

    @ViewBuilder
    private func swipeActionButton(_ action: StoryAction, story: HNItem) -> some View {
        if action != .none {
            Button {
                performAction(action, story: story)
            } label: {
                swipeLabel(for: action, story: story)
            }
            .tint(swipeTint(for: action, story: story))
        }
    }

    private func swipeLabel(for action: StoryAction, story: HNItem) -> Label<Text, Image> {
        switch action {
        case .favourite:
            return Label(store.isFavourite(story.id) ? "Unfavourite" : "Favourite",
                         systemImage: store.isFavourite(story.id) ? "heart.slash" : "heart")
        case .saveLater:
            return Label(store.isReadLater(story.id) ? "Remove" : "Read Later",
                         systemImage: store.isReadLater(story.id) ? "bookmark.slash" : "bookmark")
        default:
            return Label(action.label, systemImage: action.systemImage)
        }
    }

    private func swipeTint(for action: StoryAction, story: HNItem) -> Color {
        switch action {
        case .favourite: return store.isFavourite(story.id) ? .gray : .orange
        case .saveLater: return store.isReadLater(story.id) ? .gray : .indigo
        default:         return action.swipeTint
        }
    }

    // MARK: - Stories list

    private var favouritesList: some View {
        List {
            ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                Button {
                    performAction(settings.tapAction, story: story)
                } label: {
                    StoryRowView(story: story, rank: index + 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    swipeActionButton(settings.swipeLeftAction, story: story)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    swipeActionButton(settings.swipeRightAction, story: story)
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
            await viewModel.load(ids: store.favouriteIDs)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: AppTab.favourites.systemImage,
            title: "No favourites yet",
            message: "Open a story and use the heart action to favourite it."
        )
    }
}

#Preview {
    NavigationStack { FavouritesView() }
}
