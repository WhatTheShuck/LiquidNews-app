import XCTest
@testable import LiquidNews

final class ReaderHTMLBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func gallery(title: String?, _ images: [String]) -> String {
        let urls = images.map { URL(string: $0)! }
        return ReaderHTMLBuilder.gallery(
            content: ImgurContent(title: title, images: urls),
            baseURL: URL(string: "https://imgur.com/a/abc")!)
    }

    // MARK: - Article tests

    func test_article_emitsNoImagesBodyClass() {
        let html = ReaderHTMLBuilder.article(
            title: "Hello", byline: nil, siteName: "Example",
            content: "<p>Body</p>", baseURL: URL(string: "https://example.com")!
        )
        XCTAssertTrue(html.contains("<body class=\"no-images\">"))
        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
        XCTAssertTrue(html.contains("<p>Body</p>"))
    }

    func test_article_escapesTitle() {
        let html = ReaderHTMLBuilder.article(
            title: "a \"quote\" & <tag>", byline: nil, siteName: nil,
            content: "", baseURL: URL(string: "https://example.com")!
        )
        XCTAssertTrue(html.contains("a &quot;quote&quot; &amp; &lt;tag&gt;"))
    }

    // MARK: - Gallery tests (body class, site label, title, images)

    func test_gallery_usesImagePageBodyClass() {
        let content = ImgurContent(title: "Cat", images: [URL(string: "https://i.imgur.com/a.jpg")!])
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: URL(string: "https://imgur.com/a")!)
        XCTAssertTrue(html.contains("<body class=\"image-page\">"))
        XCTAssertFalse(html.contains("<body class=\"no-images\">"))
    }

    func test_gallery_emitsOneImgPerImage() {
        let content = ImgurContent(title: nil, images: [
            URL(string: "https://i.imgur.com/a.jpg")!,
            URL(string: "https://i.imgur.com/b.jpg")!,
        ])
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: URL(string: "https://imgur.com/a")!)
        XCTAssertTrue(html.contains("src=\"https://i.imgur.com/a.jpg\""))
        XCTAssertTrue(html.contains("src=\"https://i.imgur.com/b.jpg\""))
    }

    func test_gallery_showsImgurSiteLabel() {
        let content = ImgurContent(title: nil, images: [URL(string: "https://i.imgur.com/a.jpg")!])
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: URL(string: "https://imgur.com/a")!)
        XCTAssertTrue(html.contains(">Imgur<"))
    }

    func test_gallery_escapesAttackerTitle() {
        let content = ImgurContent(title: "x\"><script>alert(1)</script>",
                                   images: [URL(string: "https://i.imgur.com/a.jpg")!])
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: URL(string: "https://imgur.com/a")!)
        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func test_gallery_omitsTitleHeadingWhenNil() {
        let content = ImgurContent(title: nil, images: [URL(string: "https://i.imgur.com/a.jpg")!])
        let html = ReaderHTMLBuilder.gallery(content: content, baseURL: URL(string: "https://imgur.com/a")!)
        XCTAssertFalse(html.contains("<h1>"))
    }

    // MARK: - Gallery anchor-wrap tests (Task 2)

    func test_gallery_wrapsEachImageInAnchor() {
        let html = gallery(title: "Cats", [
            "https://i.imgur.com/a.jpg",
            "https://i.imgur.com/b.png",
        ])
        XCTAssertTrue(html.contains(
            "<a class=\"ln-img\" href=\"https://i.imgur.com/a.jpg\" aria-label=\"Image 1 of 2\">"))
        XCTAssertTrue(html.contains("<img src=\"https://i.imgur.com/a.jpg\" alt=\"\">"))
        XCTAssertTrue(html.contains("aria-label=\"Image 2 of 2\""))
    }

    func test_gallery_escapesTitle() {
        let html = gallery(title: "<script>evil</script>", ["https://i.imgur.com/a.jpg"])
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>evil"))
    }

    func test_gallery_keepsImagePageBodyClass() {
        let html = gallery(title: nil, ["https://i.imgur.com/a.jpg"])
        XCTAssertTrue(html.contains("class=\"image-page\""))
    }
}
