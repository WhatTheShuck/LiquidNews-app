// OnboardingView.swift
// Shown once on first launch to introduce LiquidNews features.

import SwiftUI

struct OnboardingView: View {

    var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let features: [(icon: String, title: String, body: String)] = [
        (
            "flame",
            "Hacker News, beautifully",
            "All of HN with a Liquid Glass design built for iOS 26."
        ),
        (
            "square.grid.2x2",
            "Feed categories",
            "Switch between Top, New, Best, Ask, Show, Jobs and more with a tap or swipe."
        ),
        (
            "hand.draw",
            "Swipe actions",
            "Swipe story cards to save, favourite, or hide — fully customisable in Settings."
        ),
        (
            "bookmark",
            "Save & curate",
            "Save stories for later, follow curated newsletters, and track what you've read."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 56)
                        Text("Welcome to LiquidNews")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }

                    // Feature cards
                    VStack(spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            FeatureCard(icon: feature.icon, title: feature.title, body: feature.body)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            // Get Started button — pinned to bottom
            Button(action: onDismiss) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassEffect(
                        in: RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.25))
                            .allowsHitTesting(false)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(ThemeBackground().ignoresSafeArea())
    }
}

#Preview {
    OnboardingView { }
}
