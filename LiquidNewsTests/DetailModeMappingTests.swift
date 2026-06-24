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

    func test_closeStory_clearsSelectionAndResetsMode() {
        let model = iPadNavModel()
        let story = HNItem(id: 7, type: .story, title: "t", url: "https://example.com")
        model.select(story, mode: .reader)
        model.closeStory()
        XCTAssertNil(model.selectedStory)
        XCTAssertEqual(model.detailMode, .comments)
    }

    // Regression: closing the article from the comments pane while reading side by
    // side must un-collapse the split. The split only reopens when
    // isReaderSideBySideVisible flips to false, which requires the mode reset — not
    // just clearing the selection.
    func test_closeStory_whileReadingSideBySide_makesSplitVisibleAgain() {
        let model = iPadNavModel()
        model.destination = .tab(.feed)
        let story = HNItem(id: 7, type: .story, title: "t", url: "https://example.com")
        model.select(story, mode: .reader)
        XCTAssertTrue(model.isReaderSideBySideVisible(layout: .sideBySide))
        model.closeStory()
        XCTAssertFalse(model.isReaderSideBySideVisible(layout: .sideBySide))
    }

    func test_isReaderSideBySide_trueWhenReaderAndSideBySideLayout() {
        let model = iPadNavModel()
        model.detailMode = .reader
        XCTAssertTrue(model.isReaderSideBySide(layout: .sideBySide))
    }

    func test_isReaderSideBySide_falseWhenReplaceLayout() {
        let model = iPadNavModel()
        model.detailMode = .reader
        XCTAssertFalse(model.isReaderSideBySide(layout: .replace))
    }

    func test_isReaderSideBySide_falseWhenComments() {
        let model = iPadNavModel()
        model.detailMode = .comments
        XCTAssertFalse(model.isReaderSideBySide(layout: .sideBySide))
    }

    func test_isReaderSideBySide_falseWhenBrowser() {
        let model = iPadNavModel()
        model.detailMode = .browser
        XCTAssertFalse(model.isReaderSideBySide(layout: .sideBySide))
    }

    func test_forLinkOpen_reader_mapsToReader() {
        XCTAssertEqual(DetailMode.forLinkOpen(.reader), .reader)
    }

    func test_forLinkOpen_inAppSafari_mapsToBrowser() {
        XCTAssertEqual(DetailMode.forLinkOpen(.inAppSafari), .browser)
    }

    func test_forLinkOpen_safari_returnsNil() {
        XCTAssertNil(DetailMode.forLinkOpen(.safari))
    }

    func test_isReaderSideBySideVisible_trueOnTabWhileReadingSideBySide() {
        let model = iPadNavModel()
        model.destination = .tab(.feed)
        model.detailMode = .reader
        XCTAssertTrue(model.isReaderSideBySideVisible(layout: .sideBySide))
    }

    func test_isReaderSideBySideVisible_falseOnSettingsDestination() {
        let model = iPadNavModel()
        model.destination = .settings
        model.detailMode = .reader
        XCTAssertFalse(model.isReaderSideBySideVisible(layout: .sideBySide))
    }

    func test_isReaderSideBySideVisible_falseOnAccountDestination() {
        let model = iPadNavModel()
        model.destination = .account
        model.detailMode = .reader
        XCTAssertFalse(model.isReaderSideBySideVisible(layout: .sideBySide))
    }

    func test_isReaderSideBySideVisible_falseWhenReplaceLayoutOnTab() {
        let model = iPadNavModel()
        model.destination = .tab(.feed)
        model.detailMode = .reader
        XCTAssertFalse(model.isReaderSideBySideVisible(layout: .replace))
    }
}
