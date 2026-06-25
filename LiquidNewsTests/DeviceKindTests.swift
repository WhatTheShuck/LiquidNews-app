import XCTest
import UIKit
@testable import LiquidNews

final class DeviceKindTests: XCTestCase {

    func test_labelAndSymbol_perCase() {
        XCTAssertEqual(DeviceKind.phone.label, "iPhone")
        XCTAssertEqual(DeviceKind.phone.symbol, "iphone")
        XCTAssertEqual(DeviceKind.pad.label, "iPad")
        XCTAssertEqual(DeviceKind.pad.symbol, "ipad")
        XCTAssertEqual(DeviceKind.mac.label, "Mac")
        XCTAssertEqual(DeviceKind.mac.symbol, "laptopcomputer")
        XCTAssertEqual(DeviceKind.other.label, "another device")
        XCTAssertEqual(DeviceKind.other.symbol, "rectangle.on.rectangle")
    }

    func test_initFromIdiom_mapsKnownIdioms() {
        XCTAssertEqual(DeviceKind(idiom: .phone), .phone)
        XCTAssertEqual(DeviceKind(idiom: .pad), .pad)
        XCTAssertEqual(DeviceKind(idiom: .mac), .mac)
    }

    func test_initFromIdiom_unknownIdiomsAreOther() {
        XCTAssertEqual(DeviceKind(idiom: .tv), .other)
        XCTAssertEqual(DeviceKind(idiom: .unspecified), .other)
    }

    func test_recentStory_decodesLegacyWithoutOriginFields() throws {
        let legacy = #"{"id":1,"title":"Hi","savedAt":0}"#.data(using: .utf8)!
        let story = try JSONDecoder().decode(RecentStory.self, from: legacy)
        XCTAssertEqual(story.id, 1)
        XCTAssertNil(story.installID)
        XCTAssertNil(story.deviceKind)
    }
}
