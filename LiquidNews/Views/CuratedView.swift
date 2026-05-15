// CuratedView.swift
// Chronological feed of curated articles from all enabled sources.
//
// Tap behaviour: fetch full HNItem → open StoryDetailView
// (which has the "Read Article" CTA inside, just like the main feed).
// All curated entries are required to have an HN item ID — URL-only entries
// are filtered out at ingestion time in CuratedStore.

import SwiftUI

// MARK: - Preference key for chip centre measurement

private struct ChipCenterKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Source chip data

private struct SourceItem: Identifiable {
    /// "all" | BuiltInCuratedSource.rawValue | CustomCuratedFeed.id.uuidString
    let id: String
    let label: String
}

struct CuratedView: View {

    @State private var viewModel = CuratedViewModel()
    @State private var selectedStory: HNItem?
    @State private var readerURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @Environment(\.openURL) private var openURL
    private let store = SavedPostsStore.shared
    /// True when the user has dismissed the banner for the current load cycle only.
    @State private var bannerHiddenThisLoad = false

    // MARK: Source filter

    /// nil = show all sources.
    @State private var selectedSourceID: String? = nil
    @Namespace private var chipNamespace
    /// 0 = picker fully visible, 1 = picker fully hidden (mirrors StoriesListView).
    @State private var pickerProgress: Double = 0
    @State private var chipCenters: [Int: CGFloat] = [:]
    @State private var pickerRowWidth: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if (viewModel.isLoadingInitial || viewModel.isRefreshing) && viewModel.entries.isEmpty {
                CuratedSkeletonView()
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
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle(AppTab.curated.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(item: $readerURL) { item in
            NavigationStack { ArticleReaderView(url: item.url) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
        }
    }

    // MARK: - Source data

    /// Enabled built-in + custom feed sources. Chips are shown only when ≥ 2 are enabled.
    private var enabledSources: [SourceItem] {
        var items: [SourceItem] = []
        for source in BuiltInCuratedSource.allCases {
            if settings.enabledBuiltInCuratedSources.contains(source.rawValue) {
                items.append(SourceItem(id: source.rawValue, label: source.name))
            }
        }
        for feed in settings.customCuratedFeeds where feed.isEnabled {
            items.append(SourceItem(id: feed.id.uuidString, label: feed.name))
        }
        return items
    }

    /// "All" chip followed by one chip per enabled source.
    private var allChips: [SourceItem] {
        [SourceItem(id: "all", label: "All")] + enabledSources
    }

    // MARK: - Filtering

    /// Source-filtered entries from the view model.
    private var filteredEntries: [CuratedEntry] {
        guard let sourceID = selectedSourceID else { return viewModel.entries }
        return viewModel.entries.filter { entry in
            entry.sources.contains { source in
                switch source {
                case .newsletter:
                    return sourceID == BuiltInCuratedSource.hackerNewsletter.rawValue
                case .json(let feedID):
                    return feedID == sourceID
                }
            }
        }
    }

    /// Source-filtered entries with hidden posts removed.
    /// Reactive: SavedPostsStore is @Observable so this recomputes whenever hiddenIDs changes.
    private var visibleEntries: [CuratedEntry] {
        filteredEntries.filter { entry in
            guard let id = entry.hnItemID else { return true }
            return !store.isHidden(id)
        }
    }

    // MARK: - Entries list

    private var entriesList: some View {
        List {
            if (viewModel.isLoadingInitial || viewModel.isRefreshing)
                && !settings.hideCuratedLoadingBanner
                && !bannerHiddenThisLoad {
                refreshingBanner
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
            }

            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    performAction(settings.tapAction, entry: entry)
                } label: {
                    CuratedEntryRowView(entry: entry)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    swipeActionButton(settings.swipeLeftAction, entry: entry)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    swipeActionButton(settings.swipeRightAction, entry: entry)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                // Trigger next page when within 5 rows of the bottom of visible entries.
                .onAppear {
                    if index >= visibleEntries.count - 5 {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !viewModel.canLoadMore && !visibleEntries.isEmpty && !viewModel.isLoadingInitial {
                Text("All caught up")
                    .font(AppTheme.captionFont(12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if visibleEntries.isEmpty && selectedSourceID != nil {
                Text("No entries from this source")
                    .font(AppTheme.bodyFont(14))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await viewModel.refresh()
        }
        // Reset the "hide once" flag whenever a new load/refresh cycle begins.
        .onChange(of: viewModel.isLoadingInitial) { _, isLoading in if isLoading { bannerHiddenThisLoad = false } }
        .onChange(of: viewModel.isRefreshing)     { _, isRefreshing in if isRefreshing { bannerHiddenThisLoad = false } }
        // Drive pickerProgress directly from scroll offset — no withAnimation wrapper
        // so the transition speed exactly matches the user's finger.
        // Range: 0–64 pt maps to progress 0–1.
        .onScrollGeometryChange(for: Double.self) {
            Double(min(max($0.contentOffset.y / 64, 0), 1))
        } action: { _, new in
            pickerProgress = new
        }
        // Snap to nearest end state once inertia settles.
        .onScrollPhaseChange { _, new in
            if new == .idle {
                withAnimation(.spring(duration: 0.42, bounce: 0.4)) {
                    pickerProgress = pickerProgress > 0.5 ? 1 : 0
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            sourcePickerRow
                .opacity(1 - pickerProgress * 1.6)
                .offset(y: -pickerProgress * 24)
        }
    }

    // MARK: - Swipe actions

    private func performAction(_ action: StoryAction, entry: CuratedEntry) {
        switch action {
        case .openComments:
            // StoryDetailView.task handles recordRead + auto-hide for this path.
            Task { await open(entry) }
        case .openBrowser:
            recordReadAndMaybeHide(entry)
            safariURL = IdentifiableURL(entry.url)
        case .openReader:
            recordReadAndMaybeHide(entry)
            readerURL = IdentifiableURL(entry.url)
        case .openSafari:
            recordReadAndMaybeHide(entry)
            openURL(entry.url)
        case .favourite:
            guard let id = entry.hnItemID else { return }
            store.toggleFavourite(id)
        case .saveLater:
            guard let id = entry.hnItemID else { return }
            store.toggleReadLater(id)
        case .hide:
            guard let id = entry.hnItemID else { return }
            store.hide(id: id, title: entry.title, url: entry.url.absoluteString)
        case .none:
            break
        }
    }

    /// Records the entry as read and, if readBehaviour is .hide, hides it from the feed
    /// (mirroring what StoryDetailView.task does for the openComments path).
    private func recordReadAndMaybeHide(_ entry: CuratedEntry) {
        guard let id = entry.hnItemID else { return }
        store.recordRead(id: id, title: entry.title, url: entry.url.absoluteString)
        if settings.readBehaviour == .hide,
           !store.isFavourite(id),
           !store.isReadLater(id) {
            store.hide(id: id, title: entry.title, url: entry.url.absoluteString)
        }
    }

    @ViewBuilder
    private func swipeActionButton(_ action: StoryAction, entry: CuratedEntry) -> some View {
        if action != .none {
            Button {
                performAction(action, entry: entry)
            } label: {
                swipeLabel(for: action, entry: entry)
            }
            .tint(swipeTint(for: action, entry: entry))
        }
    }

    private func swipeLabel(for action: StoryAction, entry: CuratedEntry) -> Label<Text, Image> {
        guard let id = entry.hnItemID else {
            return Label(action.label, systemImage: action.systemImage)
        }
        switch action {
        case .favourite:
            return Label(store.isFavourite(id) ? "Unfavourite" : "Favourite",
                         systemImage: store.isFavourite(id) ? "heart.slash" : "heart")
        case .saveLater:
            return Label(store.isReadLater(id) ? "Remove" : "Read Later",
                         systemImage: store.isReadLater(id) ? "bookmark.slash" : "bookmark")
        default:
            return Label(action.label, systemImage: action.systemImage)
        }
    }

    private func swipeTint(for action: StoryAction, entry: CuratedEntry) -> Color {
        guard let id = entry.hnItemID else { return action.swipeTint }
        switch action {
        case .favourite: return store.isFavourite(id) ? .gray : .orange
        case .saveLater: return store.isReadLater(id) ? .gray : .indigo
        default:         return action.swipeTint
        }
    }

    // MARK: - Source picker row

    /// Shown only when 2 or more sources are enabled — nothing to filter otherwise.
    @ViewBuilder
    private var sourcePickerRow: some View {
        if enabledSources.count >= 2 {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    ForEach(Array(allChips.enumerated()), id: \.element.id) { index, chip in
                        let isSelected = chip.id == "all"
                            ? selectedSourceID == nil
                            : selectedSourceID == chip.id
                        CuratedSourceChip(
                            label: chip.label,
                            isSelected: isSelected,
                            chipID: chip.id,
                            namespace: chipNamespace,
                            mergeProgress: pickerProgress
                        )
                        .frame(maxWidth: .infinity)
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ChipCenterKey.self,
                                    value: [index: geo.frame(in: .named("sourcePickerRow")).midX]
                                )
                            }
                        }
                        .animation(.bouncy(duration: 0.4), value: selectedSourceID)
                        .offset(x: chipConvergenceOffset(for: index))
                        .zIndex(zIndex(for: index))
                    }
                }
                .padding(.horizontal, 12)
                .coordinateSpace(.named("sourcePickerRow"))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("sourcePickerRow"))
                        .onChanged { value in selectNearest(to: value.location.x) }
                        .onEnded   { value in selectNearest(to: value.location.x) }
                )
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pickerRowWidth = $0 }
            .onPreferenceChange(ChipCenterKey.self) { chipCenters = $0 }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Chip helpers

    private func zIndex(for index: Int) -> Double {
        let n = allChips.count
        return Double(n - abs(index - n / 2)) * pickerProgress
    }

    private func chipConvergenceOffset(for index: Int) -> CGFloat {
        guard let center = chipCenters[index], pickerRowWidth > 0 else {
            return CGFloat(allChips.count / 2 - index) * 90 * CGFloat(pickerProgress)
        }
        return (pickerRowWidth / 2 - center) * CGFloat(pickerProgress)
    }

    private func selectNearest(to x: CGFloat) {
        guard !chipCenters.isEmpty,
              let nearest = chipCenters.min(by: { abs($0.value - x) < abs($1.value - x) }) else { return }
        let chip = allChips[nearest.key]
        let newID: String? = chip.id == "all" ? nil : chip.id
        guard newID != selectedSourceID else { return }
        selectedSourceID = newID
    }

    // MARK: - Refresh banner

    private var refreshingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Loading curated stories…")
                    .font(AppTheme.bodyFont(13))
                    .foregroundStyle(.primary)
                Text("Newsletter parsing may take a moment.")
                    .font(AppTheme.captionFont(11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Hide this time") {
                    bannerHiddenThisLoad = true
                }
                Button("Never show again") {
                    settings.hideCuratedLoadingBanner = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: AppTab.curated.systemImage,
            title: "Nothing curated yet",
            message: "Enable sources in Settings to see curated content here."
        )
    }

    // MARK: - Open entry

    /// Opens the HN thread for a curated entry.
    private func open(_ entry: CuratedEntry) async {
        guard let hnID = entry.hnItemID,
              let story = try? await HNAPIService.shared.item(id: hnID) else { return }
        selectedStory = story
    }
}

// MARK: - Source chip

/// Visual chip for the curated source filter row.
/// Pure visual — no Button, no action. Interaction is owned by the parent
/// container's DragGesture, matching the pattern in StoriesListView.
private struct CuratedSourceChip: View {
    let label: String
    let isSelected: Bool
    let chipID: String
    let namespace: Namespace.ID
    var mergeProgress: Double = 0

    var body: some View {
        Text(label)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? AppTheme.accent : Color.primary)
            .opacity(max(0, 1 - mergeProgress * 2))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.8 * (1 - mergeProgress)), lineWidth: 1.5)
                }
            }
            .glassEffect(in: Capsule())
            .glassEffectID(isSelected ? "activeChip" : chipID, in: namespace)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { CuratedView() }
}
