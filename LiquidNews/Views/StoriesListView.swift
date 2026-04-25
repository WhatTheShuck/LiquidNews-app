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
//
// Overflow chip design:
//   Up to 5 category chips are shown at once (the limit where all fit without
//   scrolling). When the user enables more than 5 categories, the 5th slot
//   becomes an "overflow" chip. It participates in the convergence animation
//   identically to the others — the GlassEffectContainer doesn't distinguish it.
//   Touching it triggers a confirmationDialog with the remaining categories.
//   When an overflow category is active, the overflow chip renders as "selected"
//   (accent border, morphed glass), preserving the full glassEffectID mechanic.

import SwiftUI

// MARK: - Preference key for chip centre measurement

private struct ChipCenterKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// The overflow slot in the chip row.
private enum PickerChip: Identifiable {
    case category(StoryCategory)
    case overflow

    var id: String {
        switch self {
        case .category(let c): c.id
        case .overflow:        "__overflow__"
        }
    }
}

struct StoriesListView: View {

    @State private var viewModel: StoriesViewModel
    @State private var settings = UserSettings.shared
    @State private var selectedStory: HNItem?
    @State private var webReaderURL: IdentifiableURL?
    @State private var webReaderInitialReaderMode = false
    @State private var safariURL: IdentifiableURL?
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingAccount = false
    @Environment(\.openURL) private var openURL
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

    // Maximum chips visible simultaneously. At 5 all labels fit comfortably on
    // an iPhone without the row needing to scroll — the constraint the merge
    // animation depends on.
    private let maxVisibleChips = 5

    init(viewModel: StoriesViewModel = StoriesViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Chip layout helpers

    /// All enabled categories in the user's preferred order.
    private var enabledCategories: [StoryCategory] { settings.orderedEnabledCategories }

    /// True when more categories are enabled than the row can show at once.
    private var hasOverflow: Bool { enabledCategories.count > maxVisibleChips }

    /// The "primary" chips (all if ≤ max, otherwise the first N-1 to leave room for overflow).
    private var mainCategories: [StoryCategory] {
        hasOverflow ? Array(enabledCategories.prefix(maxVisibleChips - 1)) : enabledCategories
    }

    /// Categories that live behind the overflow chip.
    private var overflowCategories: [StoryCategory] {
        hasOverflow ? Array(enabledCategories.dropFirst(maxVisibleChips - 1)) : []
    }

    /// All chips rendered in the row — main categories plus an overflow slot if needed.
    private var displayedChips: [PickerChip] {
        mainCategories.map(PickerChip.category) + (hasOverflow ? [.overflow] : [])
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stories.isEmpty {
                StoriesSkeletonView()
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
                        ForEach(enabledCategories) { category in
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
            await viewModel.load(category: enabledCategories.first ?? .top)
        }
        // If the selected category gets disabled in settings, switch to the first enabled one.
        .onChange(of: enabledCategories) { _, categories in
            if !categories.contains(viewModel.selectedCategory), let first = categories.first {
                Task { await viewModel.load(category: first) }
            }
        }
    }

    // MARK: - Category picker row (slides away on scroll)

    // All chips live in a single flat HStack inside a GlassEffectContainer, so
    // SwiftUI distributes equal width to every slot — including the overflow Menu.
    // The overflow chip is a Menu inline in the ForEach; because it sits at the
    // same level as the CategoryChips, `.frame(maxWidth: .infinity)` is applied
    // uniformly and every chip is identical in size.
    //
    // Gesture strategy: DragGesture(minimumDistance:0) on the HStack covers taps
    // and slides for main chips. For the overflow slot, selectNearest() returns
    // early — the Menu's own gesture handles that area with higher priority (child
    // gestures beat parent gestures in SwiftUI's recogniser tree).
    private var categoryPickerRow: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                ForEach(Array(displayedChips.enumerated()), id: \.element.id) { index, chip in
                    chipView(for: chip)
                        .frame(maxWidth: .infinity)
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ChipCenterKey.self,
                                    value: [index: geo.frame(in: .named("pickerRow")).midX]
                                )
                            }
                        }
                        .animation(.bouncy(duration: 0.4), value: viewModel.selectedCategory)
                        .offset(x: chipConvergenceOffset(for: index))
                        .zIndex(zIndex(for: index))
                }
            }
            .padding(.horizontal, 12)
            .coordinateSpace(.named("pickerRow"))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("pickerRow"))
                    .onChanged { value in selectNearest(to: value.location.x) }
                    .onEnded   { value in selectNearest(to: value.location.x) }
            )
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pickerRowWidth = $0 }
        .onPreferenceChange(ChipCenterKey.self) { chipCenters = $0 }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func chipView(for chip: PickerChip) -> some View {
        switch chip {
        case .category(let category):
            CategoryChip(
                category: category,
                isSelected: viewModel.selectedCategory == category,
                namespace: chipNamespace,
                mergeProgress: pickerProgress
            )
        case .overflow:
            Menu {
                ForEach(overflowCategories) { category in
                    Button {
                        guard category != viewModel.selectedCategory else { return }
                        viewModel.selectedCategory = category
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
                OverflowChip(
                    overflowCategories: overflowCategories,
                    selectedCategory: viewModel.selectedCategory,
                    namespace: chipNamespace,
                    mergeProgress: pickerProgress
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// zIndex: centre chips float on top, outer chips slide underneath during convergence.
    private func zIndex(for index: Int) -> Double {
        let n = displayedChips.count
        return Double(n - abs(index - n / 2)) * pickerProgress
    }

    /// Selects the category chip nearest to x. Returns early if x is over the overflow
    /// slot — the Menu's own gesture has higher priority and handles it directly.
    private func selectNearest(to x: CGFloat) {
        guard !chipCenters.isEmpty,
              let nearest = chipCenters.min(by: { abs($0.value - x) < abs($1.value - x) }) else { return }
        // Overflow slot — let the Menu handle it, don't interfere
        guard nearest.key < mainCategories.count else { return }
        let category = mainCategories[nearest.key]
        guard category != viewModel.selectedCategory else { return }
        viewModel.selectedCategory = category
        Task { await viewModel.load(category: category) }
    }

    /// X offset that slides chip `index` toward the row's horizontal centre.
    private func chipConvergenceOffset(for index: Int) -> CGFloat {
        guard let center = chipCenters[index], pickerRowWidth > 0 else {
            return CGFloat(displayedChips.count / 2 - index) * 90 * CGFloat(pickerProgress)
        }
        return (pickerRowWidth / 2 - center) * CGFloat(pickerProgress)
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

    private let store = SavedPostsStore.shared

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

    /// Stories with hidden posts filtered out — reactive because SavedPostsStore is @Observable.
    private var visibleStories: [HNItem] {
        viewModel.stories.filter { !store.isHidden($0.id) }
    }

    private var storiesList: some View {
        List {
            ForEach(Array(visibleStories.enumerated()), id: \.element.id) { index, story in
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
                    Button(role: .destructive) {
                        store.hide(story)
                    } label: {
                        Label("Hide Post", systemImage: "eye.slash")
                    }
                    Divider()
                    Button {
                        store.toggleFavourite(story.id)
                    } label: {
                        Label(
                            store.isFavourite(story.id) ? "Unfavourite" : "Favourite",
                            systemImage: store.isFavourite(story.id) ? "heart.slash" : "heart"
                        )
                    }
                    Button {
                        store.toggleReadLater(story.id)
                    } label: {
                        Label(
                            store.isReadLater(story.id) ? "Remove from Read Later" : "Read Later",
                            systemImage: store.isReadLater(story.id) ? "bookmark.slash" : "bookmark"
                        )
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                // Trigger next page when we're 5 items from the bottom
                .onAppear {
                    if index >= visibleStories.count - 5 {
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
        .refreshable {
            await viewModel.refresh()
        }
        // Drive pickerProgress directly from scroll offset — no withAnimation
        // wrapper so the transition speed exactly matches the user's finger.
        // Range: 0–64 pt maps to progress 0–1.
        // Clamping lives in the *transform* so SwiftUI's own deduplication
        // fires the action only when the rounded value actually changes —
        // once offset > 64, all further positions map to 1.0 and are skipped.
        .onScrollGeometryChange(for: Double.self) {
            Double(min(max($0.contentOffset.y / 64, 0), 1))
        } action: { _, new in
            pickerProgress = new
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
            .accessibilityLabel(category.rawValue)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Overflow chip

/// Occupies the last chip slot when more categories are enabled than fit on screen.
/// Visually identical to a CategoryChip, participating fully in the convergence
/// animation and glass merge. When an overflow category is active it renders as
/// "selected" so the glassEffectID morph still works correctly.
struct OverflowChip: View {
    let overflowCategories: [StoryCategory]
    let selectedCategory: StoryCategory
    let namespace: Namespace.ID
    var mergeProgress: Double = 0

    private var isActive: Bool { overflowCategories.contains(selectedCategory) }

    var body: some View {
        HStack(spacing: 3) {
            Text(isActive ? selectedCategory.rawValue : "More")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? AppTheme.accent : Color.white)
            // Chevron is always visible — when active it signals the chip is
            // still tappable to switch between overflow categories.
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(
                    isActive
                        ? AppTheme.accent.opacity(0.55)
                        : Color.white.opacity(0.55)
                )
        }
        .opacity(max(0, 1 - mergeProgress * 2))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .overlay {
            if isActive {
                Capsule()
                    .strokeBorder(AppTheme.accent.opacity(0.8 * (1 - mergeProgress)), lineWidth: 1.5)
            }
        }
        .glassEffect(in: Capsule())
        // Uses "activeChip" when selected so the glass morphs here just like any
        // other chip — the animation is unaware this is the overflow slot.
        .glassEffectID(isActive ? "activeChip" : "overflowChip", in: namespace)
    }
}

// MARK: - Supporting views

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
