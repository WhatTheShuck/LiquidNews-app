// CatchUpView.swift
// Browse top Hacker News stories from any past date range.
// Uses Algolia's HN Search API to fetch stories filtered by date, sorted by
// points (Top) or by recency (Recent).
//
// Layout:
//   - A .safeAreaInset controls strip with preset chips, sort chips, and an
//     optional custom date range picker. Slides away on scroll (same technique
//     as StoriesListView's category picker).
//   - A paginated List of StoryRowView cards below.

import SwiftUI

struct CatchUpView: View {

    @ScaledMetric(relativeTo: .headline)    private var titleSize:       CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var compactTitleSize: CGFloat = 14
    @ScaledMetric(relativeTo: .footnote)    private var chipSize:        CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var labelSize:       CGFloat = 14

    @State private var viewModel = CatchUpViewModel()
    @State private var selectedStory: HNItem?
    @State private var readerURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    // 0 = controls fully visible, 1 = controls fully hidden.
    @State private var controlsProgress: Double = 0
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.iPadNavModel) private var navModel

    private let store = SavedPostsStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                StoriesSkeletonView()
            } else if let msg = viewModel.errorMessage, viewModel.stories.isEmpty {
                ErrorView(message: msg) { Task { await viewModel.load() } }
            } else if !viewModel.isLoading && viewModel.stories.isEmpty {
                emptyState
            } else {
                storiesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .sectionIntroCoach(.catchUpIntro)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Principal: "Catch Up" title fades out as controls scroll away;
            // a compact pill showing the active range fades in to replace it.
            ToolbarItem(placement: .principal) {
                ZStack {
                    Text(AppTab.catchUp.label)
                        .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .opacity(max(0, 1 - controlsProgress * 2))
                        .scaleEffect(1 - controlsProgress * 0.25)

                    Text(viewModel.compactTitle)
                        .font(.system(size: compactTitleSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(in: Capsule())
                        .opacity(max(0, controlsProgress * 2 - 1))
                        .scaleEffect(0.75 + controlsProgress * 0.25)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            controlsArea
                .opacity(1 - controlsProgress * 1.6)
                .offset(y: -controlsProgress * 28)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.sortMode) { _, _ in
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.customFrom) { _, _ in
            if viewModel.preset == .custom { Task { await viewModel.load() } }
        }
        .onChange(of: viewModel.customTo) { _, _ in
            if viewModel.preset == .custom { Task { await viewModel.load() } }
        }
        .animation(.spring(duration: 0.25), value: viewModel.preset)
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
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

    // MARK: - Controls strip

    private var controlsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            presetRow
            HStack(spacing: 8) {
                sortRow
                Spacer()
            }
            if viewModel.preset == .custom {
                customDateRangePicker
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Preset chips

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(CatchUpPreset.allCases) { preset in
                presetChip(preset)
            }
        }
    }

    private func presetChip(_ preset: CatchUpPreset) -> some View {
        let isSelected = viewModel.preset == preset
        return Button {
            guard preset != viewModel.preset else { return }
            viewModel.preset = preset
            if preset != .custom { Task { await viewModel.load() } }
        } label: {
            Text(preset.rawValue)
                .font(.system(size: chipSize, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? AppTheme.accent : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(AppTheme.accent.opacity(0.8), lineWidth: 1.5)
                    }
                }
                .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: isSelected)
    }

    // MARK: - Sort chips

    private var sortRow: some View {
        HStack(spacing: 6) {
            ForEach(CatchUpSortMode.allCases, id: \.rawValue) { mode in
                sortChip(mode)
            }
        }
    }

    private func sortChip(_ mode: CatchUpSortMode) -> some View {
        let isSelected = viewModel.sortMode == mode
        return Button {
            guard mode != viewModel.sortMode else { return }
            viewModel.sortMode = mode
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.rawValue)
                    .font(.system(size: chipSize, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? AppTheme.accent : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.8), lineWidth: 1.5)
                }
            }
            .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: isSelected)
    }

    // MARK: - Custom date range picker

    private var customDateRangePicker: some View {
        VStack(spacing: 0) {
            HStack {
                Text("From")
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker(
                    "",
                    selection: $viewModel.customFrom,
                    in: ...min(viewModel.customTo, .now),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle()
                .fill(AppTheme.glassBorder)
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            HStack {
                Text("To")
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker(
                    "",
                    selection: $viewModel.customTo,
                    in: viewModel.customFrom ... .now,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Stories list

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
            guard let urlString = story.url, let url = URL(string: urlString) else {
                selectedStory = story; return
            }
            safariURL = IdentifiableURL(url)
        case .openReader:
            guard let urlString = story.url, let url = URL(string: urlString) else {
                selectedStory = story; return
            }
            readerURL = IdentifiableURL(url)
        case .openSafari:
            if let urlString = story.url, let url = URL(string: urlString) {
                openURL(url)
            } else {
                selectedStory = story
            }
        case .favourite: store.toggleFavourite(story.id)
        case .saveLater: store.toggleReadLater(story.id)
        case .hide:      store.hide(story)
        case .none:      break
        }
    }

    @ViewBuilder
    private func swipeActionButton(_ action: StoryAction, story: HNItem) -> some View {
        if action != .none {
            Button { performAction(action, story: story) } label: {
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

    private var storiesList: some View {
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
                .contextMenu {
                    Button(role: .destructive) { store.hide(story) } label: {
                        Label("Hide Post", systemImage: "eye.slash")
                    }
                    Divider()
                    Button { store.toggleFavourite(story.id) } label: {
                        Label(
                            store.isFavourite(story.id) ? "Unfavourite" : "Favourite",
                            systemImage: store.isFavourite(story.id) ? "heart.slash" : "heart"
                        )
                    }
                    Button { store.toggleReadLater(story.id) } label: {
                        Label(
                            store.isReadLater(story.id) ? "Remove from Read Later" : "Read Later",
                            systemImage: store.isReadLater(story.id) ? "bookmark.slash" : "bookmark"
                        )
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await viewModel.refresh() }
        // Drive controlsProgress directly from scroll offset — no withAnimation
        // so the transition speed matches the user's finger exactly.
        .onScrollGeometryChange(for: Double.self) {
            Double(min(max($0.contentOffset.y / 64, 0), 1))
        } action: { _, new in
            controlsProgress = new
        }
        // Snap to fully visible or fully hidden once scrolling settles.
        .onScrollPhaseChange { _, new in
            if new == .idle {
                withAnimation(.spring(duration: 0.42, bounce: 0.4)) {
                    controlsProgress = controlsProgress > 0.5 ? 1 : 0
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("No stories found")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.primary)
            Text("Try a different date range or sort order.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    NavigationStack { CatchUpView() }
}
