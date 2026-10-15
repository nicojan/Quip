import XCTest
import SDWebImage
@testable import Quip

final class GifWarmupTests: XCTestCase {
    private func gifs(_ prefix: String, _ count: Int) -> [Gif] {
        (0..<count).map { Gif(id: "\(prefix)\($0)", gifURL: "https://example.com/\(prefix)\($0).gif",
                              previewURL: "", title: "") }
    }

    /// Enough for every cell the widest layout can show in each strip: five
    /// columns of `rows` rows. Nothing past that, so a long library isn't loaded.
    func testStripsTakeWhatTheWidestLayoutShows() {
        let picked = GifWarmup.stripGifs(favorites: gifs("f", 40), recents: gifs("r", 40), rows: 3)
        XCTAssertEqual(picked.map(\.id), gifs("f", 15).map(\.id) + gifs("r", 15).map(\.id))
    }

    func testShortListsAreTakenWhole() {
        let picked = GifWarmup.stripGifs(favorites: gifs("f", 4), recents: [], rows: 3)
        XCTAssertEqual(picked.map(\.id), ["f0", "f1", "f2", "f3"])
    }

    /// A GIF that's in both strips is loaded once.
    func testDropsDuplicates() {
        let shared = gifs("s", 2)
        let picked = GifWarmup.stripGifs(favorites: shared, recents: shared, rows: 3)
        XCTAssertEqual(picked.map(\.id), ["s0", "s1"])
    }

    /// The grid: as many rows of the widest layout as fit in the popover.
    func testGridTakesTheWidestLayoutsVisibleCells() {
        let picked = GifWarmup.gridGifs(gifs("g", 100), popoverHeight: 700)
        XCTAssertEqual(picked.count, 35)   // 7 rows of 100 pt in 700 pt, 5 across
    }
}

final class GifWarmupOptionsTests: XCTestCase {
    /// Warming must never download: a GIF not yet on disk is skipped.
    func testNetworkGifsAreCacheOnly() {
        XCTAssertTrue(GifWarmup.options(for: URL(string: "https://media.giphy.com/a.gif")!).contains(.fromCacheOnly))
    }

    func testLocalFilesAreRead() {
        XCTAssertFalse(GifWarmup.options(for: URL(fileURLWithPath: "/tmp/a.gif")).contains(.fromCacheOnly))
    }
}
