import XCTest
@testable import LiquidNews

final class StoriesViewModelTests: XCTestCase {

    // MARK: - isCancellation
    //
    // SwiftUI cancels a `.refreshable` task whenever the List that owns it
    // leaves the view hierarchy. Those cancellations must never surface as
    // user-facing errors.

    func test_isCancellation_swiftCancellationError() {
        XCTAssertTrue(CancellationError().isCancellation)
    }

    func test_isCancellation_urlErrorCancelled() {
        XCTAssertTrue(URLError(.cancelled).isCancellation)
    }

    func test_isCancellation_bridgedNSURLErrorCancelled() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertTrue(nsError.isCancellation)
    }

    func test_isCancellation_realNetworkError_isFalse() {
        XCTAssertFalse(URLError(.notConnectedToInternet).isCancellation)
    }

    func test_isCancellation_decodingError_isFalse() {
        let error = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "bad json")
        )
        XCTAssertFalse(error.isCancellation)
    }
}
