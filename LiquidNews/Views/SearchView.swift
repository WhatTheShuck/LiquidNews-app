// SearchView.swift
// HN search sheet powered by Algolia's public API.
// Presented from the magnifying glass toolbar button in StoriesListView.
//
// UX decisions:
//   Auto-search with 400 ms debounce — results update as the user types.
//   Date filter chips persist the last choice across launches via UserDefaults.
//   The custom range option reveals a DatePicker inline beneath the chips.

import SwiftUI

private let kLastFilterKey = "hn_search_date_filter"

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedStory: HNItem?
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                searchHeader
                filterRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                if viewModel.dateFilter == .custom {
                    customDatePicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                resultsArea
            }
        }
        .animation(.spring(duration: 0.25), value: viewModel.dateFilter)
        .onAppear {
            // Restore last filter, default to week
            if let saved = UserDefaults.standard.string(forKey: kLastFilterKey),
               let filter = SearchDateFilter(rawValue: saved) {
                viewModel.dateFilter = filter
            }
            // Small delay so the sheet finishes animating before keyboard pops up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                fieldFocused = true
            }
        }
        .onChange(of: viewModel.dateFilter) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: kLastFilterKey)
            if !viewModel.query.isEmpty { Task { await viewModel.search() } }
        }
        .onChange(of: viewModel.customSince) { _, _ in
            if viewModel.dateFilter == .custom && !viewModel.query.isEmpty {
                Task { await viewModel.search() }
            }
        }
        // Auto-search with debounce — SwiftUI cancels the previous task on each change
        .task(id: viewModel.query) {
            if viewModel.query.isEmpty { viewModel.results = []; return }
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled { await viewModel.search() }
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack { StoryDetailView(story: story) }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - Search header

    private var searchHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search Hacker News…", text: $viewModel.query)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($fieldFocused)
                    .onSubmit { Task { await viewModel.search() } }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("Cancel") { dismiss() }
                .foregroundStyle(AppTheme.accent)
                .fontWeight(.medium)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Date filter chips

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchDateFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: SearchDateFilter) -> some View {
        let isSelected = viewModel.dateFilter == filter
        return Button { viewModel.dateFilter = filter } label: {
            Text(filter.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? AppTheme.accent : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
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

    // MARK: - Custom date picker

    private var customDatePicker: some View {
        HStack {
            Text("Since")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                "",
                selection: $viewModel.customSince,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Results area

    @ViewBuilder
    private var resultsArea: some View {
        if viewModel.query.isEmpty {
            emptyPrompt(icon: "magnifyingglass", message: "Search for stories, topics, or domains")
        } else if viewModel.isSearching {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            emptyPrompt(icon: "wifi.exclamationmark", message: error)
        } else if viewModel.results.isEmpty {
            emptyPrompt(icon: "doc.text.magnifyingglass", message: "No results for \"\(viewModel.query)\"")
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, story in
                        Button { selectedStory = story } label: {
                            StoryRowView(story: story, rank: index + 1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func emptyPrompt(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(message)
                .font(AppTheme.bodyFont(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
