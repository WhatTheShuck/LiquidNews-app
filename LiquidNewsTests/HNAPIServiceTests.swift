import XCTest
@testable import LiquidNews

final class HNAPIServiceTests: XCTestCase {

    // MARK: - walkToRoot

    func test_walkToRoot_returnsStoryWithoutFetch() async throws {
        let story = item(id: 1, type: .story, parent: nil)
        let result = try await HNAPIService.walkToRoot(from: story) { _ in
            XCTFail("Should not fetch parent when already a story")
            throw Err.unexpected
        }
        XCTAssertEqual(result.id, 1)
    }

    func test_walkToRoot_walksOneLevel() async throws {
        let story   = item(id: 1, type: .story,   parent: nil)
        let comment = item(id: 2, type: .comment, parent: 1)
        let result = try await HNAPIService.walkToRoot(from: comment) { id in
            XCTAssertEqual(id, 1)
            return story
        }
        XCTAssertEqual(result.id, 1)
    }

    func test_walkToRoot_walksMultipleLevels() async throws {
        let story  = item(id: 1, type: .story,   parent: nil)
        let parent = item(id: 2, type: .comment, parent: 1)
        let child  = item(id: 3, type: .comment, parent: 2)
        let result = try await HNAPIService.walkToRoot(from: child) { id in
            switch id {
            case 2: return parent
            case 1: return story
            default: XCTFail("Unexpected id \(id)"); throw Err.unexpected
            }
        }
        XCTAssertEqual(result.id, 1)
    }

    func test_walkToRoot_throwsWhenOrphaned() async {
        let orphan = item(id: 1, type: .comment, parent: nil)
        do {
            _ = try await HNAPIService.walkToRoot(from: orphan) { _ in throw Err.unexpected }
            XCTFail("Expected RootStoryError.noParent")
        } catch RootStoryError.noParent {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_walkToRoot_treatsJobAsRoot() async throws {
        let job = item(id: 1, type: .job, parent: nil)
        let result = try await HNAPIService.walkToRoot(from: job) { _ in
            XCTFail("Should not fetch for a job item")
            throw Err.unexpected
        }
        XCTAssertEqual(result.id, 1)
    }

    // MARK: - Helpers

    private enum Err: Error { case unexpected }

    private func item(id: Int, type: HNItem.ItemType, parent: Int?) -> HNItem {
        HNItem(id: id, type: type, by: nil, time: nil, title: nil, url: nil,
               score: nil, descendants: nil, text: nil, kids: nil,
               deleted: nil, dead: nil, parent: parent)
    }
}
