import XCTest
@testable import LiquidNews

final class DetailModeMappingTests: XCTestCase {

    func test_openComments_mapsToComments() {
        XCTAssertEqual(DetailMode.forSelection(action: .openComments, hasURL: true), .comments)
        XCTAssertEqual(DetailMode.forSelection(action: .openComments, hasURL: false), .comments)
    }

    func test_openReader_withURL_mapsToReader() {
        XCTAssertEqual(DetailMode.forSelection(action: .openReader, hasURL: true), .reader)
    }

    func test_openReader_withoutURL_fallsBackToComments() {
        XCTAssertEqual(DetailMode.forSelection(action: .openReader, hasURL: false), .comments)
    }

    func test_openBrowser_withURL_mapsToBrowser() {
        XCTAssertEqual(DetailMode.forSelection(action: .openBrowser, hasURL: true), .browser)
    }

    func test_openBrowser_withoutURL_fallsBackToComments() {
        XCTAssertEqual(DetailMode.forSelection(action: .openBrowser, hasURL: false), .comments)
    }

    func test_openSafari_mapsToComments_detailFallback() {
        XCTAssertEqual(DetailMode.forSelection(action: .openSafari, hasURL: true), .comments)
    }

    func test_sideEffectActions_returnNil() {
        XCTAssertNil(DetailMode.forSelection(action: .favourite, hasURL: true))
        XCTAssertNil(DetailMode.forSelection(action: .saveLater, hasURL: true))
        XCTAssertNil(DetailMode.forSelection(action: .hide, hasURL: true))
        XCTAssertNil(DetailMode.forSelection(action: .none, hasURL: true))
    }

    func test_select_setsStoryAndMode() {
        let model = iPadNavModel()
        let story = HNItem(id: 42, type: .story, title: "t", url: "https://example.com")
        model.select(story, mode: .reader)
        XCTAssertEqual(model.selectedStory?.id, 42)
        XCTAssertEqual(model.detailMode, .reader)
    }
}
