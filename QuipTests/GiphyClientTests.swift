import XCTest
@testable import Quip

final class GiphyClientTests: XCTestCase {
    func testSearchURLEncodesQueryAndParams() throws {
        let url = try GiphyClient.searchURL(query: "cat worried", apiKey: "KEY123")
        let comps = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(comps.host, "api.giphy.com")
        XCTAssertEqual(comps.path, "/v1/gifs/search")
        XCTAssertEqual(items["q"], "cat worried")
        XCTAssertEqual(items["api_key"], "KEY123")
        XCTAssertEqual(items["limit"], "36")
        XCTAssertEqual(items["rating"], "pg-13")
        // The space must be percent-encoded in the raw URL string.
        XCTAssertTrue(url.absoluteString.contains("cat%20worried"))
    }

    func testGifParsingFromGiphyDict() {
        let dict: [String: Any] = [
            "id": "abc",
            "title": "a cat",
            "images": [
                "fixed_width": ["url": "https://media.giphy.com/abc/200w.gif"],
                "fixed_width_still": ["url": "https://media.giphy.com/abc/200w_s.gif"],
            ],
        ]
        let gif = Gif(giphy: dict)
        XCTAssertEqual(gif?.id, "abc")
        XCTAssertEqual(gif?.gifURL, "https://media.giphy.com/abc/200w.gif")
        XCTAssertEqual(gif?.previewURL, "https://media.giphy.com/abc/200w_s.gif")
        XCTAssertEqual(gif?.title, "a cat")
    }

    func testGifPreviewFallsBackToGifURL() {
        let dict: [String: Any] = [
            "id": "no-still",
            "images": ["fixed_width": ["url": "https://media.giphy.com/x/200w.gif"]],
        ]
        let gif = Gif(giphy: dict)
        XCTAssertEqual(gif?.previewURL, "https://media.giphy.com/x/200w.gif")
    }

    func testGifParsingRejectsMalformed() {
        XCTAssertNil(Gif(giphy: ["id": "x"]))                 // no images
        XCTAssertNil(Gif(giphy: ["images": [:]]))             // no id
    }
}
