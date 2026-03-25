// StoriesListView.swift
// The main feed screen. Shows a horizontal category picker and a paging
// list of story cards. Pull-to-refresh and infinite scroll are both supported.

import SwiftUI

struct StoriesListView: View {

    // `@State` creates a view-owned instance. Because StoriesViewModel is
    // @Observable, SwiftUI tracks exactly which properties this view reads.
    //
    // The optional init parameter lets previews inject pre-seeded data
    // without making a live network call.
    @State private var viewModel: StoriesViewModel
    @State private var selectedStory: HNItem?

    init(viewModel: StoriesViewModel = StoriesViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Full-bleed background — sits behind the glass cards
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                CategoryPicker(selected: viewModel.selectedCategory) { category in
                    Task { await viewModel.load(category: category) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Main content area
                Group {
                    if viewModel.isLoading && viewModel.stories.isEmpty {
                        LoadingView()
                    } else if let msg = viewModel.errorMessage, viewModel.stories.isEmpty {
                        ErrorView(message: msg) {
                            Task { await viewModel.refresh() }
                        }
                    } else {
                        storiesList
                    }
                }
            }
        }
        .navigationTitle("LiquidNews")
        .navigationBarTitleDisplayMode(.large)
        // Glass nav bar — blends with our background
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                StoryDetailView(story: story)
            }
            // Grabber pill — required by Apple HIG for interactive sheets
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
        .task {
            // Load top stories when the view first appears
            await viewModel.load(category: .top)
        }
    }

    // MARK: - Stories list

    private var storiesList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                    Button {
                        selectedStory = story
                    } label: {
                        StoryRowView(story: story, rank: index + 1)
                    }
                    .buttonStyle(.plain)
                    // Trigger next page when we're 5 items from the bottom
                    .onAppear {
                        if index >= viewModel.stories.count - 5 {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                }

                // Inline spinner shown only while paginating (not on initial load)
                if viewModel.isPaginating {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            // The `refreshable` modifier hooks into pull-to-refresh automatically
            await viewModel.refresh()
        }
    }
}

// MARK: - Category Picker

struct CategoryPicker: View {
    let selected: StoryCategory
    let onSelect: (StoryCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StoryCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selected == category,
                        action: { onSelect(category) }
                    )
                }
            }
        }
    }
}

struct CategoryChip: View {
    let category: StoryCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            // Use the accent tint for selected, white for idle
            .foregroundStyle(isSelected ? AppTheme.accent : Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            // Native glass pill — adapts to whatever's behind it
            .glassEffect(in: Capsule())
            .overlay {
                // Accent ring to mark the active selection
                if isSelected {
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.8), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: isSelected)
    }
}

// MARK: - Supporting views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.white)
            Text("Loading…")
                .font(AppTheme.captionFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("Couldn't load stories")
                .font(AppTheme.titleFont(18))
                .foregroundStyle(.white)
            Text(message)
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Feed — populated") {
    let vm = StoriesViewModel()
    vm.stories = PreviewData.stories
    return NavigationStack {
        StoriesListView(viewModel: vm)
    }
    .preferredColorScheme(.dark)
}

#Preview("Feed — loading") {
    let vm = StoriesViewModel()
    vm.isLoading = true
    return NavigationStack {
        StoriesListView(viewModel: vm)
    }
    .preferredColorScheme(.dark)
}
