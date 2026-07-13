// AppTheme.swift
// Central definition of colors, gradients, and typography for the app.
//
// AppThemePreset defines the per-theme color palette.
// AppTheme provides static accessors that read the active preset from UserSettings,
// making all existing AppTheme.backgroundGradient / AppTheme.accent callsites
// automatically reactive via SwiftUI's @Observable observation tracking.

import SwiftUI
import UIKit

// MARK: - AppThemePreset

enum AppThemePreset: String, CaseIterable, Identifiable {
    case standard
    case classic
    case cosmic
    case forest
    case ember
    case midnight
    case catppuccin
    case dracula
    case gruvbox
    case solarized
    case nord
    case kanagawa
    case everforest
    case rosepine
    case onedark
    case monokai
    case synthwave

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Default"
        case .classic:  return "Classic"
        case .cosmic:   return "Cosmic"
        case .forest:   return "Forest"
        case .ember:    return "Ember"
        case .midnight:    return "Midnight"
        case .catppuccin:  return "Catppuccin"
        case .dracula:     return "Dracula"
        case .gruvbox:     return "Gruvbox"
        case .solarized:   return "Solarized"
        case .nord:        return "Nord"
        case .kanagawa:    return "Kanagawa"
        case .everforest:  return "Everforest"
        case .rosepine:    return "Rosé Pine"
        case .onedark:     return "One Dark"
        case .monokai:     return "Monokai"
        case .synthwave:   return "Synthwave"
        }
    }

    var isPremium: Bool { self != .standard && self != .classic }

    // MARK: Accent color

    var accent: Color {
        switch self {
        case .standard: return Color(red: 1.0,  green: 0.42, blue: 0.08)   // HN orange
        case .classic:  return Color(red: 1.0,  green: 0.40, blue: 0.00)   // #FF6600 exact YC orange
        case .cosmic:   return Color(red: 0.65, green: 0.45, blue: 1.0)   // soft purple
        case .forest:   return Color(red: 0.25, green: 0.85, blue: 0.45)  // green
        case .ember:    return Color(red: 1.0,  green: 0.30, blue: 0.25)   // red-orange
        case .midnight:    return Color(red: 0.40, green: 0.75, blue: 1.0)   // ice blue
        case .catppuccin:  return Color(red: 0.80, green: 0.65, blue: 0.97)  // Mocha Mauve #cba6f7
        case .dracula:     return Color(red: 0.74, green: 0.58, blue: 0.98)  // Purple #bd93f9
        case .gruvbox:     return Color(red: 1.00, green: 0.50, blue: 0.10)  // Bright Orange #fe8019
        case .solarized:   return Color(red: 0.15, green: 0.55, blue: 0.82)  // Blue #268bd2
        case .nord:        return Color(red: 0.53, green: 0.75, blue: 0.82)  // Frost Blue #88c0d0
        case .kanagawa:    return Color(red: 0.49, green: 0.61, blue: 0.85)  // crystalBlue #7E9CD8
        case .everforest:  return Color(red: 0.65, green: 0.75, blue: 0.50)  // green #A7C080
        case .rosepine:    return Color(red: 0.92, green: 0.44, blue: 0.57)  // love #eb6f92
        case .onedark:     return Color(red: 0.38, green: 0.69, blue: 0.94)  // blue #61afef
        case .monokai:     return Color(red: 0.98, green: 0.15, blue: 0.45)  // pink #f92672
        case .synthwave:   return Color(red: 1.00, green: 0.49, blue: 0.86)  // pink #ff7edb
        }
    }

    // MARK: Background gradient

    func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            switch self {
            case .standard:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.82, green: 0.91, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.75, green: 0.86, blue: 1.00), location: 0.5),
                        .init(color: Color(red: 0.68, green: 0.81, blue: 1.00), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .classic:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 0.93, blue: 0.78), location: 0.0),
                        .init(color: Color(red: 0.99, green: 0.87, blue: 0.68), location: 0.5),
                        .init(color: Color(red: 0.97, green: 0.81, blue: 0.58), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .cosmic:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.90, green: 0.82, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.83, green: 0.75, blue: 1.00), location: 0.5),
                        .init(color: Color(red: 0.76, green: 0.68, blue: 1.00), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .forest:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.80, green: 0.96, blue: 0.87), location: 0.0),
                        .init(color: Color(red: 0.72, green: 0.92, blue: 0.81), location: 0.5),
                        .init(color: Color(red: 0.65, green: 0.88, blue: 0.75), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .ember:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 0.88, blue: 0.80), location: 0.0),
                        .init(color: Color(red: 0.98, green: 0.82, blue: 0.72), location: 0.5),
                        .init(color: Color(red: 0.96, green: 0.76, blue: 0.65), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .midnight:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.83, green: 0.87, blue: 0.95), location: 0.0),
                        .init(color: Color(red: 0.77, green: 0.81, blue: 0.91), location: 0.5),
                        .init(color: Color(red: 0.71, green: 0.75, blue: 0.87), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .catppuccin:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.94, green: 0.91, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.88, green: 0.85, blue: 0.96), location: 0.5),
                        .init(color: Color(red: 0.82, green: 0.79, blue: 0.94), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .dracula:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.93, green: 0.91, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.88, green: 0.86, blue: 0.96), location: 0.5),
                        .init(color: Color(red: 0.83, green: 0.80, blue: 0.94), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .gruvbox:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.98, green: 0.95, blue: 0.78), location: 0.0),
                        .init(color: Color(red: 0.92, green: 0.86, blue: 0.70), location: 0.5),
                        .init(color: Color(red: 0.84, green: 0.77, blue: 0.63), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .solarized:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.99, green: 0.96, blue: 0.89), location: 0.0),
                        .init(color: Color(red: 0.93, green: 0.91, blue: 0.84), location: 0.5),
                        .init(color: Color(red: 0.88, green: 0.86, blue: 0.79), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .nord:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.93, green: 0.94, blue: 0.96), location: 0.0),
                        .init(color: Color(red: 0.90, green: 0.91, blue: 0.94), location: 0.5),
                        .init(color: Color(red: 0.85, green: 0.87, blue: 0.91), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .kanagawa:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.95, green: 0.93, blue: 0.74), location: 0.0),
                        .init(color: Color(red: 0.90, green: 0.87, blue: 0.69), location: 0.5),
                        .init(color: Color(red: 0.86, green: 0.84, blue: 0.67), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .everforest:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.95, green: 0.92, blue: 0.84), location: 0.0),
                        .init(color: Color(red: 0.89, green: 0.86, blue: 0.78), location: 0.5),
                        .init(color: Color(red: 0.84, green: 0.81, blue: 0.73), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .rosepine:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.98, green: 0.96, blue: 0.93), location: 0.0),
                        .init(color: Color(red: 0.95, green: 0.91, blue: 0.88), location: 0.5),
                        .init(color: Color(red: 0.92, green: 0.88, blue: 0.85), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .onedark:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.90, green: 0.92, blue: 0.96), location: 0.0),
                        .init(color: Color(red: 0.84, green: 0.87, blue: 0.93), location: 0.5),
                        .init(color: Color(red: 0.78, green: 0.82, blue: 0.90), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .monokai:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.97, green: 0.95, blue: 0.90), location: 0.0),
                        .init(color: Color(red: 0.91, green: 0.89, blue: 0.84), location: 0.5),
                        .init(color: Color(red: 0.86, green: 0.84, blue: 0.79), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .synthwave:
                return LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.93, green: 0.90, blue: 0.97), location: 0.0),
                        .init(color: Color(red: 0.87, green: 0.84, blue: 0.95), location: 0.5),
                        .init(color: Color(red: 0.81, green: 0.78, blue: 0.93), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        // Dark (unchanged from original)
        switch self {
        case .standard:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.06, green: 0.06, blue: 0.18), location: 0.0),
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.02, green: 0.02, blue: 0.07), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .classic:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.09, blue: 0.01), location: 0.0),
                    .init(color: Color(red: 0.10, green: 0.05, blue: 0.01), location: 0.5),
                    .init(color: Color(red: 0.05, green: 0.02, blue: 0.00), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .cosmic:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.10, green: 0.04, blue: 0.22), location: 0.0),
                    .init(color: Color(red: 0.07, green: 0.03, blue: 0.16), location: 0.5),
                    .init(color: Color(red: 0.03, green: 0.02, blue: 0.09), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .forest:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.03, green: 0.14, blue: 0.07), location: 0.0),
                    .init(color: Color(red: 0.02, green: 0.09, blue: 0.05), location: 0.5),
                    .init(color: Color(red: 0.01, green: 0.05, blue: 0.03), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ember:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.18, green: 0.05, blue: 0.03), location: 0.0),
                    .init(color: Color(red: 0.12, green: 0.03, blue: 0.02), location: 0.5),
                    .init(color: Color(red: 0.06, green: 0.02, blue: 0.01), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .midnight:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.00, green: 0.00, blue: 0.00), location: 0.0),
                    .init(color: Color(red: 0.00, green: 0.00, blue: 0.00), location: 0.5),
                    .init(color: Color(red: 0.00, green: 0.00, blue: 0.00), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .catppuccin:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.12, green: 0.12, blue: 0.18), location: 0.0),
                    .init(color: Color(red: 0.09, green: 0.09, blue: 0.15), location: 0.5),
                    .init(color: Color(red: 0.07, green: 0.07, blue: 0.11), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .dracula:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.16, blue: 0.21), location: 0.0),
                    .init(color: Color(red: 0.13, green: 0.13, blue: 0.17), location: 0.5),
                    .init(color: Color(red: 0.09, green: 0.10, blue: 0.13), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .gruvbox:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.20, green: 0.19, blue: 0.18), location: 0.0),
                    .init(color: Color(red: 0.16, green: 0.16, blue: 0.16), location: 0.5),
                    .init(color: Color(red: 0.11, green: 0.13, blue: 0.13), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .solarized:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.03, green: 0.21, blue: 0.26), location: 0.0),
                    .init(color: Color(red: 0.00, green: 0.17, blue: 0.21), location: 0.5),
                    .init(color: Color(red: 0.00, green: 0.12, blue: 0.16), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .nord:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.23, green: 0.26, blue: 0.32), location: 0.0),
                    .init(color: Color(red: 0.18, green: 0.20, blue: 0.25), location: 0.5),
                    .init(color: Color(red: 0.13, green: 0.15, blue: 0.19), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .kanagawa:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.16, blue: 0.22), location: 0.0),
                    .init(color: Color(red: 0.12, green: 0.12, blue: 0.16), location: 0.5),
                    .init(color: Color(red: 0.09, green: 0.09, blue: 0.13), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .everforest:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.18, green: 0.21, blue: 0.23), location: 0.0),
                    .init(color: Color(red: 0.14, green: 0.16, blue: 0.18), location: 0.5),
                    .init(color: Color(red: 0.10, green: 0.12, blue: 0.14), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .rosepine:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.15, green: 0.14, blue: 0.23), location: 0.0),
                    .init(color: Color(red: 0.12, green: 0.11, blue: 0.18), location: 0.5),
                    .init(color: Color(red: 0.10, green: 0.09, blue: 0.14), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .onedark:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.17, green: 0.19, blue: 0.24), location: 0.0),
                    .init(color: Color(red: 0.16, green: 0.17, blue: 0.20), location: 0.5),
                    .init(color: Color(red: 0.13, green: 0.15, blue: 0.17), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .monokai:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.18, green: 0.18, blue: 0.15), location: 0.0),
                    .init(color: Color(red: 0.15, green: 0.16, blue: 0.13), location: 0.5),
                    .init(color: Color(red: 0.12, green: 0.12, blue: 0.10), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .synthwave:
            return LinearGradient(
                stops: [
                    .init(color: Color(red: 0.18, green: 0.16, blue: 0.25), location: 0.0),
                    .init(color: Color(red: 0.15, green: 0.14, blue: 0.21), location: 0.5),
                    .init(color: Color(red: 0.10, green: 0.09, blue: 0.15), location: 1.0),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Swatch color (for the theme picker UI)

    var swatchColor: Color {
        switch self {
        case .standard: return Color(red: 0.06, green: 0.06, blue: 0.18)
        case .classic:  return Color(red: 0.16, green: 0.09, blue: 0.01)
        case .cosmic:   return Color(red: 0.10, green: 0.04, blue: 0.22)
        case .forest:   return Color(red: 0.03, green: 0.14, blue: 0.07)
        case .ember:    return Color(red: 0.18, green: 0.05, blue: 0.03)
        case .midnight:    return Color.black
        case .catppuccin:  return Color(red: 0.12, green: 0.12, blue: 0.18)  // Base
        case .dracula:     return Color(red: 0.16, green: 0.16, blue: 0.21)  // Background
        case .gruvbox:     return Color(red: 0.16, green: 0.16, blue: 0.16)  // bg
        case .solarized:   return Color(red: 0.00, green: 0.17, blue: 0.21)  // base03
        case .nord:        return Color(red: 0.18, green: 0.20, blue: 0.25)  // nord0
        case .kanagawa:    return Color(red: 0.12, green: 0.12, blue: 0.16)  // sumiInk3
        case .everforest:  return Color(red: 0.18, green: 0.21, blue: 0.23)  // bg0
        case .rosepine:    return Color(red: 0.10, green: 0.09, blue: 0.14)  // base
        case .onedark:     return Color(red: 0.16, green: 0.17, blue: 0.20)  // #282c34
        case .monokai:     return Color(red: 0.15, green: 0.16, blue: 0.13)  // #272822
        case .synthwave:   return Color(red: 0.15, green: 0.14, blue: 0.21)  // #262335
        }
    }

    // MARK: Glass tint (theme wash over custom backgrounds)

    /// Scheme-aware theme identity colour for tinting glass when a custom
    /// background hides the preset gradient. Dark reuses the swatch; light
    /// uses the light gradient's most saturated stop, because the dark
    /// swatches read as grey shadows over light glass.
    func glassTint(for scheme: ColorScheme) -> Color {
        scheme == .light ? lightGlassTint : swatchColor
    }

    /// Final stop (location 1.0) of the light `backgroundGradient` —
    /// literal duplication, matching how `swatchColor` duplicates the
    /// dark gradients' first stops.
    private var lightGlassTint: Color {
        switch self {
        case .standard:    return Color(red: 0.68, green: 0.81, blue: 1.00)
        case .classic:     return Color(red: 0.97, green: 0.81, blue: 0.58)
        case .cosmic:      return Color(red: 0.76, green: 0.68, blue: 1.00)
        case .forest:      return Color(red: 0.65, green: 0.88, blue: 0.75)
        case .ember:       return Color(red: 0.96, green: 0.76, blue: 0.65)
        case .midnight:    return Color(red: 0.71, green: 0.75, blue: 0.87)
        case .catppuccin:  return Color(red: 0.82, green: 0.79, blue: 0.94)
        case .dracula:     return Color(red: 0.83, green: 0.80, blue: 0.94)
        case .gruvbox:     return Color(red: 0.84, green: 0.77, blue: 0.63)
        case .solarized:   return Color(red: 0.88, green: 0.86, blue: 0.79)
        case .nord:        return Color(red: 0.85, green: 0.87, blue: 0.91)
        case .kanagawa:    return Color(red: 0.86, green: 0.84, blue: 0.67)
        case .everforest:  return Color(red: 0.84, green: 0.81, blue: 0.73)
        case .rosepine:    return Color(red: 0.92, green: 0.88, blue: 0.85)
        case .onedark:     return Color(red: 0.78, green: 0.82, blue: 0.90)
        case .monokai:     return Color(red: 0.86, green: 0.84, blue: 0.79)
        case .synthwave:   return Color(red: 0.81, green: 0.78, blue: 0.93)
        }
    }

    // MARK: Comment depth colors

    var commentColors: [Color] {
        switch self {
        case .standard:
            return [
                accent,                                       // orange
                Color(red: 0.2,  green: 0.8,  blue: 0.9),   // cyan
                Color(red: 0.7,  green: 0.4,  blue: 1.0),   // purple
                Color(red: 0.2,  green: 0.9,  blue: 0.6),   // green
                Color(red: 0.4,  green: 0.6,  blue: 1.0),   // blue
            ]
        case .classic:
            return [
                accent,  // HN orange
                accent,
                accent,
                accent,
                accent,
            ]
        case .cosmic:
            return [
                accent,                                       // soft purple
                Color(red: 0.9,  green: 0.35, blue: 0.75),  // pink/magenta
                Color(red: 0.35, green: 0.65, blue: 1.0),   // sky blue
                Color(red: 0.75, green: 0.55, blue: 1.0),   // lavender
                Color(red: 0.25, green: 0.8,  blue: 0.85),  // teal
            ]
        case .forest:
            return [
                accent,                                       // green
                Color(red: 0.15, green: 0.75, blue: 0.65),  // teal
                Color(red: 0.55, green: 0.9,  blue: 0.2),   // lime
                Color(red: 0.2,  green: 0.85, blue: 0.7),   // mint
                Color(red: 0.45, green: 0.8,  blue: 0.5),   // sage
            ]
        case .ember:
            return [
                accent,                                       // red-orange
                Color(red: 1.0,  green: 0.65, blue: 0.1),   // amber
                Color(red: 1.0,  green: 0.5,  blue: 0.35),  // coral
                Color(red: 0.85, green: 0.15, blue: 0.2),   // crimson
                Color(red: 0.95, green: 0.85, blue: 0.2),   // warm yellow
            ]
        case .midnight:
            return [
                accent,                                       // ice blue
                Color(red: 0.35, green: 0.55, blue: 0.85),  // steel blue
                Color(red: 0.2,  green: 0.85, blue: 1.0),   // cyan
                Color(red: 0.55, green: 0.6,  blue: 1.0),   // periwinkle
                Color(red: 0.65, green: 0.5,  blue: 0.95),  // lavender
            ]
        case .catppuccin:
            return [
                accent,                                        // Mauve
                Color(red: 0.96, green: 0.76, blue: 0.91),   // Pink #f5c2e7
                Color(red: 0.54, green: 0.71, blue: 0.98),   // Blue #89b4fa
                Color(red: 0.65, green: 0.89, blue: 0.63),   // Green #a6e3a1
                Color(red: 0.98, green: 0.70, blue: 0.53),   // Peach #fab387
            ]
        case .dracula:
            return [
                accent,                                        // Purple
                Color(red: 1.00, green: 0.47, blue: 0.78),   // Pink #ff79c6
                Color(red: 0.55, green: 0.91, blue: 0.99),   // Cyan #8be9fd
                Color(red: 0.31, green: 0.98, blue: 0.48),   // Green #50fa7b
                Color(red: 1.00, green: 0.72, blue: 0.42),   // Orange #ffb86c
            ]
        case .gruvbox:
            return [
                accent,                                        // Bright Orange
                Color(red: 0.98, green: 0.74, blue: 0.18),   // Bright Yellow #fabd2f
                Color(red: 0.72, green: 0.73, blue: 0.15),   // Bright Green #b8bb26
                Color(red: 0.56, green: 0.75, blue: 0.49),   // Bright Aqua #8ec07c
                Color(red: 0.51, green: 0.65, blue: 0.60),   // Bright Blue #83a598
            ]
        case .solarized:
            return [
                accent,                                        // Blue
                Color(red: 0.16, green: 0.63, blue: 0.60),   // Cyan #2aa198
                Color(red: 0.80, green: 0.29, blue: 0.09),   // Orange #cb4b16
                Color(red: 0.42, green: 0.44, blue: 0.77),   // Violet #6c71c4
                Color(red: 0.83, green: 0.21, blue: 0.51),   // Magenta #d33682
            ]
        case .nord:
            return [
                accent,                                        // Frost Blue nord8
                Color(red: 0.71, green: 0.56, blue: 0.68),   // Purple nord15 #b48ead
                Color(red: 0.56, green: 0.74, blue: 0.73),   // Teal nord7 #8fbcbb
                Color(red: 0.75, green: 0.38, blue: 0.42),   // Red nord11 #bf616a
                Color(red: 0.64, green: 0.75, blue: 0.55),   // Green nord14 #a3be8c
            ]
        case .kanagawa:
            return [
                accent,                                        // crystalBlue
                Color(red: 1.00, green: 0.63, blue: 0.40),   // surimiOrange #FFA066
                Color(red: 0.60, green: 0.73, blue: 0.42),   // springGreen #98BB6C
                Color(red: 0.82, green: 0.49, blue: 0.60),   // sakuraPink #D27E99
                Color(red: 0.90, green: 0.76, blue: 0.52),   // carpYellow #E6C384
            ]
        case .everforest:
            return [
                accent,                                        // green #A7C080
                Color(red: 0.51, green: 0.75, blue: 0.57),   // aqua #83C092
                Color(red: 0.50, green: 0.73, blue: 0.70),   // blue #7FBBB3
                Color(red: 0.86, green: 0.74, blue: 0.50),   // yellow #DBBC7F
                Color(red: 0.90, green: 0.60, blue: 0.46),   // orange #E69875
            ]
        case .rosepine:
            return [
                accent,                                        // love #eb6f92
                Color(red: 0.77, green: 0.65, blue: 0.91),   // iris #c4a7e7
                Color(red: 0.61, green: 0.81, blue: 0.85),   // foam #9ccfd8
                Color(red: 0.96, green: 0.76, blue: 0.47),   // gold #f6c177
                Color(red: 0.92, green: 0.74, blue: 0.73),   // rose #ebbcba
            ]
        case .onedark:
            return [
                accent,                                        // blue #61afef
                Color(red: 0.78, green: 0.47, blue: 0.87),   // purple #c678dd
                Color(red: 0.60, green: 0.76, blue: 0.47),   // green #98c379
                Color(red: 0.82, green: 0.60, blue: 0.40),   // orange #d19a66
                Color(red: 0.88, green: 0.42, blue: 0.46),   // red #e06c75
            ]
        case .monokai:
            return [
                accent,                                        // pink #f92672
                Color(red: 0.65, green: 0.89, blue: 0.18),   // green #a6e22e
                Color(red: 0.40, green: 0.85, blue: 0.94),   // cyan #66d9ef
                Color(red: 0.68, green: 0.51, blue: 1.00),   // purple #ae81ff
                Color(red: 0.99, green: 0.59, blue: 0.12),   // orange #fd971f
            ]
        case .synthwave:
            return [
                accent,                                        // pink #ff7edb
                Color(red: 0.01, green: 0.93, blue: 0.98),   // cyan #03edf9
                Color(red: 1.00, green: 0.87, blue: 0.36),   // yellow #fede5d
                Color(red: 0.45, green: 0.95, blue: 0.72),   // green #72f1b8
                Color(red: 0.62, green: 0.55, blue: 0.79),   // purple #9d8bca
            ]
        }
    }
}

// MARK: - Color hex helpers

extension Color {
    /// Parses a 6-character hex string (without #) into a Color. Returns nil if invalid.
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Converts to a 6-character lowercase hex string.
    func toHexString() -> String {
        let ui = UIColor(self)
        let srgb = ui.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ).map { UIColor(cgColor: $0) } ?? ui
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }
}

// MARK: - AppTheme

enum AppTheme {

    // MARK: Dynamic colors (read from active UserSettings preset)

    /// Active accent — custom hex override if set, otherwise the preset's accent.
    static var accent: Color {
        if let hex = UserSettings.shared.customAccentHex,
           let color = Color(hexString: hex) {
            return color
        }
        return UserSettings.shared.selectedAppTheme.accent
    }

    /// Subtle tint — always derived from the active accent.
    static var accentMuted: Color { accent.opacity(0.15) }

    /// Active background gradient for the given color scheme.
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        UserSettings.shared.selectedAppTheme.backgroundGradient(for: colorScheme)
    }

    // MARK: Static colors (unchanged across themes)

    /// Glass card border — adapts to light/dark.
    static let glassBorder = Color.primary.opacity(0.12)

    /// Dimmed text for secondary information — adapts to light/dark.
    static let secondaryText = Color.secondary

    /// Primary text color — adapts to light/dark.
    static let primaryText = Color.primary

    // MARK: Thread line colors

    static func threadColor(depth: Int) -> Color {
        let colors = UserSettings.shared.selectedAppTheme.commentColors
        return colors[abs(depth) % colors.count]
    }

    // MARK: Typography (unchanged)

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
