// SkeletonView.swift
// Skeleton loading placeholders that match the glass card layouts used
// in StoryRowView, CuratedEntryRowView, and CommentView.

import SwiftUI

// MARK: - Building block

/// A single placeholder shape that pulses between two opacities.
private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 7

    @State private var dim = true

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(dim ? 0.08 : 0.20))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dim = false
                }
            }
    }
}

// MARK: - Story row skeleton

/// Mirrors the layout of StoryRowView with animated placeholder blocks.
struct StoryRowSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Domain chip
            SkeletonBlock(width: 90, height: 20, cornerRadius: 10)

            // Title — two lines, second shorter
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 16)
                GeometryReader { geo in
                    SkeletonBlock(width: geo.size.width * 0.65, height: 16)
                }
                .frame(height: 16)
            }

            // Metadata row: score, comments, author · · · time
            HStack(spacing: 14) {
                SkeletonBlock(width: 46, height: 12)
                SkeletonBlock(width: 46, height: 12)
                SkeletonBlock(width: 54, height: 12)
                Spacer()
                SkeletonBlock(width: 40, height: 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .glassCard()
    }
}

// MARK: - Curated entry row skeleton

/// Mirrors the layout of CuratedEntryRowView with animated placeholder blocks.
struct CuratedEntrySkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Domain chip
            SkeletonBlock(width: 90, height: 20, cornerRadius: 10)

            // Title + subnote
            VStack(alignment: .leading, spacing: 4) {
                SkeletonBlock(height: 16)
                GeometryReader { geo in
                    SkeletonBlock(width: geo.size.width * 0.72, height: 16)
                }
                .frame(height: 16)
                GeometryReader { geo in
                    SkeletonBlock(width: geo.size.width * 0.45, height: 14)
                }
                .frame(height: 14)
            }

            // Metadata row
            HStack(spacing: 14) {
                SkeletonBlock(width: 46, height: 12)
                SkeletonBlock(width: 46, height: 12)
                SkeletonBlock(width: 80, height: 12)
                Spacer()
                SkeletonBlock(width: 36, height: 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard()
    }
}

// MARK: - List-level skeletons

/// Replaces LoadingView in story feeds (HN, Favourites, Read Later, Catch Up).
struct StoriesSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    StoryRowSkeletonView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }
}

/// Replaces the curated loading view in CuratedView.
struct CuratedSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { _ in
                    CuratedEntrySkeletonView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Related story row skeleton

/// Mirrors the layout of relatedStoryRow — used inside the "Also Discussed on HN" card.
struct RelatedRowSkeletonView: View {
    /// Show a second title line for visual variety.
    var twoLineTitle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            SkeletonBlock(height: 14)
            if twoLineTitle {
                GeometryReader { geo in
                    SkeletonBlock(width: geo.size.width * 0.60, height: 14)
                }
                .frame(height: 14)
            }
            // Meta: score, comments, author · · · time
            HStack(spacing: 12) {
                SkeletonBlock(width: 38, height: 11)
                SkeletonBlock(width: 38, height: 11)
                SkeletonBlock(width: 52, height: 11)
                Spacer()
                SkeletonBlock(width: 34, height: 11)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Comment skeleton

/// Mirrors a single comment card: author + time header, then body lines.
/// lineCount varies per row so the skeleton looks like real varied comments.
struct CommentSkeletonView: View {
    var lineCount: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header: author · · · time + chevron
            HStack {
                SkeletonBlock(width: 72, height: 12)
                Spacer()
                SkeletonBlock(width: 40, height: 11)
            }

            // Body lines
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<lineCount, id: \.self) { i in
                    if i == lineCount - 1 {
                        // Last line is shorter to look like a natural text wrap
                        GeometryReader { geo in
                            SkeletonBlock(width: geo.size.width * 0.68, height: 13)
                        }
                        .frame(height: 13)
                    } else {
                        SkeletonBlock(height: 13)
                    }
                }
            }
        }
        .padding(14)
        .glassCard()
    }
}

/// A series of comment skeletons with varied body lengths — replaces the
/// comments-loading spinner in StoryDetailView.
struct CommentsSkeletonView: View {
    // Vary line counts to mimic real comment thread density
    private let lineCounts = [2, 3, 2, 4, 2, 3, 2]

    var body: some View {
        ForEach(Array(lineCounts.enumerated()), id: \.offset) { _, count in
            CommentSkeletonView(lineCount: count)
        }
    }
}

// MARK: - Previews

#Preview("Story skeleton") {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        StoriesSkeletonView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Curated skeleton") {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        CuratedSkeletonView()
    }
    .preferredColorScheme(.dark)
}
