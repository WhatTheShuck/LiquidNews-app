import XCTest
@testable import LiquidNews

final class ResumeModeTests: XCTestCase {

    func test_rawValues_roundTrip() {
        for mode in ResumeMode.allCases {
            XCTAssertEqual(ResumeMode(rawValue: mode.rawValue), mode)
        }
    }

    func test_allCases_orderIsOffPromptAuto() {
        XCTAssertEqual(ResumeMode.allCases, [.off, .prompt, .auto])
    }

    func test_unknownRawValue_isNil_soCallersFallBackToPrompt() {
        XCTAssertNil(ResumeMode(rawValue: "garbage"))
    }

    func test_eachCaseHasLabelSubtitleAndSystemImage() {
        for mode in ResumeMode.allCases {
            XCTAssertFalse(mode.label.isEmpty)
            XCTAssertFalse(mode.subtitle.isEmpty)
            XCTAssertFalse(mode.systemImage.isEmpty)
        }
    }
}
