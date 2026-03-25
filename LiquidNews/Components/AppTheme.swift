// AppTheme.swift
// Central definition of colors, gradients, and typography for the app.
// Keeping design tokens in one place makes it easy to tweak the look later.

import SwiftUI

enum AppTheme {

    // MARK: - Colors

    /// HackerNews brand orange
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.08)

    /// Subtle orange used for chips / metadata tints
    static let accentMuted = accent.opacity(0.15)

    /// Glass card border — barely visible white shimmer
    static let glassBorder = Color.white.opacity(0.14)

    /// Dimmed text for secondary information
    static let secondaryText = Color.white.opacity(0.55)

    // MARK: - Background gradient
    // A deep indigo-to-black gradient that makes glass elements pop.

    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.06, green: 0.06, blue: 0.18), location: 0.0),
            .init(color: Color(red: 0.04, green: 0.04, blue: 0.12), location: 0.5),
            .init(color: Color(red: 0.02, green: 0.02, blue: 0.07), location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Thread line colors
    // Used in comment threads to show nesting depth with a color progression.

    static let threadColors: [Color] = [
        accent,
        Color(red: 0.2, green: 0.8, blue: 0.9),   // cyan
        Color(red: 0.7, green: 0.4, blue: 1.0),   // purple
        Color(red: 0.2, green: 0.9, blue: 0.6),   // teal
        Color(red: 0.4, green: 0.6, blue: 1.0),   // indigo-blue
    ]

    static func threadColor(depth: Int) -> Color {
        threadColors[depth % threadColors.count]
    }

    // MARK: - Typography
    // Using SF Pro Rounded for a softer, modern feel.

    static func titleFont(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular)
    }

    static func captionFont(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}
