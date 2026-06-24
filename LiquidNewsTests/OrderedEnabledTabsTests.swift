import Testing
@testable import LiquidNews

struct OrderedEnabledTabsTests {
    @Test func feedAlwaysFirstAndOnlyEnabledOptionalsInOrder() {
        let order: [AppTab] = [.curated, .readLater, .history, .favourites, .catchUp]
        let enabled: Set<AppTab> = [.readLater, .catchUp]
        // Feed prepended; optionals appear in `order` sequence, filtered to enabled.
        #expect(AppTab.orderedEnabled(order: order, enabled: enabled) == [.feed, .readLater, .catchUp])
    }

    @Test func noOptionalsEnabledLeavesOnlyFeed() {
        #expect(AppTab.orderedEnabled(order: AppTab.optional, enabled: []) == [.feed])
    }

    @Test func feedInOrderArrayIsNotDuplicated() {
        // `tabOrder` never contains .feed, but guard against accidental duplication.
        let result = AppTab.orderedEnabled(order: [.feed, .curated], enabled: [.curated])
        #expect(result == [.feed, .curated])
    }
}
