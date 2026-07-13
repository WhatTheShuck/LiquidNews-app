// CommentsPerfTests.swift
// Empirical performance suite for the story-detail / comments surface.
//
// Complements HNAPIServicePerfTests (raw fetch/decode/cache layer) by measuring
// the pipeline the user actually feels when opening a story: StoryDetailViewModel
// fetches the story, snapshots cached comments (phase 1), then hydrates the
// top-level thread over the network (phase 2) and writes it through HNCache.
// Also measures the comment text formatters (`htmlStripped` / `htmlWithLinks`)
// that run per visible comment.
//
// Not covered here: rich-mode segment parsing (CommentBodyView's private
// NSAttributedString/WebKit path) — it has no test seam; measuring a copy of the
// implementation would not regress with the real one.
//
// Same rules as the rest of the Performance plan: network is stubbed, timings
// are reported (attachment), assertions are machine-independent only.

import XCTest
@testable import LiquidNews

final class CommentsPerfTests: PerfTestCase {

    private let concurrency = 6

    /// Comments per story served by the stub (its fixture gives every item 8 kids).
    private let kidsPerStory = 8

    // Story ids move to a fresh block every run so "cold" is cold in the
    // persistent HNCache (L2) too, not just the per-process L1.
    private static var nextID = 5_000_000_000
        + (Int(Date().timeIntervalSince1970) % 900_000) * 1_000

    private func coldStory() -> HNItem {
        Self.nextID += 1
        return HNItem(id: Self.nextID, type: .story)
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        StubURLProtocol.reset()
        UserSettings.shared.maxConcurrentFetchesWifi = concurrency
        UserSettings.shared.maxConcurrentFetchesCellular = concurrency
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Reported scenarios (timings only; no absolute-time asserts)

    /// First open of a story: story fetch + cache snapshot + thread hydration.
    func test_perf_openStory_coldThread() async throws {
        try XCTSkipUnless(NetworkMonitor.shared.currentlyOnline(),
                          "phase-2 hydration requires the (stubbed) network path")
        for latencyMS in [0, 5, 25] {
            StubURLProtocol.latency = Double(latencyMS) / 1000
            let median = try await medianMS(iterations: 8) { _ in
                let vm = StoryDetailViewModel(story: self.coldStory())
                await vm.loadComments()
                XCTAssertNil(vm.errorMessage)
                XCTAssertEqual(vm.comments.count, self.kidsPerStory)
            }
            record("openStoryCold", "1+\(kidsPerStory) items", latencyMS: latencyMS, median: median)
        }
    }

    /// Re-opening a story already in cache: phase 1 serves the cached thread,
    /// phase 2 revalidates. This is the "back into a thread" cost.
    func test_perf_openStory_warmRevisit() async throws {
        try XCTSkipUnless(NetworkMonitor.shared.currentlyOnline(),
                          "phase-2 revalidation requires the (stubbed) network path")
        StubURLProtocol.latency = 0
        let vm = StoryDetailViewModel(story: coldStory())
        await vm.loadComments()                       // populate L1/L2
        let median = try await medianMS(iterations: 8) { _ in
            await vm.loadComments()
            XCTAssertEqual(vm.comments.count, self.kidsPerStory)
        }
        record("openStoryWarm", "1+\(kidsPerStory) items", latencyMS: 0, median: median)
    }

    /// Per-comment text formatting, as run for every visible comment in the two
    /// plain render modes. Pure CPU; reported per batch of bodies.
    func test_perf_commentFormatting_textModes() async throws {
        let bodies = PerfFixtures.commentBodies(count: 400)

        let stripped = try await medianMS(iterations: 8) { _ in
            for b in bodies { _ = b.htmlStripped }
        }
        record("fmtTextOnly", "\(bodies.count) bodies", latencyMS: 0, median: stripped)

        let withLinks = try await medianMS(iterations: 8) { _ in
            for b in bodies { _ = b.htmlWithLinks }
        }
        record("fmtTextWithLinks", "\(bodies.count) bodies", latencyMS: 0, median: withLinks)
    }

    // MARK: - Regression guard (machine-independent assert)

    /// Opening a story is one item fetch + one batched thread hydration. With an
    /// injected latency L the story fetch costs ≈L, but the thread batch must
    /// overlap — total time must stay far under the serial bound (1+N)·L. Fails if
    /// the view-model path ever hydrates comments one-by-one (or the fetcher's
    /// concurrency breaks upstream of it).
    ///
    /// Bound math: 8 comments at concurrency 6 hydrate in 2 waves, so the
    /// concurrent floor is 3·L (+ fixed cache/scheduling overhead, ~50ms on a
    /// simulator) vs 9·L serial. 0.7·serial sits well above the floor and well
    /// below the ≥1.0·serial a one-by-one regression produces.
    func test_openStory_hydratesConcurrently() async throws {
        try XCTSkipUnless(NetworkMonitor.shared.currentlyOnline(),
                          "phase-2 hydration requires the (stubbed) network path")
        let latency = 0.05                            // 50 ms per request
        StubURLProtocol.latency = latency

        let vm = StoryDetailViewModel(story: coldStory())
        let clock = ContinuousClock()
        let elapsed = await clock.measure { await vm.loadComments() }
        let ms = elapsed.milliseconds

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.comments.count, kidsPerStory)

        let serialMS = Double(1 + kidsPerStory) * latency * 1000    // 450 ms
        record("openStoryConcurr", "1+\(kidsPerStory) items", latencyMS: 50, median: ms)
        XCTAssertLessThan(ms, serialMS * 0.7,
            "cold story open took \(Int(ms))ms — near-serial (serial≈\(Int(serialMS))ms); "
            + "thread hydration appears to have lost its concurrency")
    }
}
