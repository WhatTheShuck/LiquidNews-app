import XCTest
@testable import LiquidNews

final class ReaderPreferencesTests: XCTestCase {

    func test_applyScript_togglesNoImagesClassInsteadOfOverwriting() {
        let prefs = ReaderPreferences()
        // Must NOT clobber the whole className (which would drop `image-page`).
        XCTAssertFalse(prefs.applyScript.contains("document.body.className ="))
        XCTAssertTrue(prefs.applyScript.contains("classList.toggle('no-images'"))
    }

    func test_applyScript_guardsImagePageBody() {
        let prefs = ReaderPreferences()
        // The no-images toggle is skipped for image-page bodies.
        XCTAssertTrue(prefs.applyScript.contains("image-page"))
    }

    func test_applyScript_stillSetsThemeAndFontForAllPages() {
        let prefs = ReaderPreferences()
        prefs.fontSize = 20
        let script = prefs.applyScript
        // Theme background + font padding must run regardless of body class — no early return.
        XCTAssertTrue(script.contains("backgroundColor"))
        XCTAssertTrue(script.contains("paddingTop"))
        XCTAssertTrue(script.contains("20px"))
    }
}
