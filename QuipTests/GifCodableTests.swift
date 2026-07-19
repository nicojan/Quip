import XCTest
@testable import Quip

final class GifCodableTests: XCTestCase {
    func testDecodeToleratesMissingPreviewAndTitle() throws {
        let json = Data(#"{"id":"a","gifURL":"https://x/a.gif"}"#.utf8)
        let gif = try JSONDecoder().decode(Gif.self, from: json)
        XCTAssertEqual(gif.id, "a")
        XCTAssertEqual(gif.previewURL, "https://x/a.gif")   // falls back to gifURL
        XCTAssertEqual(gif.title, "")
    }

    func testDecodeRequiresIdAndGifURL() {
        XCTAssertThrowsError(try JSONDecoder().decode(Gif.self, from: Data(#"{"id":"a"}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(Gif.self, from: Data(#"{"gifURL":"https://x"}"#.utf8)))
    }

    func testRoundTrip() throws {
        let gif = Gif(id: "a", gifURL: "https://x/a.gif", previewURL: "https://x/s.gif", title: "cat")
        let back = try JSONDecoder().decode(Gif.self, from: try JSONEncoder().encode(gif))
        XCTAssertEqual(gif, back)
    }

    func testDedupedByIDKeepsFirstAndPreservesOrder() {
        func gif(_ id: String) -> Gif {
            Gif(id: id, gifURL: "https://x/\(id).gif", previewURL: "https://x/\(id).gif")
        }
        let deduped = [gif("a"), gif("b"), gif("a"), gif("c"), gif("b")].dedupedByID()
        XCTAssertEqual(deduped.map(\.id), ["a", "b", "c"])   // later dups dropped, order intact
    }
}
