import XCTest
@testable import LiquidNews

final class StoriesViewModelTests: XCTestCase {

    // MARK: - isCancellation
    //
    // SwiftUI cancels a `.refreshable` task whenever the List that owns it
    // leaves the view hierarchy. Those cancellations must never surface as
    // user-facing errors.

    func test_isCancellation_swiftCancellationError() {
        XCTAssertTrue(StoriesViewModel.isCancellation(CancellationError()))
    }

    func test_isCancellation_urlErrorCancelled() {
        XCTAssertTrue(StoriesViewModel.isCancellation(URLError(.cancelled)))
    }

    func test_isCancellation_bridgedNSURLErrorCancelled() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertTrue(StoriesViewModel.isCancellation(nsError))
    }

    func test_isCancellation_realNetworkError_isFalse() {
        XCTAssertFalse(StoriesViewModel.isCancellation(URLError(.notConnectedToInternet)))
    }

    func test_isCancellation_decodingError_isFalse() {
        let error = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "bad json")
        )
        XCTAssertFalse(StoriesViewModel.isCancellation(error))
    }
}
