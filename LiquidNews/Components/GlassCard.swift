// GlassCard.swift
// Liquid glass card styling using iOS 26's native .glassEffect() modifier.
//
// Supports an optional `tint` colour that overlays a subtle wash on the glass,
// used for semantic highlights (warning red/orange, comment thread colours).
// When no tint is passed, the wash defaults to the active accent so every card
// carries the theme identity on any background. Pass `.clear` to opt out.

import SwiftUI

extension CGFloat {
    static let glassCornerRadius: CGFloat = 28
}

// MARK: - View modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?

    /// Explicit tints always win — semantic tints (warning red, thread
    /// colours, `.clear` opt-outs) must not be replaced by the accent wash.
    static func effectiveTint(explicit: Color?, accent: Color) -> Color {
        explicit ?? accent
    }

    func body(content: Content) -> some View {
        // AppTheme.accent reads customAccentHex and selectedAppTheme off the
        // @Observable UserSettings.shared, so every glassCard() callsite
        // re-renders live on theme or custom-accent changes.
        let resolvedTint = Self.effectiveTint(explicit: tint, accent: AppTheme.accent)
        content
            // Context-aware glass: automatically renders as an interactive card when
            // it detects interactive content (Buttons) inside. This keeps the glow
            // state consistent through layout changes — using .regular here caused
            // flickering because it conflicted with the system's own interactive-state
            // detection on every re-render.
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Subtle colour wash on top of the glass
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(resolvedTint.opacity(0.10))
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = .glassCornerRadius, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Standard sheet chrome: visible drag indicator + glass corner radius.
    /// Detents and iPad sizing stay at the call site — they vary per sheet.
    func glassSheet() -> some View {
        self
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
    }
}

// MARK: - Convenience container

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = .glassCornerRadius
    var tint: Color?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .glassCard(cornerRadius: cornerRadius, tint: tint)
    }
}
