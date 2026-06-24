import XCTest
@testable import LiquidNews

final class WordsOfWisdomTests: XCTestCase {

    func test_quotes_isNotEmpty() {
        XCTAssertFalse(WordsOfWisdom.quotes.isEmpty)
    }

    func test_random_returnsAMemberOfQuotes() {
        for _ in 0..<50 {
            XCTAssertTrue(WordsOfWisdom.quotes.contains(WordsOfWisdom.random))
        }
    }

    func test_firstQuote_isSeeded() {
        XCTAssertTrue(WordsOfWisdom.quotes.contains("Lucky boys get pizza"))
    }
}
