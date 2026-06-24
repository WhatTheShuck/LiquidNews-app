// PremiumPaywallView.swift
// Paywall sheet shown when a premium feature is accessed without entitlement.

import StoreKit
import SwiftUI

struct PremiumPaywallView: View {

    // Kept for call-site compatibility — no longer applies a visual highlight.
    let focused: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var store = StoreService.shared

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var purchaseError: String?

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .footnote) private var captionSize: CGFloat = 13

    init(focused: String? = nil) {
        self.focused = focused
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                header
                mainProductsSection
                restoreButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("LiquidNews Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        .alert(
            "Restore Failed",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text("LiquidNews Premium")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Unlock premium features with a one-time purchase.")
                .font(.system(size: captionSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Main products

    private var mainProductsSection: some View {
        VStack(spacing: 0) {
            ProductRowView(
                id: StoreService.ProductID.account,
                icon: "lock.open.fill",
                title: "Account",
                description: "Vote, reply, and flag on Hacker News",
                isOwned: store.isAccountUnlocked
            )
            Divider().overlay(AppTheme.glassBorder).padding(.horizontal, 16)
            ProductRowView(
                id: StoreService.ProductID.themes,
                icon: "paintpalette.fill",
                title: "Themes",
                description: "Premium app and reader themes",
                isOwned: store.isThemesUnlocked
            )
            Divider().overlay(AppTheme.glassBorder).padding(.horizontal, 16)
            ProductRowView(
                id: StoreService.ProductID.bundle,
                icon: "star.fill",
                title: "Bundle — Best Value",
                description: "Account + Themes at a discount",
                isOwned: store.isAccountUnlocked && store.isThemesUnlocked,
                // Owning either component already makes the Bundle a double-charge,
                // so it's offered but ineligible until they own nothing.
                isUnavailable: !store.isBundlePurchasable
                    && !(store.isAccountUnlocked && store.isThemesUnlocked)
            )
        }
        .glassCard()
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await handleRestore() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: captionSize))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Restore action

    private func handleRestore() async {
        await store.restorePurchases()
        if let err = store.purchaseError {
            purchaseError = err
            return
        }
        let hasAny = store.isAccountUnlocked || store.isThemesUnlocked
        restoreMessage =
            hasAny
            ? "Your purchases have been restored."
            : "No purchases found to restore."
        showRestoreAlert = true
    }
}

// MARK: - Product Row

private struct ProductRowView: View {
    let id: String
    let icon: String
    let title: String
    let description: String
    let isOwned: Bool
    var isUnavailable: Bool = false

    @State private var store = StoreService.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var captionSize: CGFloat = 13

    var body: some View {
        Button {
            guard !isPurchasing else { return }
            Task { await purchase() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: captionSize))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isUnavailable {
                    Text("Unavailable")
                        .font(.system(size: captionSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if isPurchasing {
                    ProgressView().scaleEffect(0.8)
                } else if let product = store.product(for: id) {
                    Text(product.displayPrice)
                        .font(.system(size: captionSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.accent.opacity(0.3), in: Capsule())
                } else {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .opacity(isUnavailable ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isOwned || isUnavailable)
        .alert(
            "Purchase Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func purchase() async {
        guard let product = store.product(for: id) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await StoreService.shared.purchase(product)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PremiumPaywallView(focused: StoreService.ProductID.account)
    }
}
