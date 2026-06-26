import XCTest
@testable import LiquidNews

final class CacheReconcilerTests: XCTestCase {

    func test_updatesFieldsInPlacePreservingOrder() {
        let displayed = [
            HNItem(id: 1, type: .story, title: "A", score: 10),
            HNItem(id: 2, type: .story, title: "B", score: 20),
        ]
        let fresh = [
            HNItem(id: 2, type: .story, title: "B", score: 99),  // order differs upstream
            HNItem(id: 1, type: .story, title: "A", score: 50),
        ]
        let result = CacheReconciler.reconcile(displayed: displayed, fresh: fresh)
        XCTAssertEqual(result.map(\.id), [1, 2], "displayed order preserved")
        XCTAssertEqual(result[0].score, 50, "fresh fields applied to item 1")
        XCTAssertEqual(result[1].score, 99, "fresh fields applied to item 2")
    }

    func test_dropsItemsAbsentFromFresh() {
        let displayed = [HNItem(id: 1, type: .story), HNItem(id: 2, type: .story)]
        let fresh = [HNItem(id: 1, type: .story)]
        let result = CacheReconciler.reconcile(displayed: displayed, fresh: fresh)
        XCTAssertEqual(result.map(\.id), [1])
    }

    func test_appendsNewFreshItemsAtEndInFreshOrder() {
        let displayed = [HNItem(id: 1, type: .story)]
        let fresh = [
            HNItem(id: 1, type: .story),
            HNItem(id: 3, type: .story),
            HNItem(id: 4, type: .story),
        ]
        let result = CacheReconciler.reconcile(displayed: displayed, fresh: fresh)
        XCTAssertEqual(result.map(\.id), [1, 3, 4])
    }

    func test_emptyDisplayedReturnsFresh() {
        let fresh = [HNItem(id: 1, type: .story), HNItem(id: 2, type: .story)]
        let result = CacheReconciler.reconcile(displayed: [], fresh: fresh)
        XCTAssertEqual(result.map(\.id), [1, 2])
    }
}
