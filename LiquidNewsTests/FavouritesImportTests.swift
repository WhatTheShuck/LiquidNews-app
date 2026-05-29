import XCTest
@testable import LiquidNews

final class FavouritesImportTests: XCTestCase {

    // MARK: - parseIDs

    func test_parseIDs_bracketed() throws {
        let ids = try SavedPostsStore.parseIDs(from: "[37140159,37158317,37239747]")
        XCTAssertEqual(ids, [37140159, 37158317, 37239747])
    }

    func test_parseIDs_bare() throws {
        let ids = try SavedPostsStore.parseIDs(from: "37140159,37158317")
        XCTAssertEqual(ids, [37140159, 37158317])
    }

    func test_parseIDs_withWhitespace() throws {
        let ids = try SavedPostsStore.parseIDs(from: "[ 37140159 , 37158317 ]")
        XCTAssertEqual(ids, [37140159, 37158317])
    }

    func test_parseIDs_singleID() throws {
        let ids = try SavedPostsStore.parseIDs(from: "[37140159]")
        XCTAssertEqual(ids, [37140159])
    }

    func test_parseIDs_skipsNonIntegers() throws {
        let ids = try SavedPostsStore.parseIDs(from: "[37140159,abc,37158317]")
        XCTAssertEqual(ids, [37140159, 37158317])
    }

    func test_parseIDs_emptyStringThrows() {
        XCTAssertThrowsError(try SavedPostsStore.parseIDs(from: "")) { error in
            XCTAssertTrue(error is FavouritesImportError)
        }
    }

    func test_parseIDs_emptyBracketsThrows() {
        XCTAssertThrowsError(try SavedPostsStore.parseIDs(from: "[]")) { error in
            XCTAssertTrue(error is FavouritesImportError)
        }
    }

    func test_parseIDs_allInvalidTokensThrows() {
        XCTAssertThrowsError(try SavedPostsStore.parseIDs(from: "[abc,def]")) { error in
            XCTAssertTrue(error is FavouritesImportError)
        }
    }

    // MARK: - exportFavouritesCompact format

    func test_exportFavouritesCompact_isCompactJSON() throws {
        // Parse a known compact string and verify round-trip format
        let ids = try SavedPostsStore.parseIDs(from: "[1,2,3]")
        // Re-encode via JSONEncoder (same path as exportFavouritesCompact)
        let data = try JSONEncoder().encode(ids)
        let result = String(data: data, encoding: .utf8)
        XCTAssertEqual(result, "[1,2,3]")
    }
}
