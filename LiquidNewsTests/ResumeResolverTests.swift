import XCTest
@testable import LiquidNews

final class ResumeResolverTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func recent(id: Int, install: String, ageDays: Double,
                        kind: DeviceKind = .pad) -> RecentStory {
        RecentStory(id: id, title: "Story \(id)",
                    savedAt: now.addingTimeInterval(-ageDays * 86_400),
                    installID: install, deviceKind: kind)
    }

    private func local(id: Int = 100) -> RecentStory {
        recent(id: id, install: "self", ageDays: 0, kind: .phone)
    }

    func test_nilLocal_returnsNil_regardlessOfCloud() {
        let cloud = [recent(id: 1, install: "peer", ageDays: 1)]
        XCTAssertNil(ResumeResolver.hint(local: nil, cloud: cloud,
                                         thisInstallID: "self", now: now))
    }

    func test_freshDistinctPeer_isReturned() {
        let cloud = [recent(id: 1, install: "peer", ageDays: 1)]
        let hint = ResumeResolver.hint(local: local(), cloud: cloud,
                                       thisInstallID: "self", now: now)
        XCTAssertEqual(hint?.id, 1)
        XCTAssertFalse(hint!.isThisDevice)
        XCTAssertEqual(hint?.deviceName, "iPad")
    }

    func test_sameInstallCloud_returnsNil() {
        let cloud = [recent(id: 1, install: "self", ageDays: 1)]
        XCTAssertNil(ResumeResolver.hint(local: local(), cloud: cloud,
                                         thisInstallID: "self", now: now))
    }

    func test_sameIdAsLocal_returnsNil() {
        let cloud = [recent(id: 100, install: "peer", ageDays: 1)]
        XCTAssertNil(ResumeResolver.hint(local: local(id: 100), cloud: cloud,
                                         thisInstallID: "self", now: now))
    }

    func test_olderThanSevenDays_returnsNil() {
        let cloud = [recent(id: 1, install: "peer", ageDays: 7.5)]
        XCTAssertNil(ResumeResolver.hint(local: local(), cloud: cloud,
                                         thisInstallID: "self", now: now))
    }

    func test_multipleQualifying_picksMostRecent() {
        let cloud = [
            recent(id: 1, install: "peerA", ageDays: 5),
            recent(id: 2, install: "peerB", ageDays: 1),
            recent(id: 3, install: "peerC", ageDays: 3),
        ]
        let hint = ResumeResolver.hint(local: local(), cloud: cloud,
                                       thisInstallID: "self", now: now)
        XCTAssertEqual(hint?.id, 2)
    }

    func test_mixOfQualifyingAndDisqualified_picksMostRecentQualifying() {
        let cloud = [
            recent(id: 100, install: "peerA", ageDays: 0.5),  // disqualified: same id as local
            recent(id: 2,   install: "self",  ageDays: 0.2),  // disqualified: same install
            recent(id: 3,   install: "peerB", ageDays: 2),    // qualifying
            recent(id: 4,   install: "peerC", ageDays: 9),    // disqualified: stale
        ]
        let hint = ResumeResolver.hint(local: local(), cloud: cloud,
                                       thisInstallID: "self", now: now)
        XCTAssertEqual(hint?.id, 3)
    }

    func test_entry_mapsFieldsAndDeviceLabels() {
        let story = recent(id: 9, install: "peer", ageDays: 1, kind: .mac)
        let entry = ResumeResolver.entry(from: story, isThisDevice: false)
        XCTAssertEqual(entry.id, 9)
        XCTAssertEqual(entry.title, "Story 9")
        XCTAssertEqual(entry.savedAt, story.savedAt)
        XCTAssertFalse(entry.isThisDevice)
        XCTAssertEqual(entry.deviceName, "Mac")
        XCTAssertEqual(entry.deviceSymbol, "laptopcomputer")
    }

    func test_entry_nilDeviceKind_fallsBackToOther() {
        let story = RecentStory(id: 5, title: "Legacy", savedAt: now)
        let entry = ResumeResolver.entry(from: story, isThisDevice: true)
        XCTAssertEqual(entry.deviceName, "another device")
        XCTAssertTrue(entry.isThisDevice)
    }
}
