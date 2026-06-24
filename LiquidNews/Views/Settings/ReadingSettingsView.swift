// ReadingSettingsView.swift
// How links open across the app, plus Reader options.

import SwiftUI

struct ReadingSettingsView: View {

    @State private var settings = UserSettings.shared

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        SettingsDetailScaffold(title: "Reading") {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: settings.defaultLinkOpen.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default open mode")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(settings.defaultLinkOpen.subtitle)
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    segmentedPicker(
                        options: LinkOpenMode.allCases,
                        selection: settings.defaultLinkOpen
                    ) { settings.defaultLinkOpen = $0 }
                }

                // iPad reader layout (regular width only)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                    HStack(spacing: 12) {
                        Image(systemName: settings.iPadReaderLayout.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reader layout")
                                .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(settings.iPadReaderLayout.subtitle)
                                .font(.system(size: subtitleFontSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    segmentedPicker(
                        options: IPadReaderLayout.allCases,
                        selection: settings.iPadReaderLayout
                    ) { settings.iPadReaderLayout = $0 }
                }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Comment link mode
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Links in comments")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(settings.commentLinkOpen.subtitle)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                segmentedPicker(
                    options: CommentLinkMode.allCases,
                    selection: settings.commentLinkOpen
                ) { settings.commentLinkOpen = $0 }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Reader link mode
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Links in reader")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(settings.readerLinkOpen.subtitle)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                segmentedPicker(
                    options: ReaderLinkMode.allCases,
                    selection: settings.readerLinkOpen
                ) { settings.readerLinkOpen = $0 }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // HN Thread Links
                HStack(spacing: 12) {
                    Image(systemName: settings.hnThreadLinkOpen.systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HN Thread Links")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(settings.hnThreadLinkOpen.subtitle)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                segmentedPicker(
                    options: HNLinkMode.allCases,
                    selection: settings.hnThreadLinkOpen
                ) { settings.hnThreadLinkOpen = $0 }

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Reader images default
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show images in Reader")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Fetch and display images when opening articles in Reader mode")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.readerShowImagesByDefault)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Safari Reader Mode
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safari Reader Mode")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Auto-enter Reader Mode when opening articles in In-App Safari")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.safariReaderMode)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder).padding(.leading, 58)

                // Words of Wisdom
                HStack(spacing: 12) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Words of Wisdom")
                            .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Show a goofy quote while articles load")
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.wordsOfWisdom)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(16)
            }
            .glassCard()
        }
    }

    /// Segmented row of icon+label buttons matching the app's settings style.
    @ViewBuilder
    private func segmentedPicker<Mode>(
        options: [Mode],
        selection: Mode,
        onSelect: @escaping (Mode) -> Void
    ) -> some View where Mode: Equatable, Mode: SettingsSegmentOption {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, mode in
                Button {
                    onSelect(mode)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selection == mode ? AppTheme.accent.opacity(0.2) : Color.clear
                    )
                    .foregroundStyle(
                        selection == mode ? AppTheme.accent : Color.secondary
                    )
                }
                .buttonStyle(.plain)

                if index != options.count - 1 {
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
}

#Preview {
    NavigationStack { ReadingSettingsView() }
}
