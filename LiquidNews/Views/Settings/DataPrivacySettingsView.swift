// DataPrivacySettingsView.swift
// Hidden posts, read behaviour, history, and import/export of saved data.

import SwiftUI
import UniformTypeIdentifiers

struct DataPrivacySettingsView: View {

    private let store = SavedPostsStore.shared
    @State private var settings = UserSettings.shared

    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingExportOptions = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var showingImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var showingClearHistoryConfirm = false
    @State private var navigateToHiddenPosts = false
    @State private var showingPasteFavourites = false
    @State private var pastedFavouritesText = ""
    @State private var pasteImportMode: ImportMode = .merge
    @State private var pasteImportError: String?
    @State private var showingPasteReplaceConfirm = false
    @State private var showingImportSuccess = false
    @State private var importSuccessMessage = ""

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    private enum ImportMode { case merge, replace }

    var body: some View {
        SettingsDetailScaffold(title: "Data & Privacy") {
            VStack(spacing: 0) {

                // Hidden posts
                Button {
                    navigateToHiddenPosts = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hidden Posts")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("\(store.hiddenPosts.count) hidden")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Hidden posts auto-expiry
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-clear hidden posts")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("HN posts age quickly — auto-expiry keeps the list lean")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.hiddenPostsExpiry) {
                        ForEach(HiddenPostsExpiry.allCases) { expiry in
                            Text(expiry.label).tag(expiry)
                        }
                    }
                    .labelsHidden()
                    .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Viewed post behaviour
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: settings.readBehaviour.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("When you view a post")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(settings.readBehaviour.subtitle)
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 0) {
                        ForEach(ReadBehaviour.allCases) { behaviour in
                            Button {
                                settings.readBehaviour = behaviour
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: behaviour.systemImage)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(behaviour.label)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    settings.readBehaviour == behaviour
                                        ? AppTheme.accent.opacity(0.2)
                                        : Color.clear
                                )
                                .foregroundStyle(
                                    settings.readBehaviour == behaviour
                                        ? AppTheme.accent
                                        : Color.secondary
                                )
                            }
                            .buttonStyle(.plain)

                            if behaviour != ReadBehaviour.allCases.last {
                                Divider()
                                    .frame(height: 32)
                                    .overlay(AppTheme.glassBorder)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Note: Hide mode never auto-hides favourited or read later posts
                if settings.readBehaviour == .hide {
                    Text("Favourited and read later posts are never auto-hidden.")
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Clear read history
                Button(role: .destructive) {
                    showingClearHistoryConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 18))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Read History")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.red.opacity(0.8))
                            Text("\(store.readHistory.count) entries")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Export
                Button {
                    showingExportOptions = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Data")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Share favourites, read later, history, or everything")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Export Data", isPresented: $showingExportOptions, titleVisibility: .visible
                ) {
                    Button("All Data — JSON file") {
                        triggerExport(data: try? store.exportData(), name: "liquidnews-all")
                    }
                    Button("Favourites — Copy \(store.favouriteIDs.count) IDs to clipboard") {
                        UIPasteboard.general.string = store.favouriteIDs.sorted()
                            .map(String.init).joined(separator: "\n")
                    }
                    Button("Favourites — JSON file") {
                        triggerExport(
                            data: try? store.exportFavourites(), name: "liquidnews-favourites")
                    }
                    Button("Favourites — Copy compact [\(store.favouriteIDs.count) IDs]") {
                        UIPasteboard.general.string = store.exportFavouritesCompact()
                    }
                    Button("Read Later — Copy \(store.readLaterIDs.count) IDs to clipboard") {
                        UIPasteboard.general.string = store.readLaterIDs.sorted()
                            .map(String.init).joined(separator: "\n")
                    }
                    Button("Read Later — JSON file") {
                        triggerExport(data: try? store.exportReadLater(), name: "liquidnews-read-later")
                    }
                    Button("Read History — JSON file") {
                        triggerExport(data: try? store.exportHistory(), name: "liquidnews-history")
                    }
                    Button("Hidden Posts — JSON file") {
                        triggerExport(data: try? store.exportHidden(), name: "liquidnews-hidden")
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("IDs are copied one per line or as a compact array. JSON files can be re-imported later.")
                }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Import
                Button {
                    showingImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Data")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Restore from a previous export")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                Button {
                    pastedFavouritesText = ""
                    pasteImportError = nil
                    pasteImportMode = .merge
                    showingPasteFavourites = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paste Favourites IDs")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Import a compact [id,id,id] list")
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
            .glassCard()
        }
        .navigationDestination(isPresented: $navigateToHiddenPosts) {
            HiddenPostsView()
        }
        // Export share sheet
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        // Import file picker
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            // Coordinate access — file may be outside sandbox
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                importError = "Could not read the selected file."
                showingImportError = true
                return
            }
            pendingImportData = data
            showingImportConfirm = true
        }
        .confirmationDialog(
            "Import Data",
            isPresented: $showingImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Merge with existing data") {
                if let data = pendingImportData {
                    let prevFavs = store.favouriteIDs.count
                    let prevRL = store.readLaterIDs.count
                    let prevHist = store.readHistory.count
                    try? store.importData(data, replacing: false)
                    importSuccessMessage = fileImportSummary(
                        favs: store.favouriteIDs.count - prevFavs,
                        rl: store.readLaterIDs.count - prevRL,
                        hist: store.readHistory.count - prevHist,
                        replacing: false
                    )
                    showingImportSuccess = true
                }
            }
            Button("Replace all data", role: .destructive) {
                if let data = pendingImportData {
                    try? store.importData(data, replacing: true)
                    importSuccessMessage = fileImportSummary(
                        favs: store.favouriteIDs.count,
                        rl: store.readLaterIDs.count,
                        hist: store.readHistory.count,
                        replacing: true
                    )
                    showingImportSuccess = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Merge keeps your existing favourites, read later posts, and history. Replace will overwrite everything with the imported data."
            )
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error.")
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importSuccessMessage)
        }
        .confirmationDialog(
            "Clear all read history?",
            isPresented: $showingClearHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingPasteFavourites, onDismiss: {
            pastedFavouritesText = ""
            pasteImportError = nil
            pasteImportMode = .merge
        }) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Mode", selection: $pasteImportMode) {
                        Text("Merge").tag(ImportMode.merge)
                        Text("Replace").tag(ImportMode.replace)
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $pastedFavouritesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                        )

                    if let err = pasteImportError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("Paste a compact list like [37140159,37158317] or bare IDs separated by commas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("Paste Favourites IDs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingPasteFavourites = false
                            pastedFavouritesText = ""
                            pasteImportError = nil
                            pasteImportMode = .merge
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            if pasteImportMode == .replace {
                                // Validate first so we don't show confirm for empty input
                                guard (try? SavedPostsStore.parseIDs(from: pastedFavouritesText)) != nil else {
                                    pasteImportError = FavouritesImportError.noValidIDs.localizedDescription
                                    return
                                }
                                showingPasteReplaceConfirm = true
                            } else {
                                do {
                                    let prevCount = store.favouriteIDs.count
                                    try store.importFavourites(from: pastedFavouritesText, replacing: false)
                                    let added = store.favouriteIDs.count - prevCount
                                    importSuccessMessage = added == 0
                                        ? "All IDs were already in your favourites."
                                        : "Added \(added) favourite\(added == 1 ? "" : "s")."
                                    showingPasteFavourites = false
                                    showingImportSuccess = true
                                } catch {
                                    pasteImportError = error.localizedDescription
                                }
                            }
                        }
                    }
                }
                .confirmationDialog(
                    "Replace Favourites",
                    isPresented: $showingPasteReplaceConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Replace", role: .destructive) {
                        do {
                            try store.importFavourites(from: pastedFavouritesText, replacing: true)
                            let count = store.favouriteIDs.count
                            importSuccessMessage = "Replaced favourites with \(count) ID\(count == 1 ? "" : "s")."
                            showingPasteFavourites = false
                            showingImportSuccess = true
                        } catch {
                            pasteImportError = error.localizedDescription
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will replace all your current favourites with the imported IDs. This cannot be undone.")
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
    }

    // MARK: - Import / Export helpers

    private func fileImportSummary(favs: Int, rl: Int, hist: Int, replacing: Bool) -> String {
        if replacing {
            return "\(favs) favourite\(favs == 1 ? "" : "s"), \(rl) read later, \(hist) history entr\(hist == 1 ? "y" : "ies") imported."
        }
        var parts: [String] = []
        if favs > 0 { parts.append("\(favs) favourite\(favs == 1 ? "" : "s")") }
        if rl > 0 { parts.append("\(rl) read later") }
        if hist > 0 { parts.append("\(hist) history entr\(hist == 1 ? "y" : "ies")") }
        return parts.isEmpty ? "Nothing new to import — all data already up to date." : "Added " + parts.joined(separator: ", ") + "."
    }

    private func triggerExport(data: Data?, name: String) {
        guard let data else {
            importError = "Failed to prepare export data."
            showingImportError = true
            return
        }
        let dateTag = Date().formatted(.iso8601.year().month().day())
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(dateTag).json")
        do {
            try data.write(to: tmp, options: .atomic)
            exportURL = tmp
            showingExportSheet = true
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

#Preview {
    NavigationStack { DataPrivacySettingsView() }
}
