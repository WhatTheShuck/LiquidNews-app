// StoreService.swift
// Manages StoreKit 2 products, purchases, transaction verification,
// entitlements, and the 7-day Account free trial.
//
// Follows the same singleton pattern as HNAuthService and UserSettings.

import Foundation
import StoreKit
import Observation
import UIKit

// MARK: - Error

enum StoreServiceError: LocalizedError {
    case failedVerification
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "Purchase could not be verified."
        case .purchaseFailed:     return "Purchase failed. Please try again."
        }
    }
}

// MARK: - StoreService

@Observable
final class StoreService {

    static let shared = StoreService()

    // MARK: - Product IDs

    enum ProductID {
        static let account  = "com.liquidnews.premium.account"
        static let themes   = "com.liquidnews.premium.themes"
        static let bundle   = "com.liquidnews.premium.bundle"

        static let all: [String] = [account, themes, bundle]
    }

    // MARK: - Published state

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = true
    private(set) var purchaseError: String?

    // MARK: - Entitlements (computed from purchasedProductIDs)

    var isAccountUnlocked: Bool {
        Self.accountUnlocked(purchasedIDs: purchasedProductIDs)
    }

    var isThemesUnlocked: Bool {
        Self.themesUnlocked(purchasedIDs: purchasedProductIDs)
    }

    /// True only when the Bundle is still a valid purchase (user owns neither component).
    var isBundlePurchasable: Bool {
        Self.bundlePurchasable(purchasedIDs: purchasedProductIDs)
    }

    // MARK: - Trial

    enum TrialState: Equatable {
        case notStarted
        case active       // days 0–7: full access
        case grace        // days 7–10: access continues, nudge shown
        case hardExpired  // day 10+: forced free state, no dialog can bypass
    }

    private let kvStore = NSUbiquitousKeyValueStore.default
    private enum Keys {
        static let firstAccountUseDate = "LN_firstAccountUseDate"
    }

    /// Cached trial start date — stored so SwiftUI observation tracks changes.
    private(set) var trialStartDate: Date?

    /// Single trial window covering both Account and Themes.
    var trialState: TrialState {
        guard let date = trialStartDate else { return .notStarted }
        let elapsed = Date.now.timeIntervalSince(date)
        if elapsed < 7 * 24 * 3_600  { return .active }
        if elapsed < 10 * 24 * 3_600 { return .grace }
        return .hardExpired
    }

    /// True if the trial is running and the feature hasn't been purchased.
    var isInAccountTrial: Bool { trialState == .active && !isAccountUnlocked }

    /// True if account features are accessible — purchased, trial active, or in grace period.
    var accountAccessible: Bool { isAccountUnlocked || trialState == .active || trialState == .grace }

    /// True if theme features are accessible — purchased, trial active, or in grace period.
    var themesAccessible: Bool { isThemesUnlocked || trialState == .active || trialState == .grace }

    /// Days left in the 7-day trial, clamped to 0–7.
    var trialDaysRemaining: Int {
        guard let date = trialStartDate else { return 0 }
        let remaining = (7 * 24 * 3_600) - Date.now.timeIntervalSince(date)
        return max(0, Int(ceil(remaining / (24 * 3_600))))
    }

    /// Days left in the 3-day grace period, clamped to 0–3.
    var graceDaysRemaining: Int {
        guard let date = trialStartDate else { return 0 }
        let remaining = (10 * 24 * 3_600) - Date.now.timeIntervalSince(date)
        return max(0, Int(ceil(remaining / (24 * 3_600))))
    }

    /// Records the trial start date the first time this is called.
    /// Safe to call multiple times — only writes on first call.
    func startTrialIfNeeded() {
        guard kvStore.object(forKey: Keys.firstAccountUseDate) == nil else { return }
        let now = Date.now
        kvStore.set(now, forKey: Keys.firstAccountUseDate)
        kvStore.synchronize()
        trialStartDate = now
    }

    // MARK: - Static pure logic (testable without StoreKit)

    static func isInTrial(since startDate: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(startDate) < 7 * 24 * 3_600
    }

    static func accountUnlocked(purchasedIDs: Set<String>) -> Bool {
        purchasedIDs.contains(ProductID.account) ||
        purchasedIDs.contains(ProductID.bundle)
    }

    static func themesUnlocked(purchasedIDs: Set<String>) -> Bool {
        purchasedIDs.contains(ProductID.themes) ||
        purchasedIDs.contains(ProductID.bundle)
    }

    /// The Bundle is a standalone non-consumable with no App Store auto-discount,
    /// so it must only be offered to users who own neither component. Owning either
    /// individual product (or the Bundle itself) makes a Bundle purchase a double-charge.
    static func bundlePurchasable(purchasedIDs: Set<String>) -> Bool {
        !accountUnlocked(purchasedIDs: purchasedIDs) &&
        !themesUnlocked(purchasedIDs: purchasedIDs)
    }

    // MARK: - Products

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Purchase

    /// Initiates a purchase. Returns the verified transaction on success, nil if cancelled.
    /// Throws `StoreServiceError` on verification failure.
    /// Must be called from the main actor so we can resolve the active UIWindowScene,
    /// which prevents StoreKit's payment sheet from getting stuck behind a sheet presentation.
    @MainActor
    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        purchaseError = nil
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let result: Product.PurchaseResult
        if let windowScene {
            result = try await product.purchase(confirmIn: windowScene)
        } else {
            result = try await product.purchase()
        }
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Re-fetches products from StoreKit. Safe to call from any context.
    /// A no-op if a load is already in progress.
    func reloadProducts() async {
        guard !isLoadingProducts else { return }
        await MainActor.run { isLoadingProducts = true }
        await loadProducts()
    }

    // MARK: - Init

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        trialStartDate = kvStore.object(forKey: Keys.firstAccountUseDate) as? Date
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Private

    private func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProductID.all)
            await MainActor.run {
                self.products = fetched
                self.isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingProducts = false
                print("[StoreService] Failed to load products: \(error)")
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("[StoreService] Transaction verification failed: \(error)")
                }
            }
        }
    }

    @MainActor
    func updatePurchasedProducts() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreServiceError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - Debug helpers (DEBUG builds only)

    #if DEBUG
    /// Backdates the trial start to 8 days ago, entering the grace period.
    func debugExpireTrial() {
        let date = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        kvStore.set(date, forKey: Keys.firstAccountUseDate)
        kvStore.synchronize()
        trialStartDate = date
    }

    /// Backdates the trial start to 11 days ago, simulating hard expiry.
    func debugHardExpireTrial() {
        let date = Calendar.current.date(byAdding: .day, value: -11, to: .now)!
        kvStore.set(date, forKey: Keys.firstAccountUseDate)
        kvStore.synchronize()
        trialStartDate = date
    }

    /// Clears the trial start date entirely, resetting to the "not started" state.
    func debugResetTrial() {
        kvStore.removeObject(forKey: Keys.firstAccountUseDate)
        kvStore.synchronize()
        trialStartDate = nil
    }

    /// Sets the trial start date to right now, giving a fresh 7-day window.
    func debugStartFreshTrial() {
        let now = Date.now
        kvStore.set(now, forKey: Keys.firstAccountUseDate)
        kvStore.synchronize()
        trialStartDate = now
    }
    #endif
}
