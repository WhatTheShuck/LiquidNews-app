import XCTest
@testable import LiquidNews

final class HNURLRouterTests: XCTestCase {

    // MARK: - isHNItemURL

    func test_isHNItemURL_acceptsValidItemURL() {
        let url = URL(string: "https://news.ycombinator.com/item?id=12345")!
        XCTAssertTrue(HNURLRouter.isHNItemURL(url))
    }

    func test_isHNItemURL_acceptsHttpScheme() {
        let url = URL(string: "http://news.ycombinator.com/item?id=12345")!
        XCTAssertTrue(HNURLRouter.isHNItemURL(url))
    }

    func test_isHNItemURL_rejectsNonYCombinatorDomain() {
        let url = URL(string: "https://example.com/item?id=12345")!
        XCTAssertFalse(HNURLRouter.isHNItemURL(url))
    }

    func test_isHNItemURL_rejectsNonItemPath() {
        let url = URL(string: "https://news.ycombinator.com/user?id=pg")!
        XCTAssertFalse(HNURLRouter.isHNItemURL(url))
    }

    func test_isHNItemURL_rejectsMissingIDParam() {
        let url = URL(string: "https://news.ycombinator.com/item")!
        XCTAssertFalse(HNURLRouter.isHNItemURL(url))
    }

    func test_isHNItemURL_rejectsItemPathWithoutID() {
        let url = URL(string: "https://news.ycombinator.com/item?foo=bar")!
        XCTAssertFalse(HNURLRouter.isHNItemURL(url))
    }

    // MARK: - itemID(from:)

    func test_itemID_extractsValidInteger() {
        let url = URL(string: "https://news.ycombinator.com/item?id=42000")!
        XCTAssertEqual(HNURLRouter.itemID(from: url), 42000)
    }

    func test_itemID_returnsNilForNonHNURL() {
        let url = URL(string: "https://example.com/item?id=42000")!
        XCTAssertNil(HNURLRouter.itemID(from: url))
    }

    func test_itemID_returnsNilForNonNumericID() {
        let url = URL(string: "https://news.ycombinator.com/item?id=abc")!
        XCTAssertNil(HNURLRouter.itemID(from: url))
    }

    func test_itemID_extractsIDWithAdditionalQueryParams() {
        let url = URL(string: "https://news.ycombinator.com/item?id=99&p=2")!
        XCTAssertEqual(HNURLRouter.itemID(from: url), 99)
    }
}
