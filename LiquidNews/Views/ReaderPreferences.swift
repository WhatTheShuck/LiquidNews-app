// ReaderPreferences.swift
// Reader-mode appearance model: the theme/font enums and the ReaderPreferences
// object that renders them into the live-apply JavaScript. Extracted from
// ArticleReaderView (DESLOPPIFY M4) with no behaviour change.

import SwiftUI
import UIKit

// MARK: - Reader preferences

enum ReaderTheme: String, CaseIterable, Equatable {
    case dark, light, sepia, warm
    // Premium cases
    case oled
    case terminal
    case solarized
    case paper

    var label: String {
        switch self {
        case .dark:      return "Dark"
        case .light:     return "Light"
        case .sepia:     return "Sepia"
        case .warm:      return "Warm"
        case .oled:      return "OLED"
        case .terminal:  return "Terminal"
        case .solarized: return "Solarized"
        case .paper:     return "Paper"
        }
    }

    /// CSS hex value for the page background
    var background: String {
        switch self {
        case .dark:      return "#0f0f1a"
        case .light:     return "#ffffff"
        case .sepia:     return "#f5f1e8"
        case .warm:      return "#1a1815"
        case .oled:      return "#000000"
        case .terminal:  return "#0d1a0d"
        case .solarized: return "#002b36"
        case .paper:     return "#f8f4e8"
        }
    }

    /// CSS hex value for body text
    var text: String {
        switch self {
        case .dark:      return "#e8e8ee"
        case .light:     return "#1a1a1a"
        case .sepia:     return "#3a3019"
        case .warm:      return "#ddd8cc"
        case .oled:      return "#e8e8ee"
        case .terminal:  return "#33ff66"
        case .solarized: return "#839496"
        case .paper:     return "#3a3019"
        }
    }

    /// CSS hex value for dimmed / secondary text
    var dim: String {
        switch self {
        case .dark:      return "#8888aa"
        case .light:     return "#6b6b7a"
        case .sepia:     return "#7a7060"
        case .warm:      return "#9a9080"
        case .oled:      return "#6666aa"
        case .terminal:  return "#1a8832"
        case .solarized: return "#586e75"
        case .paper:     return "#7a7060"
        }
    }

    /// CSS hex value for headings (needs separate control on light backgrounds)
    var heading: String {
        switch self {
        case .dark:      return "#ffffff"
        case .light:     return "#111111"
        case .sepia:     return "#2a2012"
        case .warm:      return "#ece7dc"
        case .oled:      return "#ffffff"
        case .terminal:  return "#66ff88"
        case .solarized: return "#93a1a1"
        case .paper:     return "#2a2012"
        }
    }

    /// CSS rgba for subtle borders
    var border: String {
        isLight ? "rgba(0,0,0,0.12)" : "rgba(255,255,255,0.10)"
    }

    /// CSS rgba for code block backgrounds
    var codeBg: String {
        isLight ? "rgba(0,0,0,0.05)" : "rgba(255,255,255,0.06)"
    }

    /// SwiftUI color for the theme swatch circle
    var swatchColor: Color {
        switch self {
        case .dark:      return Color(red: 0.06, green: 0.06, blue: 0.10)
        case .light:     return Color.white
        case .sepia:     return Color(red: 0.96, green: 0.95, blue: 0.91)
        case .warm:      return Color(red: 0.10, green: 0.10, blue: 0.08)
        case .oled:      return Color.black
        case .terminal:  return Color(red: 0.05, green: 0.10, blue: 0.05)
        case .solarized: return Color(red: 0.00, green: 0.17, blue: 0.21)
        case .paper:     return Color(red: 0.97, green: 0.96, blue: 0.91)
        }
    }

    /// True for light-background themes — used to pick checkmark colour
    var isLight: Bool { self == .light || self == .sepia || self == .paper }

    var isPremium: Bool {
        switch self {
        case .oled, .terminal, .solarized, .paper: return true
        default: return false
        }
    }
}

enum ReaderFont: String, CaseIterable, Equatable {
    case system = "System"
    case serif  = "Serif"
    case mono   = "Mono"

    var cssFamily: String {
        switch self {
        case .system: return "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"
        case .serif:  return "Georgia, 'Times New Roman', serif"
        case .mono:   return "'SF Mono', ui-monospace, Menlo, monospace"
        }
    }

    /// Font used to render the label in its own typeface
    var displayFont: Font {
        switch self {
        case .system: return .system(size: 15)
        case .serif:  return .custom("Georgia", size: 15)
        case .mono:   return .system(size: 14, design: .monospaced)
        }
    }
}

@Observable
final class ReaderPreferences {
    var theme: ReaderTheme  = .dark
    var fontSize: Double    = 18
    var fontFamily: ReaderFont = .system
    var showImages: Bool    = false
    /// Custom text color override. nil = use theme default.
    var textColor: Color?
    /// Custom heading color override. nil = use theme default.
    var headingColor: Color?
    /// Extra top padding (in points) added to the article body so its content
    /// clears an overlaid control strip. Used by the side-by-side floating chrome,
    /// where the glass buttons sit above the page rather than in a nav bar.
    var topInset: Double = 0

    static let minFontSize: Double = 14
    static let maxFontSize: Double = 26

    /// JS injected into the WKWebView to apply all preferences live.
    ///
    /// IMPORTANT: font-family values contain single quotes (e.g. 'Helvetica Neue'),
    /// so the --font property value must use double-quote JS string delimiters.
    /// Using single quotes there causes a syntax error that silently kills the
    /// entire IIFE, preventing all preference changes from taking effect.
    var applyScript: String {
        let showImagesJS = showImages ? "true" : "false"
        return """
        (function () {
            var root = document.documentElement;
            root.style.fontSize = '\(Int(fontSize))px';
            root.style.setProperty('--bg',      '\(theme.background)');
            root.style.setProperty('--text',    '\(textColorCSS)');
            root.style.setProperty('--dim',     '\(theme.dim)');
            root.style.setProperty('--heading', '\(headingColorCSS)');
            root.style.setProperty('--border',  '\(theme.border)');
            root.style.setProperty('--code-bg', '\(theme.codeBg)');
            root.style.setProperty('--font', "\(fontFamily.cssFamily)");
            document.body.style.backgroundColor = '\(theme.background)';
            document.body.style.paddingTop = '\(28 + Int(topInset))px';
            // Image pages (Imgur galleries) keep their images regardless of the global
            // toggle; only article pages honour the no-images class.
            if (!document.body.classList.contains('image-page')) {
                document.body.classList.toggle('no-images', !\(showImagesJS));
            }

            if (\(showImagesJS)) {
                // Resolve lazy-loaded images — many sites use data-src / data-lazy-src
                // instead of src, relying on JS scroll handlers to swap them in.
                // Since we disable page JS, we fix these up manually.
                document.querySelectorAll('img').forEach(function (img) {
                    var lazy = img.getAttribute('data-src')
                        || img.getAttribute('data-lazy-src')
                        || img.getAttribute('data-original')
                        || img.getAttribute('data-image');
                    if (lazy) { img.src = lazy; }
                });
            }
        })();
        """
    }

    private var textColorCSS: String {
        if let color = textColor {
            return "#\(color.toHexString())"
        }
        return theme.text
    }

    private var headingColorCSS: String {
        if let color = headingColor {
            return "#\(color.toHexString())"
        }
        return theme.heading
    }
}
