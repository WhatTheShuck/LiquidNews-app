import XCTest
@testable import LiquidNews

final class HNItemTests: XCTestCase {

    func test_hnItem_decodesParentField() throws {
        let json = #"{"id":42,"type":"comment","parent":1234}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(HNItem.self, from: json)
        XCTAssertEqual(item.parent, 1234)
    }

    func test_hnItem_parentIsNilWhenAbsent() throws {
        let json = #"{"id":42,"type":"story"}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(HNItem.self, from: json)
        XCTAssertNil(item.parent)
    }

    func test_hnItem_customInitDefaultsParentToNil() {
        let item = HNItem(id: 99, type: .story, by: nil, time: nil, title: nil,
                          url: nil, score: nil, descendants: nil, text: nil,
                          kids: nil, deleted: nil, dead: nil)
        XCTAssertNil(item.parent)
    }

    func test_hnItem_customInitAcceptsParent() {
        let item = HNItem(id: 99, type: .comment, by: nil, time: nil, title: nil,
                          url: nil, score: nil, descendants: nil, text: nil,
                          kids: nil, deleted: nil, dead: nil, parent: 55)
        XCTAssertEqual(item.parent, 55)
    }
}
