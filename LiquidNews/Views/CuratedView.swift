// CuratedView.swift
// Chronological feed of curated articles from all enabled sources.
//
// Tap behaviour mirrors the main feed:
//   - Entries with an HN item ID → fetch full HNItem → open StoryDetailView
//     (which has the "Read Article" CTA inside, just like the main feed).
//   - JSON-only entries with no HN ID → open article directly in WebReaderView.

import SwiftUI

struct CuratedView: View {

    @State private var viewModel = CuratedViewModel()
    @State private var selectedStory: HNItem?
    @State private var webReaderURL: IdentifiableURL?
    @State private var settings = UserSettings.shared
    @Environment(\.openURL) private var openURL
    /// True when the user has dismissed the banner for the current load cycle only.
    @State private var bannerHiddenThisLoad = false

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

    // MARK: - Entries list

    private var entriesList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if (viewModel.isLoadingInitial || viewModel.isRefreshing)
                    && !settings.hideCuratedLoadingBanner
                    && !bannerHiddenThisLoad {
                    refreshingBanner
                }

                ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        Task { await open(entry) }
                    } label: {
                        CuratedEntryRowView(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Trigger next newsletter page when within 5 rows of the bottom.
                    .onAppear {
                        if index >= viewModel.entries.count - 5 {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 16)
                }

                if !viewModel.canLoadMore && !viewModel.entries.isEmpty && !viewModel.isLoadingInitial {
                    Text("All caught up")
                        .font(AppTheme.captionFont(12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 24)
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
        VStack(spacing: 14) {
            Image(systemName: AppTab.curated.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
            Text("Nothing curated yet")
                .font(AppTheme.titleFont(22))
                .foregroundStyle(.white)
            Text("Enable sources in Settings\nto see curated content here.")
                .font(AppTheme.bodyFont(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
