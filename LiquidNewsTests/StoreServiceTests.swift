import XCTest
@testable import LiquidNews

final class StoreServiceTests: XCTestCase {

    // MARK: - Trial logic

    func test_trialActive_whenWithin7Days() {
        let sixDaysAgo = Date.now.addingTimeInterval(-6 * 24 * 3_600)
        XCTAssertTrue(StoreService.isInTrial(since: sixDaysAgo))
    }

    func test_trialExpired_after7Days() {
        let eightDaysAgo = Date.now.addingTimeInterval(-8 * 24 * 3_600)
        XCTAssertFalse(StoreService.isInTrial(since: eightDaysAgo))
    }

    func test_trialExpires_exactlyAt7Days() {
        let exactly7Days = Date.now.addingTimeInterval(-7 * 24 * 3_600)
        XCTAssertFalse(StoreService.isInTrial(since: exactly7Days))
    }

    // MARK: - Entitlement logic

    func test_accountUnlocked_byAccountProduct() {
        XCTAssertTrue(StoreService.accountUnlocked(purchasedIDs: ["com.liquidnews.premium.account"]))
    }

    func test_accountUnlocked_byBundle() {
        XCTAssertTrue(StoreService.accountUnlocked(purchasedIDs: ["com.liquidnews.premium.bundle"]))
    }

    func test_accountNotUnlocked_withThemesOnly() {
        XCTAssertFalse(StoreService.accountUnlocked(purchasedIDs: ["com.liquidnews.premium.themes"]))
    }

    func test_themesUnlocked_byThemesProduct() {
        XCTAssertTrue(StoreService.themesUnlocked(purchasedIDs: ["com.liquidnews.premium.themes"]))
    }

    func test_themesUnlocked_byBundle() {
        XCTAssertTrue(StoreService.themesUnlocked(purchasedIDs: ["com.liquidnews.premium.bundle"]))
    }

    func test_themesNotUnlocked_withAccountOnly() {
        XCTAssertFalse(StoreService.themesUnlocked(purchasedIDs: ["com.liquidnews.premium.account"]))
    }

    // MARK: - Bundle purchasability

    func test_bundlePurchasable_whenOwningNothing() {
        XCTAssertTrue(StoreService.bundlePurchasable(purchasedIDs: []))
    }

    func test_bundleNotPurchasable_whenOwningAccountOnly() {
        XCTAssertFalse(StoreService.bundlePurchasable(purchasedIDs: ["com.liquidnews.premium.account"]))
    }

    func test_bundleNotPurchasable_whenOwningThemesOnly() {
        XCTAssertFalse(StoreService.bundlePurchasable(purchasedIDs: ["com.liquidnews.premium.themes"]))
    }

    func test_bundleNotPurchasable_whenOwningBundle() {
        XCTAssertFalse(StoreService.bundlePurchasable(purchasedIDs: ["com.liquidnews.premium.bundle"]))
    }

    func test_bundleNotPurchasable_whenOwningBothIndividualProducts() {
        XCTAssertFalse(StoreService.bundlePurchasable(
            purchasedIDs: ["com.liquidnews.premium.account", "com.liquidnews.premium.themes"]
        ))
    }
}
