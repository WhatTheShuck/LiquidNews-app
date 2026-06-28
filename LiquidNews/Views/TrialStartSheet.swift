// TrialStartSheet.swift
// Confirmation sheet shown before the 7-day free trial starts, so the user
// knows they're opting into a trial rather than having it begin silently.
//
// Purely presentational — owns no trial logic. The caller passes `onConfirm`,
// which runs `StoreService.startTrialIfNeeded()` (plus any pending action, e.g.
// applying a premium theme) when the user taps "Start".

import SwiftUI

struct TrialStartSheet: View {

    /// Runs when the user confirms. The caller starts the trial and applies any
    /// pending action here. The sheet dismisses itself afterwards.
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .title3)   private var titleSize:   CGFloat = 20
    @ScaledMetric(relativeTo: .body)      private var buttonSize:  CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var captionSize: CGFloat = 13

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                header
                perks
                reassurance
                startButton
                notNowButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Free Trial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text("Start your free trial")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("7 days of full access — then everything reverts to the free version.")
                .font(.system(size: captionSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Perks

    private var perks: some View {
        VStack(spacing: 0) {
            perkRow(
                icon: "lock.open.fill",
                title: "Account",
                description: "Vote, reply, and flag on Hacker News"
            )
            Divider().overlay(AppTheme.glassBorder).padding(.horizontal, 16)
            perkRow(
                icon: "paintpalette.fill",
                title: "Themes",
                description: "Premium app and reader themes"
            )
        }
        .glassCard()
    }

    private func perkRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: buttonSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: captionSize))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Reassurance

    private var reassurance: some View {
        Text("No payment, no card required. Nothing auto-charges — access simply ends when the trial does.")
            .font(.system(size: captionSize))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Buttons

    private var startButton: some View {
        Button {
            onConfirm()
            dismiss()
        } label: {
            HStack {
                Spacer()
                Text("Start 7-Day Free Trial")
                    .font(.system(size: buttonSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 16)
            .glassEffect(in: RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: .glassCornerRadius, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.25))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }

    private var notNowButton: some View {
        Button { dismiss() } label: {
            Text("Not now")
                .font(.system(size: captionSize))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrialStartSheet(onConfirm: {})
    }
}
