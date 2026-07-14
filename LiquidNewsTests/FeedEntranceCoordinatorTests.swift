import XCTest
@testable import LiquidNews

final class FeedEntranceCoordinatorTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func coordinator() -> FeedEntranceCoordinator {
        let c = FeedEntranceCoordinator()
        c.beginGeneration(now: start)
        return c
    }

    // MARK: - Before any load event

    func test_beforeAnyGeneration_returnsNil() {
        let c = FeedEntranceCoordinator()
        XCTAssertNil(c.entranceDelay(id: 1, index: 0, now: start))
    }

    // MARK: - Stagger

    func test_firstAppearance_returnsIndexStaggeredDelay() {
        let c = coordinator()
        XCTAssertEqual(c.entranceDelay(id: 1, index: 0, now: start), 0)
        XCTAssertEqual(
            c.entranceDelay(id: 2, index: 3, now: start),
            3 * FeedEntranceCoordinator.staggerStep
        )
    }

    func test_staggerIsCapped() {
        let c = coordinator()
        XCTAssertEqual(
            c.entranceDelay(id: 1, index: 20, now: start),
            Double(FeedEntranceCoordinator.staggerCap) * FeedEntranceCoordinator.staggerStep
        )
    }

    // MARK: - Once per ID per generation

    func test_sameID_secondAppearance_returnsNil() {
        let c = coordinator()
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: start))
        XCTAssertNil(c.entranceDelay(id: 1, index: 0, now: start))
    }

    func test_distinctIDs_bothAnimate() {
        let c = coordinator()
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: start))
        XCTAssertNotNil(c.entranceDelay(id: 2, index: 1, now: start))
    }

    // MARK: - Window

    func test_appearanceInsideWindow_animates() {
        let c = coordinator()
        let justInside = start.addingTimeInterval(FeedEntranceCoordinator.window - 0.01)
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: justInside))
    }

    func test_appearanceAfterWindow_returnsNil() {
        let c = coordinator()
        let late = start.addingTimeInterval(FeedEntranceCoordinator.window + 0.01)
        XCTAssertNil(c.entranceDelay(id: 1, index: 0, now: late))
    }

    // MARK: - Pagination

    func test_markSettled_paginationRowsInsideWindow_doNotAnimate() {
        let c = coordinator()
        // Page 2 lands 0.5s after the load event — well inside the window —
        // but pagination is never a load event, so its rows must not animate.
        c.markSettled([10, 11])
        let inside = start.addingTimeInterval(0.5)
        XCTAssertNil(c.entranceDelay(id: 10, index: 20, now: inside))
        XCTAssertNil(c.entranceDelay(id: 11, index: 21, now: inside))
    }

    func test_markSettled_doesNotAffectOtherIDs() {
        let c = coordinator()
        c.markSettled([10])
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: start))
    }

    func test_markSettled_clearedByNewGeneration() {
        let c = coordinator()
        c.markSettled([10])

        let secondStart = start.addingTimeInterval(60)
        c.beginGeneration(now: secondStart)
        XCTAssertNotNil(c.entranceDelay(id: 10, index: 0, now: secondStart))
    }

    // MARK: - Generations

    func test_newGeneration_allowsSameIDAgain() {
        let c = coordinator()
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: start))

        let secondStart = start.addingTimeInterval(60)
        c.beginGeneration(now: secondStart)
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: secondStart))
    }

    func test_lateRow_thenNewGeneration_animates() {
        let c = coordinator()
        // Row realized too late to animate in generation 1…
        let late = start.addingTimeInterval(10)
        XCTAssertNil(c.entranceDelay(id: 1, index: 0, now: late))

        // …still animates when a fresh load event opens generation 2.
        let secondStart = start.addingTimeInterval(60)
        c.beginGeneration(now: secondStart)
        XCTAssertNotNil(c.entranceDelay(id: 1, index: 0, now: secondStart))
    }
}
