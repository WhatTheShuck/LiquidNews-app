import XCTest
@testable import LiquidNews

final class ImgurImageActionsTests: XCTestCase {

    /// A valid 1×1 transparent PNG, base64-encoded.
    static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    /// Counts how many times the injected fetch closure runs (async-safe).
    actor CallCounter {
        private(set) var count = 0
        func bump() { count += 1 }
    }

    // MARK: - localFile

    func test_localFile_writesTempFileAndCachesAfterFirstFetch() async throws {
        let counter = CallCounter()
        let fetch: ImgurImageActions.DataFetch = { _ in
            await counter.bump()
            return Self.onePixelPNG
        }
        let url = URL(string: "https://i.imgur.com/cachetest.png")!

        let first = await ImgurImageActions.localFile(for: url, fetch: fetch)
        let firstPath = try XCTUnwrap(first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstPath.path))

        let second = await ImgurImageActions.localFile(for: url, fetch: fetch)
        XCTAssertEqual(first, second, "second call must return the cached file")

        let count = await counter.count
        XCTAssertEqual(count, 1, "fetch must run only once (cache hit on second call)")
    }

    // MARK: - localFiles

    func test_localFiles_preservesOrderAndDropsFailures() async {
        let good1 = URL(string: "https://i.imgur.com/order1.png")!
        let bad   = URL(string: "https://i.imgur.com/orderbad.png")!
        let good2 = URL(string: "https://i.imgur.com/order2.png")!
        let fetch: ImgurImageActions.DataFetch = { url in
            url == bad ? nil : Self.onePixelPNG
        }

        let files = await ImgurImageActions.localFiles(for: [good1, bad, good2], fetch: fetch)
        XCTAssertEqual(files.count, 2, "the failed download must be dropped")

        let f1 = await ImgurImageActions.localFile(for: good1, fetch: fetch)
        let f2 = await ImgurImageActions.localFile(for: good2, fetch: fetch)
        XCTAssertEqual(files, [f1, f2], "results must be in input order")
    }

    // MARK: - image

    func test_image_decodesValidBytes() async {
        let fetch: ImgurImageActions.DataFetch = { _ in Self.onePixelPNG }
        let image = await ImgurImageActions.image(
            for: URL(string: "https://i.imgur.com/valid.png")!, fetch: fetch)
        XCTAssertNotNil(image)
    }

    func test_image_returnsNilForGarbageBytes() async {
        let fetch: ImgurImageActions.DataFetch = { _ in Data([0x00, 0x01, 0x02, 0x03]) }
        let image = await ImgurImageActions.image(
            for: URL(string: "https://i.imgur.com/garbage.png")!, fetch: fetch)
        XCTAssertNil(image)
    }
}
