// OnboardingView.swift
// Shown once on first launch to introduce LiquidNews features.

import SwiftUI

struct OnboardingView: View {

    var onDismiss: () -> Void

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
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }

                    // Feature cards
                    VStack(spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            HStack(spacing: 16) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(feature.body)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .glassCard()
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
                    .foregroundStyle(.white)
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
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView { }
}
