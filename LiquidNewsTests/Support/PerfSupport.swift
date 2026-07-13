// PerfSupport.swift
// Shared machinery + fixtures for the Performance test plan.
//
// PerfTestCase centralises the conventions every perf class follows:
//   • Timings are REPORTED (xcresult attachment + optional PERF_OUT file) for
//     humans; assertions are only ever made on machine-independent quantities.
//   • Each scenario runs a discarded warm-up, then reports the MEDIAN of several
//     iterations (robust to a stray scheduler hiccup).
//
// PerfFixtures provides the fixed, deterministic "set of articles/comments we
// test against" — synthetic but representative HTML, generated from constants
// (no randomness), so every run measures identical input.

import XCTest
@testable import LiquidNews

// MARK: - Base case

class PerfTestCase: XCTestCase {

    private var results: [String] = []

    override func tearDown() {
        // Surface the collected timings: as an Xcode-visible attachment, and — when
        // PERF_OUT is set (used by tooling / CI) — appended to that host file too.
        if !results.isEmpty {
            let text = results.joined(separator: "\n") + "\n"
            let attachment = XCTAttachment(string: text)
            attachment.name = "perf-results"
            attachment.lifetime = .keepAlways
            add(attachment)
            if let path = ProcessInfo.processInfo.environment["PERF_OUT"] {
                let data = Data(text.utf8)
                if let h = FileHandle(forWritingAtPath: path) {
                    h.seekToEndOfFile(); h.write(data); try? h.close()
                } else { try? data.write(to: URL(fileURLWithPath: path)) }
            }
            results = []
        }
        super.tearDown()
    }

    /// Runs `body` once as warm-up (discarded), then `iterations` timed runs;
    /// returns the median elapsed time in milliseconds.
    func medianMS(
        iterations: Int,
        _ body: (_ iteration: Int) async throws -> Void
    ) async rethrows -> Double {
        try await body(-1)
        var samples: [Double] = []
        let clock = ContinuousClock()
        for i in 0 ..< iterations {
            samples.append(try await clock.measure { try await body(i) }.milliseconds)
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    func record(_ scenario: String, _ workload: String, latencyMS: Int, median: Double) {
        let latency = latencyMS < 0 ? "  real" : String(format: "%3dms", latencyMS)
        results.append(String(format: "PERF: %-18@ | %-12@ | latency %@ | median %8.2f ms",
                              scenario as NSString, workload as NSString, latency, median))
    }
}

extension Duration {
    /// Elapsed time in milliseconds.
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}

// MARK: - Fixtures

enum PerfFixtures {

    // A small fixed word bank; content is built by index arithmetic so it is
    // fully deterministic run-to-run.
    private static let words = [
        "performance", "regression", "latency", "throughput", "cache", "decode",
        "concurrency", "executor", "thread", "actor", "swift", "network",
        "measure", "median", "baseline", "release", "profile", "allocation",
    ]

    private static func sentence(_ i: Int, length: Int = 14) -> String {
        (0 ..< length).map { words[(i &* 7 &+ $0 &* 3) % words.count] }
            .joined(separator: " ") + "."
    }

    /// Representative HN comment bodies, cycling through the shapes the
    /// formatters must handle: plain paragraphs, anchors, inline markup with
    /// entities, and quote lines.
    static func commentBodies(count: Int) -> [String] {
        (0 ..< count).map { i in
            switch i % 4 {
            case 0:   // plain multi-paragraph prose
                return "\(sentence(i))<p>\(sentence(i + 1))<p>\(sentence(i + 2))"
            case 1:   // long + short anchors (exercises href extraction)
                return "\(sentence(i)) <a href=\"https://example.com/a/very/long/path/segment-\(i)?q=1\">https://example.com/a/very/long/pa…</a><p>\(sentence(i + 1)) <a href=\"https://news.ycombinator.com/item?id=\(i)\">discussion</a>"
            case 2:   // inline markup + entities
                return "\(sentence(i)) <i>emphasis</i> &amp; <code>let x = y &lt; z</code>&nbsp;\(sentence(i + 1)) &#x27;quoted&#x2F;path&#x27;"
            default:  // HN-style quote followed by a reply
                return "&gt; \(sentence(i))<p>&gt; \(sentence(i + 1))<p>\(sentence(i + 2))"
            }
        }
    }

    /// Readability-extracted-style article body: what `ReaderHTMLBuilder.article`
    /// receives as `content`. Paragraphs with periodic headings, links, code
    /// blocks and quotes, like a substantial technical blog post.
    static func articleBodyHTML(paragraphs: Int) -> String {
        var out: [String] = []
        for i in 0 ..< paragraphs {
            if i % 12 == 0 { out.append("<h2>\(sentence(i, length: 5))</h2>") }
            if i % 17 == 0 {
                out.append("<pre><code>func measure_\(i)() { // \(sentence(i, length: 6))\n    run()\n}</code></pre>")
            }
            if i % 9 == 0 {
                out.append("<blockquote><p>\(sentence(i + 3))</p></blockquote>")
            }
            out.append("<p>\(sentence(i)) <a href=\"https://example.com/ref/\(i)\">reference \(i)</a> \(sentence(i + 1))</p>")
        }
        return out.joined(separator: "\n")
    }

    /// A full "as fetched" web page for the Readability pipeline: the article
    /// wrapped in realistic chrome (nav, sidebar, footer) that extraction must
    /// identify and strip.
    static func articlePageHTML(paragraphs: Int) -> String {
        let navLinks = (0 ..< 12).map { "<a href=\"/section/\($0)\">Section \($0)</a>" }
            .joined(separator: " | ")
        let asideItems = (0 ..< 20).map { "<li><a href=\"/related/\($0)\">\(sentence($0, length: 6))</a></li>" }
            .joined(separator: "\n")
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>Fixture Article — Perf Suite</title>
        <meta property="og:site_name" content="Perf Fixtures">
        <meta name="description" content="A deterministic fixture article for reader perf measurement.">
        </head>
        <body>
        <header><nav>\(navLinks)</nav></header>
        <aside><h3>Related</h3><ul>\(asideItems)</ul></aside>
        <main>
        <article>
        <h1>Deterministic Fixture Article</h1>
        <p class="byline">By The Perf Suite</p>
        \(articleBodyHTML(paragraphs: paragraphs))
        </article>
        </main>
        <footer><nav>\(navLinks)</nav><p>© Fixture. All rights reserved.</p></footer>
        </body>
        </html>
        """
    }

    /// Mirrors the app's extraction call (ReaderWebView's script, minus site
    /// preprocessing): clone the document, run Readability, return JSON.
    static let extractionJS = """
    (function () {
        try {
            if (typeof Readability === 'undefined') {
                return JSON.stringify({ error: 'Readability class not defined' });
            }
            var clone = document.cloneNode(true);
            var article = new Readability(clone, {
                classesToPreserve: ['caption', 'code', 'pre', 'highlight'],
            }).parse();
            if (!article) {
                return JSON.stringify({ error: 'Readability returned null' });
            }
            return JSON.stringify({
                title:   article.title   || document.title,
                content: article.content || '',
                length:  article.length  || 0,
            });
        } catch (e) {
            return JSON.stringify({ error: e.message });
        }
    })();
    """
}
