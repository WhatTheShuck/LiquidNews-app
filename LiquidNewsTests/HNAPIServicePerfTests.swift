// HNAPIServicePerfTests.swift
// Empirical performance suite for the HN fetch / decode / cache path.
//
// Purpose: give slowdowns a number and fail loudly if a structural regression
// (like routing every cache read through an actor hop) comes back. These are
// heavier, timing-based tests: they live in the `Performance` test plan and are
// meant to run on demand — before a release, or when changing HNAPIService / the
// cache path — NOT on every commit. The default test plan skips this class.
//
// Design for "always compares correctly":
//   • The network is stubbed (StubURLProtocol) so what's measured is app-side
//     work — JSON decode, cache access, cross-actor hops — not the internet.
//   • Timing is reported (as an attachment) for humans, but ASSERTIONS are made
//     on machine-independent quantities: ratios and bounds derived from the
//     latency we inject, never absolute wall-clock thresholds.
//   • Each scenario runs a discarded warm-up, then reports the MEDIAN of several
//     iterations (robust to a stray scheduler hiccup).
//   • Latency tiers stand in for network conditions; because they're injected,
//     the "does it parallelise" bound holds regardless of how fast the host is.

import XCTest
@testable import LiquidNews

final class HNAPIServicePerfTests: PerfTestCase {

    private let service = HNAPIService.shared
    private let concurrency = 6

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        StubURLProtocol.reset()
        // Pin concurrency so the fetcher's WiFi/cellular branch is deterministic
        // regardless of the simulator's reported network path.
        UserSettings.shared.maxConcurrentFetchesWifi = concurrency
        UserSettings.shared.maxConcurrentFetchesCellular = concurrency
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Reported scenarios (timings only; no absolute-time asserts)

    /// Initial feed load — a cold batch of ~30 items, across latency tiers.
    func test_perf_coldFeedLoad() async throws {
        for latencyMS in [0, 5, 25] {
            StubURLProtocol.latency = Double(latencyMS) / 1000
            let median = try await medianMS(iterations: 10) { iteration in
                let ids = coldIDs(scenario: 1, latencyMS: latencyMS, iteration: iteration, count: 30)
                let items = try await self.service.items(ids: ids)
                XCTAssertEqual(items.count, 30)
            }
            record("coldFeedLoad", "30 items", latencyMS: latencyMS, median: median)
        }
    }

    /// Large comment-thread hydration — a cold batch of ~150 items.
    func test_perf_coldLargeThread() async throws {
        for latencyMS in [0, 5] {
            StubURLProtocol.latency = Double(latencyMS) / 1000
            let median = try await medianMS(iterations: 6) { iteration in
                let ids = coldIDs(scenario: 2, latencyMS: latencyMS, iteration: iteration, count: 150)
                let items = try await self.service.items(ids: ids)
                XCTAssertEqual(items.count, 150)
            }
            record("coldLargeThread", "150 items", latencyMS: latencyMS, median: median)
        }
    }

    // MARK: - Regression guards (machine-independent asserts)

    /// Scrolling a warm thread re-reads already-cached items many times. Each read
    /// should return on the caller's thread, not pay a cross-actor hop. Guard: the
    /// amortised per-read cost stays well under a microsecond-scale ceiling that an
    /// async hop (microseconds each) would blow through. This is the test that
    /// fails if HNAPIService is ever turned back into an actor.
    func test_warmCacheScroll_staysInline() async throws {
        StubURLProtocol.latency = 0
        let pool = Array(30_000_000 ..< 30_000_200)
        _ = try await service.items(ids: pool)      // warm L1
        StubURLProtocol.reset()

        let reads = 4_000
        let median = try await medianMS(iterations: 8) { _ in
            for i in 0 ..< reads {
                _ = try await self.service.item(id: pool[i % pool.count])
            }
        }
        record("warmCacheScroll", "\(reads) reads", latencyMS: 0, median: median)

        XCTAssertEqual(StubURLProtocol.requestCount, 0,
                       "warm-cache scroll unexpectedly hit the network")
        let perReadUS = median * 1000 / Double(reads)
        // ~0.2µs when inline; a per-read actor hop was ~18µs. 5µs leaves a wide
        // margin for slower CI hosts while still catching a reintroduced hop.
        XCTAssertLessThan(perReadUS, 5.0,
            "warm cache read cost \(String(format: "%.2f", perReadUS))µs/read — a per-read "
            + "actor hop or lock-contention regression has likely been reintroduced")
    }

    /// A batch of N fetches at injected latency L, with a concurrency limit of C,
    /// must complete far faster than running them serially (≈N·L). This proves the
    /// fetcher parallelises and that decode isn't serialised behind one executor.
    /// The bound is derived from the injected latency, so it holds on any host.
    func test_batchFetch_runsConcurrently() async throws {
        let latency = 0.02                          // 20 ms per request
        StubURLProtocol.latency = latency
        let n = 60
        let ids = Array(40_000_000 ..< 40_000_000 + n)

        let clock = ContinuousClock()
        let elapsed = try await clock.measure { _ = try await service.items(ids: ids) }
        let ms = elapsed.milliseconds

        let serialMS = Double(n) * latency * 1000               // 1200 ms
        let idealMS = Double(n) / Double(concurrency) * latency * 1000  // 200 ms
        record("batchConcurrency", "\(n) items", latencyMS: 20, median: ms)

        XCTAssertLessThan(ms, serialMS * 0.5,
            "batch of \(n) took \(Int(ms))ms — near-serial (serial≈\(Int(serialMS))ms, "
            + "ideal≈\(Int(idealMS))ms); fetch concurrency appears broken")
    }

    // MARK: - Opt-in real-network smoke test (set PERF_REALNET=1)

    /// Realistic end-to-end timing against live HN for a fixed set of stories.
    /// Skipped unless PERF_REALNET=1 so normal/CI runs never depend on the network.
    /// Asserts only completion + shape (wide tolerance, warm-up run) — never a hard
    /// time, since real latency is uncontrolled.
    func test_realNetwork_feedLoad() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PERF_REALNET"] == "1",
                          "real-network perf test is opt-in (set PERF_REALNET=1)")
        StubURLProtocol.uninstall()               // hit the real internet
        defer { StubURLProtocol.install() }

        // A fixed, stable set of well-known historical HN story IDs.
        let ids = [1, 8863, 121003, 192327, 2921983, 9224, 100000, 10000000]
        _ = try await service.items(ids: ids)     // warm-up (network + cache)
        let clock = ContinuousClock()
        let elapsed = try await clock.measure { _ = try await service.items(ids: ids) }
        record("realNetwork(warm)", "\(ids.count) items", latencyMS: -1,
               median: elapsed.milliseconds)
        // Second pass is fully cached, so it must be quick even on a slow link.
        XCTAssertLessThan(elapsed.milliseconds, 500,
                          "warm real-network re-fetch should be served from cache")
    }

    // MARK: - Helpers

    /// A disjoint id block per (scenario, tier, iteration) so "cold" stays cold —
    /// the session cache never sees the same id twice across runs.
    private func coldIDs(scenario: Int, latencyMS: Int, iteration: Int, count: Int) -> [Int] {
        let base = scenario * 100_000_000 + latencyMS * 1_000_000 + (iteration + 1) * 1_000
        return Array(base ..< base + count)
    }
}
