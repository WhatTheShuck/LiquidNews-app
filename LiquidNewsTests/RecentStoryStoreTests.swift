import XCTest
@testable import LiquidNews

final class RecentStoryStoreTests: XCTestCase {

    /// In-memory stand-in for NSUbiquitousKeyValueStore.
    private final class FakeKVStore: RecentStoryKVStore {
        var storage: [String: Data] = [:]
        func data(forKey key: String) -> Data? { storage[key] }
        func setData(_ data: Data?, forKey key: String) { storage[key] = data }
        func removeObject(forKey key: String) { storage[key] = nil }
        func keys(withPrefix prefix: String) -> [String] {
            storage.keys.filter { $0.hasPrefix(prefix) }
        }
        @discardableResult func synchronize() -> Bool { true }
    }

    private func makeDefaults() -> UserDefaults {
        let name = "RecentStoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func story(id: Int, title: String?) -> HNItem {
        HNItem(id: id, type: .story, title: title, url: "https://example.com")
    }

    /// Encodes a peer device's slot directly into a fake KV store.
    private func seedPeer(_ kv: FakeKVStore, install: String, id: Int, title: String,
                          savedAt: Date = .now) {
        let peer = RecentStory(id: id, title: title, savedAt: savedAt,
                               installID: install, deviceKind: .pad)
        kv.storage["LN_lastStory_\(install)"] = try! JSONEncoder().encode(peer)
    }

    func test_record_storesLocalIdTitleDateAndOrigin() {
        let store = RecentStoryStore(defaults: makeDefaults(), kvStore: FakeKVStore(),
                                     installID: "self")
        store.record(story(id: 42, title: "Hello"))
        XCTAssertEqual(store.lastStory?.id, 42)
        XCTAssertEqual(store.lastStory?.title, "Hello")
        XCTAssertEqual(store.lastStory?.installID, "self")
        XCTAssertNotNil(store.lastStory?.deviceKind)
    }

    func test_record_writesOwnCloudSlotOnly() {
        let kv = FakeKVStore()
        seedPeer(kv, install: "peer", id: 7, title: "Peer story")
        let store = RecentStoryStore(defaults: makeDefaults(), kvStore: kv, installID: "self")
        store.record(story(id: 42, title: "Hello"))
        // Own slot written.
        XCTAssertNotNil(kv.storage["LN_lastStory_self"])
        // Peer slot untouched.
        let peer = try! JSONDecoder().decode(RecentStory.self, from: kv.storage["LN_lastStory_peer"]!)
        XCTAssertEqual(peer.id, 7)
    }

    func test_record_noOpWhenTitleMissingOrBlank() {
        let store = RecentStoryStore(defaults: makeDefaults(), kvStore: FakeKVStore(),
                                     installID: "self")
        store.record(story(id: 3, title: nil))
        XCTAssertNil(store.lastStory)
        store.record(story(id: 4, title: "   "))
        XCTAssertNil(store.lastStory)
    }

    func test_reloadCloudStories_decodesPeersExcludingSelf() {
        let kv = FakeKVStore()
        seedPeer(kv, install: "peerA", id: 1, title: "A")
        seedPeer(kv, install: "peerB", id: 2, title: "B")
        // Own slot present too; must be excluded.
        let store = RecentStoryStore(defaults: makeDefaults(), kvStore: kv, installID: "self")
        store.record(story(id: 99, title: "Mine"))
        store.reloadCloudStories()
        let ids = Set(store.cloudStories.map(\.id))
        XCTAssertEqual(ids, [1, 2])
        XCTAssertFalse(store.cloudStories.contains { $0.installID == "self" })
    }

    func test_clear_removesLocalAndOwnSlot_leavesPeers() {
        let kv = FakeKVStore()
        seedPeer(kv, install: "peer", id: 7, title: "Peer")
        let store = RecentStoryStore(defaults: makeDefaults(), kvStore: kv, installID: "self")
        store.record(story(id: 5, title: "Mine"))
        store.clear()
        XCTAssertNil(store.lastStory)
        XCTAssertNil(kv.storage["LN_lastStory_self"])
        XCTAssertNotNil(kv.storage["LN_lastStory_peer"])
    }

    func test_persistsLocalAcrossInstances() {
        let defaults = makeDefaults()
        let kv = FakeKVStore()
        let first = RecentStoryStore(defaults: defaults, kvStore: kv, installID: "self")
        first.record(story(id: 7, title: "Persisted"))
        let second = RecentStoryStore(defaults: defaults, kvStore: kv, installID: "self")
        XCTAssertEqual(second.lastStory?.id, 7)
    }

    func test_installID_isStableAcrossInstances() {
        let defaults = makeDefaults()
        let first = RecentStoryStore(defaults: defaults, kvStore: FakeKVStore())
        let second = RecentStoryStore(defaults: defaults, kvStore: FakeKVStore())
        XCTAssertEqual(first.installID, second.installID)
        XCTAssertFalse(first.installID.isEmpty)
    }

    func test_clearHistory_alsoClearsRecentStory() {
        RecentStoryStore.shared.record(story(id: 321, title: "To be cleared"))
        XCTAssertNotNil(RecentStoryStore.shared.lastStory)
        SavedPostsStore.shared.clearHistory()
        XCTAssertNil(RecentStoryStore.shared.lastStory)
    }
}
