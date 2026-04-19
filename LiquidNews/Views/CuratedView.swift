// CuratedView.swift
// Chronological feed of curated articles from all enabled sources.
//
// Tap behaviour mirrors the main feed:
//   - Entries with an HN item ID → fetch full HNItem → open StoryDetailView
//     (which has the "Read Article" CTA inside, just like the main feed).
//   - JSON-only entries with no HN ID → open article directly in WebReaderView.

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
    @State private var webReaderURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @Environment(\.openURL) private var openURL
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

    var body: some View {
        Group {
            if viewModel.isLoadingInitial && viewModel.entries.isEmpty {
                curatedLoadingView
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
        // Fallback for JSON-only entries that have no HN thread — respects defaultLinkOpen
        .sheet(item: $webReaderURL) { item in
            NavigationStack {
                switch settings.defaultLinkOpen {
                case .reader:  ArticleReaderView(url: item.url)
                case .browser: WebReaderView(url: item.url)
                case .safari:  WebReaderView(url: item.url) // safari handled inline in open(_:)
                }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
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

    // MARK: - Entries list

    private var entriesList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if (viewModel.isLoadingInitial || viewModel.isRefreshing)
                    && !settings.hideCuratedLoadingBanner
                    && !bannerHiddenThisLoad {
                    refreshingBanner
                }

                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        Task { await open(entry) }
                    } label: {
                        CuratedEntryRowView(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Trigger next page when within 5 rows of the bottom of visible entries.
                    .onAppear {
                        if index >= filteredEntries.count - 5 {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 16)
                }

                if !viewModel.canLoadMore && !filteredEntries.isEmpty && !viewModel.isLoadingInitial {
                    Text("All caught up")
                        .font(AppTheme.captionFont(12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 24)
                }

                if filteredEntries.isEmpty && selectedSourceID != nil {
                    Text("No entries from this source")
                        .font(AppTheme.bodyFont(14))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 48)
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
                    .foregroundStyle(.white)
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

    // MARK: - Loading state

    private var curatedLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("Loading curated stories…")
                .font(AppTheme.bodyFont(15))
                .foregroundStyle(.white)
            Text("Parsing the newsletter may take\na moment on first load.")
                .font(AppTheme.captionFont(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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

    /// Opens the entry the same way the main feed does:
    /// HN thread first (StoryDetailView), article from within that view.
    /// Falls back to the user's preferred open mode for entries with no HN thread.
    private func open(_ entry: CuratedEntry) async {
        if let hnID = entry.hnItemID,
           let story = try? await HNAPIService.shared.item(id: hnID) {
            selectedStory = story
        } else if settings.defaultLinkOpen == .safari {
            openURL(entry.url)
        } else {
            webReaderURL = IdentifiableURL(entry.url)
        }
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
            .foregroundStyle(isSelected ? AppTheme.accent : Color.white)
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
