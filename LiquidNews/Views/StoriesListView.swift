// StoriesListView.swift
// The main feed screen. Shows a system nav bar (title + toolbar buttons) and a
// sliding category picker, plus a paging list of story cards.
//
// Header hide/show strategy:
//   The system nav bar is always visible — its ToolbarItems get automatic iOS 26
//   glass grouping and we never toggle its visibility (which would change content
//   insets and cause jitter). The category picker lives in a .safeAreaInset so it
//   occupies a fixed layout slot; .offset() slides it visually without reflowing
//   the scroll content, giving a smooth hide/show on scroll.

import SwiftUI

struct StoriesListView: View {

    @State private var viewModel: StoriesViewModel
    @State private var selectedStory: HNItem?
    @State private var showingSearch = false
    @State private var headerVisible = true

    init(viewModel: StoriesViewModel = StoriesViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
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
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("LiquidNews")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSearch = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { settingsActionMenu } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        // Category picker occupies a fixed layout slot via safeAreaInset.
        // .offset() slides it visually without changing content insets.
        .safeAreaInset(edge: .top, spacing: 0) {
            categoryPickerRow
                .offset(y: headerVisible ? 0 : -300)
                .animation(.spring(duration: 0.35, bounce: 0), value: headerVisible)
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                StoryDetailView(story: story)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .task {
            await viewModel.load(category: .top)
        }
    }

    // MARK: - Category picker row (slides away on scroll)

    private var categoryPickerRow: some View {
        CategoryPicker(selected: viewModel.selectedCategory) { category in
            Task { await viewModel.load(category: category) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Settings menu content

    @ViewBuilder
    private var settingsActionMenu: some View {
        Section {
            Button {
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
            } label: {
                Label("Account", systemImage: "person.crop.circle")
            }
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
            await viewModel.refresh()
        }
        // Direction-change with threshold to avoid micro-jitter.
        // Because the header uses .offset (not layout), this callback never
        // receives a spurious offset change caused by the header animating.
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y
        } action: { old, new in
            // Always restore at the top
            if new <= 0 {
                withAnimation(.spring(duration: 0.35, bounce: 0)) { headerVisible = true }
                return
            }
            // Only react to moves larger than 4 pt to filter out bounce/noise
            guard abs(new - old) > 4 else { return }
            let scrollingDown = new > old
            withAnimation(.spring(duration: 0.35, bounce: 0)) {
                headerVisible = !scrollingDown
            }
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
            .foregroundStyle(isSelected ? AppTheme.accent : Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(in: Capsule())
            .overlay {
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
