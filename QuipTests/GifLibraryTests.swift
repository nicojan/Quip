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

    func testFavoritesCapDropsOldest() {
        let lib = makeLibrary()
        for i in 0..<(GifLibrary.favoritesLimit + 3) {
            lib.toggleFavorite(gif("f\(i)"))
        }
        XCTAssertEqual(lib.favorites.count, GifLibrary.favoritesLimit)
        XCTAssertEqual(lib.favorites.first?.id, "f\(GifLibrary.favoritesLimit + 2)") // newest first
        XCTAssertFalse(lib.favorites.contains { $0.id == "f0" })                      // oldest dropped
    }

    func testLoadToleratesOneBadRecord() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let good1: [String: Any] = ["id": "g1", "gifURL": "https://x/1.gif", "previewURL": "https://x/1.gif", "title": ""]
        let bad: [String: Any] = ["id": "b"]  // missing gifURL — undecodable
        let good2: [String: Any] = ["id": "g2", "gifURL": "https://x/2.gif", "previewURL": "https://x/2.gif", "title": ""]
        let data = try! JSONSerialization.data(withJSONObject: [good1, bad, good2])
        defaults.set(data, forKey: "favoriteGifs")

        let lib = GifLibrary(defaults: defaults)
        XCTAssertEqual(lib.favorites.map(\.id), ["g1", "g2"])  // bad record skipped, rest survive
    }

    // MARK: - Collections

    func testCreateCollectionAddsNamed() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Reactions")
        XCTAssertNotNil(c)
        XCTAssertEqual(lib.collections.map(\.name), ["Reactions"])
    }

    func testCreateCollectionTrimsAndRejectsBlankName() {
        let lib = makeLibrary()
        XCTAssertNil(lib.createCollection(named: "   "))
        XCTAssertTrue(lib.collections.isEmpty)
        let c = lib.createCollection(named: "  Work  ")
        XCTAssertEqual(c?.name, "Work")   // trimmed
    }

    func testRenameCollection() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Work")!
        lib.renameCollection(c.id, to: "Job")
        XCTAssertEqual(lib.collections.first?.name, "Job")
    }

    func testRenameCollectionIgnoresBlank() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Work")!
        lib.renameCollection(c.id, to: "   ")
        XCTAssertEqual(lib.collections.first?.name, "Work")
    }

    func testDeleteCollection() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Work")!
        lib.deleteCollection(c.id)
        XCTAssertTrue(lib.collections.isEmpty)
    }

    func testSetMembershipAddsThenRemoves() {
        let lib = makeLibrary()
        let g = gif("a")
        lib.toggleFavorite(g)
        let c = lib.createCollection(named: "Reactions")!
        lib.setMembership(g, inCollection: c.id, member: true)
        XCTAssertTrue(lib.isMember(g, ofCollection: c.id))
        lib.setMembership(g, inCollection: c.id, member: false)
        XCTAssertFalse(lib.isMember(g, ofCollection: c.id))
    }

    func testSetMembershipDedupes() {
        let lib = makeLibrary()
        let g = gif("a")
        lib.toggleFavorite(g)
        let c = lib.createCollection(named: "R")!
        lib.setMembership(g, inCollection: c.id, member: true)
        lib.setMembership(g, inCollection: c.id, member: true)
        XCTAssertEqual(lib.collections.first?.gifIDs, ["a"])
    }

    func testAddingMembershipAutoFavourites() {
        let lib = makeLibrary()
        let g = gif("a")   // not favourited yet
        let c = lib.createCollection(named: "R")!
        lib.setMembership(g, inCollection: c.id, member: true)
        XCTAssertTrue(lib.isFavorite(g))
        XCTAssertTrue(lib.isMember(g, ofCollection: c.id))
    }

    func testUnfavouriteCascadesRemovalFromCollections() {
        let lib = makeLibrary()
        let g = gif("a")
        lib.toggleFavorite(g)
        let c = lib.createCollection(named: "R")!
        lib.setMembership(g, inCollection: c.id, member: true)
        lib.toggleFavorite(g)   // un-favourite
        XCTAssertFalse(lib.isFavorite(g))
        XCTAssertFalse(lib.isMember(g, ofCollection: c.id))
    }

    func testUnfavouriteCascadesAcrossMultipleCollections() {
        let lib = makeLibrary()
        let g = gif("a")
        lib.toggleFavorite(g)
        let c1 = lib.createCollection(named: "One")!
        let c2 = lib.createCollection(named: "Two")!
        lib.setMembership(g, inCollection: c1.id, member: true)
        lib.setMembership(g, inCollection: c2.id, member: true)
        lib.toggleFavorite(g)   // un-favourite
        XCTAssertFalse(lib.isMember(g, ofCollection: c1.id))
        XCTAssertFalse(lib.isMember(g, ofCollection: c2.id))
    }

    func testCapEvictionCascadesOutOfCollections() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "R")!
        let old = gif("old")
        lib.toggleFavorite(old)
        lib.setMembership(old, inCollection: c.id, member: true)
        XCTAssertTrue(lib.isMember(old, ofCollection: c.id))
        // Favoriting past the cap evicts the oldest ("old"); it must not linger
        // as an orphan id in the collection.
        for i in 0..<GifLibrary.favoritesLimit {
            lib.toggleFavorite(gif("n\(i)"))
        }
        XCTAssertFalse(lib.isFavorite(old))
        XCTAssertFalse(lib.isMember(old, ofCollection: c.id))
    }

    func testGifsInCollectionDerivedFromFavourites() {
        let lib = makeLibrary()
        let a = gif("a"); let b = gif("b")
        lib.toggleFavorite(a); lib.toggleFavorite(b)
        let c = lib.createCollection(named: "R")!
        lib.setMembership(a, inCollection: c.id, member: true)
        XCTAssertEqual(lib.gifs(inCollection: c.id).map(\.id), ["a"])
    }

    func testCollectionsPersist() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let first = GifLibrary(defaults: defaults)
        let g = gif("a"); first.toggleFavorite(g)
        let c = first.createCollection(named: "R")!
        first.setMembership(g, inCollection: c.id, member: true)

        let second = GifLibrary(defaults: defaults)
        XCTAssertEqual(second.collections.map(\.name), ["R"])
        XCTAssertEqual(second.gifs(inCollection: c.id).map(\.id), ["a"])
    }

    func testCollectionsCapRejectsBeyondLimit() {
        let lib = makeLibrary()
        for i in 0..<(GifLibrary.collectionsLimit + 3) {
            _ = lib.createCollection(named: "c\(i)")
        }
        XCTAssertEqual(lib.collections.count, GifLibrary.collectionsLimit)
    }

    func testLoadToleratesOneBadCollectionRecord() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let good1: [String: Any] = ["id": "c1", "name": "A", "gifIDs": ["x"]]
        let bad: [String: Any] = ["name": "B"]   // missing id — undecodable
        let good2: [String: Any] = ["id": "c2", "name": "C", "gifIDs": []]
        let data = try! JSONSerialization.data(withJSONObject: [good1, bad, good2])
        defaults.set(data, forKey: "favoriteCollections")

        let lib = GifLibrary(defaults: defaults)
        XCTAssertEqual(lib.collections.map(\.id), ["c1", "c2"])  // bad record skipped
    }
}
