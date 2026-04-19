// GlassCard.swift
// Liquid glass card styling using iOS 26's native .glassEffect() modifier.
//
// Supports an optional `tint` colour that overlays a subtle wash on the glass,
// used by comment threads to colour-code nesting depth.

import SwiftUI

extension CGFloat {
    static let glassCornerRadius: CGFloat = 28
}

// MARK: - View modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        content
            // .regular is explicitly non-interactive — suppresses the touch-highlight
            // that the default context-aware glass shows when interactive children
            // (Buttons, gesture recognisers) are detected inside the card.
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Subtle colour wash on top of the glass when a tint is specified
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.10))
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = .glassCornerRadius, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
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
