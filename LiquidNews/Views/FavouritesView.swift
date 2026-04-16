// FavouritesView.swift
// List of all stories the user has hearted, mirroring StoriesListView's layout.

import SwiftUI

struct FavouritesView: View {

    @State private var viewModel = FavouritesViewModel()
    @State private var selectedStory: HNItem?
    @State private var webReaderURL: IdentifiableURL?
    @State private var webReaderInitialReaderMode = false
    @State private var safariURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @Environment(\.openURL) private var openURL

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
        .sheet(item: $webReaderURL) { item in
            NavigationStack {
                WebReaderView(url: item.url, initialReaderMode: webReaderInitialReaderMode)
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
        switch action {
        case .openComments:
            selectedStory = story
        case .openBrowser:
            guard let urlString = story.url, let url = URL(string: urlString) else { selectedStory = story; return }
            safariURL = IdentifiableURL(url)
        case .openReader:
            guard let urlString = story.url, let url = URL(string: urlString) else { selectedStory = story; return }
            webReaderInitialReaderMode = true
            webReaderURL = IdentifiableURL(url)
        case .openSafari:
            if let urlString = story.url, let url = URL(string: urlString) { openURL(url) } else { selectedStory = story }
        case .favourite:
            store.toggleFavourite(story.id)
        case .saveLater:
            store.toggleSaved(story.id)
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
            return Label(store.isSaved(story.id) ? "Unsave" : "Save",
                         systemImage: store.isSaved(story.id) ? "bookmark.slash" : "bookmark")
        default:
            return Label(action.label, systemImage: action.systemImage)
        }
    }

    private func swipeTint(for action: StoryAction, story: HNItem) -> Color {
        switch action {
        case .favourite: return store.isFavourite(story.id) ? .gray : .orange
        case .saveLater: return store.isSaved(story.id) ? .gray : .indigo
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
