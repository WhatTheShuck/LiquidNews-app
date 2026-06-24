import XCTest
@testable import LiquidNews

final class IPadReaderLayoutTests: XCTestCase {

    func test_rawValues_roundTrip() {
        for layout in IPadReaderLayout.allCases {
            XCTAssertEqual(IPadReaderLayout(rawValue: layout.rawValue), layout)
        }
    }

    func test_allCases_orderHasSideBySideFirst() {
        XCTAssertEqual(IPadReaderLayout.allCases, [.sideBySide, .replace])
    }

    func test_eachCaseHasLabelAndSystemImage() {
        for layout in IPadReaderLayout.allCases {
            XCTAssertFalse(layout.label.isEmpty)
            XCTAssertFalse(layout.systemImage.isEmpty)
        }
    }
}
