import XCTest
@testable import Quip

@MainActor
final class GifLibraryTests: XCTestCase {
    private func makeLibrary() -> GifLibrary {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return GifLibrary(defaults: defaults)
    }

    private func gif(_ id: String) -> Gif {
        Gif(id: id, gifURL: "https://example.com/\(id).gif", previewURL: "https://example.com/\(id)_s.gif")
    }

    func testToggleFavoriteAddsThenRemoves() {
        let lib = makeLibrary()
        let g = gif("a")
        XCTAssertFalse(lib.isFavorite(g))
        lib.toggleFavorite(g)
        XCTAssertTrue(lib.isFavorite(g))
        XCTAssertEqual(lib.favorites.count, 1)
        lib.toggleFavorite(g)
        XCTAssertFalse(lib.isFavorite(g))
        XCTAssertTrue(lib.favorites.isEmpty)
    }

    func testAddRecentDedupsAndMovesToFront() {
        let lib = makeLibrary()
        lib.addRecent(gif("a"))
        lib.addRecent(gif("b"))
        lib.addRecent(gif("a")) // re-copying "a" moves it to front, not duplicate
        XCTAssertEqual(lib.recents.map(\.id), ["a", "b"])
    }

    func testRecentsCapEvictsOldest() {
        let lib = makeLibrary()
        for i in 0..<(GifLibrary.recentsLimit + 5) {
            lib.addRecent(gif("g\(i)"))
        }
        XCTAssertEqual(lib.recents.count, GifLibrary.recentsLimit)
        XCTAssertEqual(lib.recents.first?.id, "g\(GifLibrary.recentsLimit + 4)")
        XCTAssertFalse(lib.recents.contains { $0.id == "g0" })
    }

    func testPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let first = GifLibrary(defaults: defaults)
        first.toggleFavorite(gif("fav"))
        first.addRecent(gif("rec"))

        let second = GifLibrary(defaults: defaults)
        XCTAssertTrue(second.isFavorite(gif("fav")))
        XCTAssertEqual(second.recents.map(\.id), ["rec"])
    }
}
