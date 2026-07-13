// ReaderPerfTests.swift
// Empirical performance suite for the reader-page surface.
//
// Two measurable halves of the reader pipeline:
//   1. Document build — ReaderHTMLBuilder.article, the pure app-side work of
//      wrapping extracted content into the styled reader document, across a
//      fixed set of article sizes.
//   2. Extraction — Readability.js run in a real WKWebView over a fixed,
//      deterministic fixture page (loaded via loadHTMLString; no network), the
//      same way ReaderWebView's phase-1 → extraction step does it.
//
// WebKit timings vary with OS/WebKit version, so extraction is REPORT-ONLY:
// assertions check shape (extraction succeeded, chrome was stripped), never
// wall-clock time. Compare medians across runs on the same machine.

import XCTest
import WebKit
@testable import LiquidNews

final class ReaderPerfTests: PerfTestCase {

    // MARK: - Document build (pure CPU)

    /// Building the reader document for small / medium / large articles.
    func test_perf_readerDocumentBuild() async throws {
        let base = URL(string: "https://example.com/article")!
        for (label, paragraphs) in [("small", 30), ("medium", 300), ("large", 1500)] {
            let content = PerfFixtures.articleBodyHTML(paragraphs: paragraphs)
            let kb = content.utf8.count / 1024
            let median = try await medianMS(iterations: 10) { _ in
                let html = ReaderHTMLBuilder.article(
                    title: "Deterministic Fixture Article",
                    byline: "By The Perf Suite",
                    siteName: "Perf Fixtures",
                    content: content,
                    baseURL: base
                )
                XCTAssertTrue(html.contains("<div class=\"content\">"))
                XCTAssertTrue(html.hasSuffix("</html>"))
            }
            record("readerBuild-\(label)", "\(kb) KB body", latencyMS: 0, median: median)
        }
    }

    // MARK: - Readability extraction (real WKWebView, fixture page)

    @MainActor
    func test_perf_readabilityExtraction() async throws {
        // The test host is the app, so the bundled Readability.js is available.
        guard let jsURL = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let readability = try? String(contentsOf: jsURL, encoding: .utf8) else {
            throw XCTSkip("Readability.js not found in the test host bundle")
        }
        let script = readability + "\n" + PerfFixtures.extractionJS

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let waiter = NavigationWaiter()
        webView.navigationDelegate = waiter

        let page = PerfFixtures.articlePageHTML(paragraphs: 250)
        webView.loadHTMLString(page, baseURL: URL(string: "https://example.com/article")!)
        await waiter.waitForFinish()

        // Warm-up + timed runs, mirroring medianMS (kept inline: each sample
        // must also validate the extraction result).
        var samples: [Double] = []
        let clock = ContinuousClock()
        for i in -1 ..< 5 {
            var extracted: [String: Any] = [:]
            let elapsed = try await clock.measure {
                extracted = try await self.runExtraction(script, in: webView)
            }
            XCTAssertNil(extracted["error"],
                         "Readability failed: \(extracted["error"] ?? "?")")
            let content = extracted["content"] as? String ?? ""
            let length = extracted["length"] as? Int ?? 0
            XCTAssertGreaterThan(length, 10_000,
                                 "extraction returned implausibly little article text")
            XCTAssertFalse(content.contains("All rights reserved"),
                           "extraction failed to strip the footer chrome")
            if i >= 0 { samples.append(elapsed.milliseconds) }
        }
        samples.sort()
        record("readabilityExtract", "250 paras", latencyMS: 0,
               median: samples[samples.count / 2])
    }

    @MainActor
    private func runExtraction(_ script: String, in webView: WKWebView) async throws -> [String: Any] {
        let raw: Any? = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value as Any) }
            }
        }
        guard let jsonString = raw as? String,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("could not parse extraction output (got \(type(of: raw)))")
            return ["error": "unparseable"]
        }
        return json
    }
}

// MARK: - Navigation waiter

/// Resolves once WKWebView's didFinish fires for the loadHTMLString navigation.
@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    func waitForFinish() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }
}
