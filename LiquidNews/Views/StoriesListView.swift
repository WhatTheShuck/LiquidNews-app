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
    // Namespace shared across all chips so glassEffectID can morph the active
    // glass capsule between chips when the selection changes.
    @Namespace private var chipNamespace

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

    // Chips fill the full screen width equally (no ScrollView needed with 5 chips).
    // All chips live inside a GlassEffectContainer so:
    //   1. Each chip's glass capsule morphs to the adjacent chip when selection changes
    //      (via glassEffectID — the same mechanism Apple's tab bar uses).
    //   2. All capsules merge together liquidly as they converge on scroll.
    // The selected chip also floats upward as it converges, making it appear to
    // travel into the toolbar's category menu button.
    // Chips fill the full screen width equally. All chips live inside a
    // GlassEffectContainer so their glass capsules morph between positions
    // when selection changes (glassEffectID mechanism), and merge together
    // liquidly when the picker scrolls away.
    //
    // Interaction is handled by a single DragGesture(minimumDistance:0) on the
    // HStack — this covers both taps (zero travel) and slides (finger moves
    // between chips), exactly like Apple's own tab bar. Individual per-chip
    // Buttons are intentionally absent: Button + .glassEffect(.interactive())
    // compete for the same touch and produce unreliable firing.
    private var categoryPickerRow: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element.id) {
                    index, category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategory == category,
                        namespace: chipNamespace,
                        mergeProgress: pickerProgress
                    )
                    .frame(maxWidth: .infinity)
                    // Measure each chip's natural centre X before any offset is applied.
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ChipCenterKey.self,
                                value: [index: geo.frame(in: .named("pickerRow")).midX]
                            )
                        }
                    }
                    // Animate glass morph and highlight when selection changes.
                    .animation(.bouncy(duration: 0.4), value: viewModel.selectedCategory)
                    // Slide chips toward screen centre on scroll.
                    .offset(x: chipConvergenceOffset(for: index))
                    // Centre chip stays on top; outer chips slide underneath.
                    .zIndex(Double(StoryCategory.allCases.count - abs(index - 2)) * pickerProgress)
                }
            }
            .padding(.horizontal, 12)
            .coordinateSpace(.named("pickerRow"))
            .contentShape(Rectangle())
            // Single gesture covers both taps (minimumDistance:0 fires on lift)
            // and slides (onChanged fires as finger crosses chip boundaries).
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("pickerRow"))
                    .onChanged { value in
                        selectNearest(to: value.location.x)
                    }
                    .onEnded { value in
                        selectNearest(to: value.location.x)
                    }
            )
        }
        // Capture visible row width for convergence target calculation.
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            pickerRowWidth = $0
        }
        .onPreferenceChange(ChipCenterKey.self) { chipCenters = $0 }
        .padding(.vertical, 10)
    }

    /// Selects the chip whose measured centre is nearest to x (pickerRow space).
    /// Setting selectedCategory synchronously here guarantees the @Observable
    /// change fires in the current render pass, so .animation picks it up.
    private func selectNearest(to x: CGFloat) {
        guard !chipCenters.isEmpty,
              let nearest = chipCenters.min(by: { abs($0.value - x) < abs($1.value - x) }),
              nearest.key < StoryCategory.allCases.count else { return }
        let category = StoryCategory.allCases[nearest.key]
        guard category != viewModel.selectedCategory else { return }
        viewModel.selectedCategory = category
        Task { await viewModel.load(category: category) }
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
                // Higher bounce (0.4) gives the glass merge its liquid snap feel.
                withAnimation(.spring(duration: 0.42, bounce: 0.4)) {
                    pickerProgress = pickerProgress > 0.5 ? 1 : 0
                }
            }
        }
    }
}

// MARK: - Category Picker

// CategoryPicker is a standalone scrollable version used outside StoriesListView.
// It owns its namespace and gesture — same single-gesture pattern as the main row.
struct CategoryPicker: View {
    let selected: StoryCategory
    let onSelect: (StoryCategory) -> Void
    @Namespace private var ns
    @State private var centers: [Int: CGFloat] = [:]

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    CategoryChip(
                        category: category,
                        isSelected: selected == category,
                        namespace: ns
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ChipCenterKey.self,
                                value: [index: geo.frame(in: .named("cpRow")).midX]
                            )
                        }
                    }
                    .animation(.bouncy(duration: 0.4), value: selected)
                }
            }
            .padding(.horizontal, 12)
            .coordinateSpace(.named("cpRow"))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cpRow"))
                    .onChanged { v in selectNearest(to: v.location.x) }
                    .onEnded   { v in selectNearest(to: v.location.x) }
            )
        }
        .onPreferenceChange(ChipCenterKey.self) { centers = $0 }
    }

    private func selectNearest(to x: CGFloat) {
        guard !centers.isEmpty,
              let nearest = centers.min(by: { abs($0.value - x) < abs($1.value - x) }),
              nearest.key < StoryCategory.allCases.count else { return }
        onSelect(StoryCategory.allCases[nearest.key])
    }
}

// Pure visual chip — no Button, no action. Interaction is owned by the parent
// container's DragGesture so there is no gesture conflict with the glass effect.
struct CategoryChip: View {
    let category: StoryCategory
    let isSelected: Bool
    /// Shared namespace so glassEffectID can morph the active capsule between chips.
    let namespace: Namespace.ID
    /// 0 = normal; 1 = fully converged. Non-selected labels fade during merge.
    var mergeProgress: Double = 0

    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? AppTheme.accent : Color.white)
            // All chips fade identically during convergence — selected included.
            // This leaves uniform plain-glass capsules for GlassEffectContainer
            // to blend, rather than one visually distinct chip resisting the merge.
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
            .glassEffectID(isSelected ? "activeChip" : category.rawValue, in: namespace)
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
