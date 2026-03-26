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

// MARK: - Preference key for chip centre measurement

private struct ChipCenterKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

struct StoriesListView: View {

    @State private var viewModel: StoriesViewModel
    @State private var selectedStory: HNItem?
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingAccount = false
    // 0 = picker fully visible, 1 = picker fully hidden.
    // Driven directly from scroll offset so the animation tracks finger speed.
    // Snapped to 0 or 1 with a spring once scrolling stops.
    @State private var pickerProgress: Double = 0
    // Measured chip centres (in the picker row's coordinate space) and row width,
    // used to converge chips toward the true horizontal centre of the screen.
    @State private var chipCenters: [Int: CGFloat] = [:]
    @State private var pickerRowWidth: CGFloat = 0

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
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // ── Principal: "LiquidNews" title fades/scales out as the category
            // picker slides away, replaced by a compact category menu so the
            // user can still switch feeds while scrolled down.
            ToolbarItem(placement: .principal) {
                // Title exits in the first half of the range (progress 0→0.5),
                // category menu enters in the second half (0.5→1). This creates
                // a staggered crossfade that tracks scroll speed directly.
                ZStack {
                    Text("LiquidNews")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(max(0, 1 - pickerProgress * 2))
                        .scaleEffect(1 - pickerProgress * 0.25)

                    Menu {
                        ForEach(StoryCategory.allCases) { category in
                            Button {
                                Task { await viewModel.load(category: category) }
                            } label: {
                                if viewModel.selectedCategory == category {
                                    Label(category.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(category.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.selectedCategory.systemImage)
                                .font(.system(size: 17, weight: .semibold))
                            Text(viewModel.selectedCategory.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(in: Capsule())
                    }
                    .opacity(max(0, pickerProgress * 2 - 1))
                    .scaleEffect(0.75 + pickerProgress * 0.25)
                }
            }

            // ── Trailing: search + overflow (always present) ──
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    settingsActionMenu
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        // safeAreaInset gives a fixed layout slot. All transforms are visual-only.
        .safeAreaInset(edge: .top, spacing: 0) {
            categoryPickerRow
                .opacity(1 - pickerProgress * 1.6)
                .offset(y: -pickerProgress * 24)
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
        .sheet(isPresented: $showingSettings) {
            SettingsListView()
        }
        .sheet(isPresented: $showingAccount) {
            NavigationStack { AccountView() }
        }
        .task {
            await viewModel.load(category: .top)
        }
    }

    // MARK: - Category picker row (slides away on scroll)

    // Uses a ScrollView for normal interaction but disables scroll + clip during
    // the convergence animation so chips can physically overlap each other.
    private var categoryPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element.id) {
                    index, category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategory == category,
                        action: { Task { await viewModel.load(category: category) } }
                    )
                    // Measure each chip's natural centre X in the HStack coordinate
                    // space before any offset is applied.
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ChipCenterKey.self,
                                value: [index: geo.frame(in: .named("pickerRow")).midX]
                            )
                        }
                    }
                    // Slide each chip toward the screen's horizontal centre.
                    // At progress=0 offset is 0; at progress=1 all chips are stacked.
                    .offset(x: chipConvergenceOffset(for: index))
                    // Centre chip stays on top; outer chips slide underneath.
                    .zIndex(Double(StoryCategory.allCases.count - abs(index - 2)) * pickerProgress)
                }
            }
            .padding(.horizontal, 16)
            .coordinateSpace(.named("pickerRow"))
        }
        // Capture the visible row width (= screen width) for the convergence target.
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            pickerRowWidth = $0
        }
        .onPreferenceChange(ChipCenterKey.self) { chipCenters = $0 }
        // Allow chips to visually leave the scroll bounds once converging.
        .scrollClipDisabled(pickerProgress > 0)
        // Freeze scroll position while animating so offsets are consistent.
        .scrollDisabled(pickerProgress > 0.05)
        .padding(.vertical, 10)
    }

    /// Returns the x offset that moves chip at `index` toward the true horizontal
    /// centre of the row (= screen centre). Falls back to an index-based estimate
    /// until the first geometry pass completes.
    private func chipConvergenceOffset(for index: Int) -> CGFloat {
        guard let center = chipCenters[index], pickerRowWidth > 0 else {
            let fallbackCentre = StoryCategory.allCases.count / 2
            return CGFloat(fallbackCentre - index) * 90 * CGFloat(pickerProgress)
        }
        // target is the midpoint of the visible row (= centre of the screen)
        let target = pickerRowWidth / 2
        return (target - center) * CGFloat(pickerProgress)
    }

    // MARK: - Settings menu content

    @ViewBuilder
    private var settingsActionMenu: some View {
        Section {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                showingAccount = true
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
        // Drive pickerProgress directly from scroll offset — no withAnimation
        // wrapper so the transition speed exactly matches the user's finger.
        // Range: 0–64 pt maps to progress 0–1.
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y
        } action: { _, new in
            pickerProgress = Double(min(max(new / 64, 0), 1))
        }
        // Once the user's finger is fully off and inertia has settled, snap
        // to whichever end state is closest using a springy finish.
        .onScrollPhaseChange { _, new in
            if new == .idle {
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                    pickerProgress = pickerProgress > 0.5 ? 1 : 0
                }
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
