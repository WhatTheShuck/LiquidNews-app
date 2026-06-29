// WhatsNewView.swift
// Version-gated sheet shown to existing users after they update, advertising
// this release's headline features. Distinct from OnboardingView (first launch).

import SwiftUI

struct WhatsNewView: View {

    var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let features: [(icon: String, title: String, body: String)] = [
        (
            "wifi.slash",
            "Offline mode",
            "Read saved stories and cached threads with no connection."
        ),
        (
            "arrow.down.circle",
            "Prepare for offline",
            "Download stories and their comments ahead of a flight or commute."
        ),
        (
            "internaldrive",
            "Persistent cache",
            "Stories you've opened load instantly, cache-first, on every launch."
        ),
        (
            "arrow.triangle.2.circlepath",
            "Continue from iCloud",
            "Pick up the story you were reading on another device."
        ),
        (
            "sidebar.left",
            "iPad split view",
            "A three-column layout that uses every inch of a larger screen."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 64))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 56)
                        Text("What's New")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            FeatureCard(icon: feature.icon, title: feature.title, body: feature.body)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            Button(action: onDismiss) {
                Text("Continue")
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
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
    }
}

#Preview {
    WhatsNewView { }
}
