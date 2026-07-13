// StubURLProtocol.swift
// Test-only in-process network stub.
//
// Serves canned HN Firebase-API responses without touching the real network, so
// network-dependent paths (HNAPIService.item/items) can be measured and asserted
// deterministically. Registered globally via `install()`, it intercepts requests
// to `hacker-news.firebaseio.com` and synthesises a plausible item payload for
// `/v0/item/<id>.json`.
//
// A configurable `latency` lets a test simulate different network conditions, and
// `requestCount` lets a test prove cache hits never reached the network.

import Foundation

final class StubURLProtocol: URLProtocol {

    // URLProtocol instances are created per-request by the loading system, so all
    // shared configuration/counters live behind a lock on the type.
    private static let lock = NSLock()
    private static var _latency: TimeInterval = 0
    private static var _requestCount = 0

    /// Artificial per-request delay, simulating a network round-trip.
    static var latency: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return _latency }
        set { lock.lock(); _latency = newValue; lock.unlock() }
    }

    /// Number of requests actually served since the last `reset()`. A measured
    /// loop over warm-cache reads should leave this unchanged.
    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }; return _requestCount
    }

    static func reset() {
        lock.lock(); _requestCount = 0; _latency = 0; lock.unlock()
    }

    static func install() { URLProtocol.registerClass(StubURLProtocol.self) }
    static func uninstall() { URLProtocol.unregisterClass(StubURLProtocol.self) }

    // Delivers delayed responses off the loading thread so concurrent requests
    // actually overlap — a serial `Thread.sleep` here would make N fetches look
    // sequential and mask whether the fetcher parallelises.
    private static let deliveryQueue = DispatchQueue(
        label: "StubURLProtocol.delivery", attributes: .concurrent)
    private var cancelled = false

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("firebaseio.com") ?? false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        let latency = Self._latency
        Self.lock.unlock()

        let deliver = { [weak self] in
            guard let self, !self.cancelled else { return }
            let url = self.request.url!
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Self.itemData(for: url))
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if latency > 0 {
            Self.deliveryQueue.asyncAfter(deadline: .now() + latency, execute: deliver)
        } else {
            Self.deliveryQueue.async(execute: deliver)
        }
    }

    override func stopLoading() { cancelled = true }

    // MARK: - Fixture

    /// Builds a representative HN comment payload for `/v0/item/<id>.json`. The
    /// body is deliberately non-trivial (HTML text + a kids list) so the JSON
    /// decode has realistic cost — decode work is what the actor conversion
    /// serialises, so a toy 3-field item would hide the effect being measured.
    private static func itemData(for url: URL) -> Data {
        let id = Int(url.lastPathComponent.replacingOccurrences(of: ".json", with: "")) ?? 0
        return itemJSON(id: id)
    }

    static func itemJSON(id: Int) -> Data {
        // ~1.5 KB of HTML text, like a substantial HN comment. Built via
        // JSONSerialization so the embedded markup (quotes in href, angle
        // brackets) is escaped correctly and always yields valid JSON.
        let paragraph = "<p>This is a representative Hacker News comment body with a fair "
            + "amount of <i>markup</i> and a <a href=\"https://example.com/some/path\">link</a> "
            + "so that JSON decoding does a realistic amount of work per item.</p>"
        let object: [String: Any] = [
            "id": id,
            "type": "comment",
            "by": "user\(id % 500)",
            "time": 1_600_000_000,
            "parent": max(1, id - 1),
            "kids": (1...8).map { id * 10 + $0 },   // plausible reply ids
            "text": String(repeating: paragraph, count: 6)
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }
}
