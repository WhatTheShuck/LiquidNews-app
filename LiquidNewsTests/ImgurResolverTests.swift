import XCTest
@testable import LiquidNews

final class ImgurResolverTests: XCTestCase {

    // MARK: - handles

    func test_handles_acceptsBareImgur() {
        XCTAssertTrue(ImgurResolver.handles(URL(string: "https://imgur.com/abc1234")!))
    }

    func test_handles_acceptsWwwImgur() {
        XCTAssertTrue(ImgurResolver.handles(URL(string: "https://www.imgur.com/gallery/abc1234")!))
    }

    func test_handles_acceptsDirectImageHost() {
        XCTAssertTrue(ImgurResolver.handles(URL(string: "https://i.imgur.com/abc1234.jpg")!))
    }

    func test_handles_acceptsMobileHost() {
        XCTAssertTrue(ImgurResolver.handles(URL(string: "https://m.imgur.com/abc1234")!))
    }

    func test_handles_rejectsNonImgur() {
        XCTAssertFalse(ImgurResolver.handles(URL(string: "https://example.com/imgur.com")!))
    }

    func test_handles_rejectsLookalikeSuffix() {
        // "notimgur.com" must NOT match — suffix check must be on a dot boundary.
        XCTAssertFalse(ImgurResolver.handles(URL(string: "https://notimgur.com/abc")!))
    }

    // MARK: - directImage

    func test_directImage_detectsJpg() {
        let url = URL(string: "https://i.imgur.com/abc1234.jpg")!
        XCTAssertEqual(ImgurResolver.directImage(for: url), url)
    }

    func test_directImage_detectsAllStillExtensions() {
        for ext in ["jpg", "jpeg", "png", "gif", "webp"] {
            let url = URL(string: "https://i.imgur.com/abc1234.\(ext)")!
            XCTAssertEqual(ImgurResolver.directImage(for: url), url, "ext \(ext)")
        }
    }

    func test_directImage_isCaseInsensitiveOnExtension() {
        let url = URL(string: "https://i.imgur.com/abc1234.PNG")!
        XCTAssertEqual(ImgurResolver.directImage(for: url), url)
    }

    func test_directImage_rejectsGifvAndMp4() {
        // Video wrappers are out of scope for v1 — fall through to the normal flow.
        XCTAssertNil(ImgurResolver.directImage(for: URL(string: "https://i.imgur.com/abc1234.gifv")!))
        XCTAssertNil(ImgurResolver.directImage(for: URL(string: "https://i.imgur.com/abc1234.mp4")!))
    }

    func test_directImage_rejectsPostPage() {
        XCTAssertNil(ImgurResolver.directImage(for: URL(string: "https://imgur.com/abc1234")!))
    }

    // MARK: - isValidImageURL

    func test_isValidImageURL_acceptsHttpsImgur() {
        XCTAssertTrue(ImgurResolver.isValidImageURL(URL(string: "https://i.imgur.com/abc1234.jpg")!))
    }

    func test_isValidImageURL_rejectsNonHttpScheme() {
        XCTAssertFalse(ImgurResolver.isValidImageURL(URL(string: "javascript:alert(1)//.imgur.com")!))
        XCTAssertFalse(ImgurResolver.isValidImageURL(URL(string: "data:image/png;base64,AAAA")!))
    }

    func test_isValidImageURL_rejectsNonImgurHost() {
        XCTAssertFalse(ImgurResolver.isValidImageURL(URL(string: "https://evil.example.com/x.jpg")!))
    }
}

extension ImgurResolverTests {

    // Builds a fetch seam that returns the given HTML for any request.
    private func stubFetch(html: String) -> ImgurResolver.Fetch {
        { request in
            let data = Data(html.utf8)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "text/html"]
            )!
            return (data, response)
        }
    }

    private var failingFetch: ImgurResolver.Fetch { { _ in nil } }

    // MARK: - resolve: direct image (no network)

    func test_resolve_directImage_returnsImmediately() async {
        let url = URL(string: "https://i.imgur.com/abc1234.png")!
        let content = await ImgurResolver.resolve(url, fetch: failingFetch)
        XCTAssertEqual(content, ImgurContent(title: nil, images: [url]))
    }

    // MARK: - parseOpenGraph

    func test_parseOpenGraph_singleImageWithTitle() {
        let html = """
        <meta property="og:title" content="A cat">
        <meta property="og:image" content="https://i.imgur.com/abc1234.jpg">
        """
        let content = ImgurResolver.parseOpenGraph(html)
        XCTAssertEqual(content?.title, "A cat")
        XCTAssertEqual(content?.images, [URL(string: "https://i.imgur.com/abc1234.jpg")!])
    }

    func test_parseOpenGraph_multipleImagesDedupedInOrder() {
        let html = """
        <meta property="og:image" content="https://i.imgur.com/one.jpg">
        <meta property="og:image" content="https://i.imgur.com/two.jpg">
        <meta property="og:image" content="https://i.imgur.com/one.jpg">
        """
        let content = ImgurResolver.parseOpenGraph(html)
        XCTAssertEqual(content?.images, [
            URL(string: "https://i.imgur.com/one.jpg")!,
            URL(string: "https://i.imgur.com/two.jpg")!,
        ])
    }

    func test_parseOpenGraph_noImagesReturnsNil() {
        let html = "<meta property=\"og:title\" content=\"No image here\">"
        XCTAssertNil(ImgurResolver.parseOpenGraph(html))
    }

    func test_parseOpenGraph_titleOptionalWhenAbsent() {
        let html = "<meta property=\"og:image\" content=\"https://i.imgur.com/abc1234.jpg\">"
        let content = ImgurResolver.parseOpenGraph(html)
        XCTAssertNil(content?.title)
        XCTAssertEqual(content?.images.count, 1)
    }

    func test_parseOpenGraph_rejectsNonImgurOgImage() {
        let html = """
        <meta property="og:title" content="t">
        <meta property="og:image" content="https://evil.example.com/x.jpg">
        """
        // The only og:image is foreign → no valid images → nil.
        XCTAssertNil(ImgurResolver.parseOpenGraph(html))
    }

    // MARK: - resolve: page fetch through the seam

    func test_resolve_pageFetch_parsesOg() async {
        let html = """
        <meta property="og:title" content="Gallery">
        <meta property="og:image" content="https://i.imgur.com/cover.jpg">
        """
        let url = URL(string: "https://imgur.com/gallery/abc1234")!
        let content = await ImgurResolver.resolve(url, fetch: stubFetch(html: html))
        XCTAssertEqual(content?.title, "Gallery")
        XCTAssertEqual(content?.images, [URL(string: "https://i.imgur.com/cover.jpg")!])
    }

    func test_resolve_fetchFailureReturnsNil() async {
        let url = URL(string: "https://imgur.com/gallery/abc1234")!
        let content = await ImgurResolver.resolve(url, fetch: failingFetch)
        XCTAssertNil(content)
    }
}

extension ImgurResolverTests {

    // MARK: - classicPostID

    func test_classicPostID_extractsSevenCharID() {
        XCTAssertEqual(ImgurResolver.classicPostID(from: URL(string: "https://imgur.com/aBc1234")!), "aBc1234")
    }

    func test_classicPostID_rejectsAlbumPath() {
        XCTAssertNil(ImgurResolver.classicPostID(from: URL(string: "https://imgur.com/a/aBc1234")!))
    }

    func test_classicPostID_rejectsGalleryPath() {
        XCTAssertNil(ImgurResolver.classicPostID(from: URL(string: "https://imgur.com/gallery/aBc1234")!))
    }

    func test_classicPostID_rejectsDirectImageHost() {
        XCTAssertNil(ImgurResolver.classicPostID(from: URL(string: "https://i.imgur.com/aBc1234.jpg")!))
    }

    // MARK: - resolve: construction fallback on og miss

    func test_resolve_constructsImageWhenOgMissesOnClassicPost() async {
        // og fetch returns image-less HTML; the constructed i.imgur.com/{id}.jpg
        // then validates (image content-type) and is returned.
        let fetch: ImgurResolver.Fetch = { request in
            let url = request.url!
            if url.host == "i.imgur.com" {
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "image/jpeg"])!
                return (Data([0xFF, 0xD8]), resp)   // JPEG magic bytes
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "text/html"])!
            return (Data("<html>no og here</html>".utf8), resp)
        }
        let content = await ImgurResolver.resolve(URL(string: "https://imgur.com/aBc1234")!, fetch: fetch)
        XCTAssertEqual(content?.images, [URL(string: "https://i.imgur.com/aBc1234.jpg")!])
        XCTAssertNil(content?.title)
    }

    func test_resolve_constructionFallbackNotUsedForAlbum() async {
        // /a/ has no classic post id → og miss returns nil, no construction attempt.
        let fetch: ImgurResolver.Fetch = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "text/html"])!
            return (Data("<html>no og</html>".utf8), resp)
        }
        let content = await ImgurResolver.resolve(URL(string: "https://imgur.com/a/aBc1234")!, fetch: fetch)
        XCTAssertNil(content)
    }
}
