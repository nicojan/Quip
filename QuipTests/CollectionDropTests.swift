import XCTest
import UniformTypeIdentifiers
@testable import Quip

/// Covers the drag-to-file path: the `QuipDragType` payload round-trip and the
/// `GifLibrary.setMembership(member:)` call a chip drop makes. The drag/drop
/// gesture itself is manual QA (SwiftUI drag isn't unit-testable).
@MainActor
final class CollectionDropTests: XCTestCase {
    private func makeLibrary() -> GifLibrary {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return GifLibrary(defaults: defaults)
    }

    private func gif(_ id: String) -> Gif {
        Gif(id: id,
            gifURL: "https://example.com/\(id).gif",
            previewURL: "https://example.com/\(id)_s.gif",
            title: "Title \(id)")
    }

    /// The drag/drop match is by type identifier, so it must survive an actual
    /// `NSItemProvider` round-trip — the same machinery SwiftUI's `.onDrag`/`.onDrop`
    /// use. This is what proves filing works in the shipped app, where the exported
    /// UTI isn't in the bundle Info.plist. If this fails, the type declaration is
    /// genuinely required and the drop would silently never fire.
    func testProviderConformsAndRoundTripsByIdentifier() {
        let typeID = QuipDragType.gifRef.identifier
        XCTAssertEqual(typeID, "com.nicojan.Quip.gif-ref")

        let g = gif("a")
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: typeID, visibility: .ownProcess
        ) { completion in
            completion(QuipDragType.encode(g), nil)
            return nil
        }

        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(typeID),
                      "onDrop matches by conformance to this identifier")

        let loaded = expectation(description: "load")
        var roundTripped: Gif?
        provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
            roundTripped = QuipDragType.decode(data)
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 2)
        XCTAssertEqual(roundTripped, g)
    }

    /// Exercises the *production* provider (not a hand-built copy). Guards the
    /// silent-breakage cases: dropping the `.gif` file rep would kill drag-to-insert;
    /// mistyping the gif-ref identifier would break every chip drop.
    func testProductionProviderRegistersBothRepresentations() {
        let g = gif("a")
        let provider = QuipDragProvider.make(for: g)

        let types = provider.registeredTypeIdentifiers
        XCTAssertTrue(types.contains(QuipDragType.gifRef.identifier),
                      "chip filing payload must be present")
        XCTAssertTrue(types.contains(UTType.gif.identifier),
                      "drag-to-insert file representation must survive")

        let loaded = expectation(description: "load gif-ref")
        var roundTripped: Gif?
        provider.loadDataRepresentation(forTypeIdentifier: QuipDragType.gifRef.identifier) { data, _ in
            roundTripped = QuipDragType.decode(data)
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 2)
        XCTAssertEqual(roundTripped, g)
    }

    func testPayloadEncodeDecodeRoundTrips() {
        let g = gif("a")
        let data = QuipDragType.encode(g)
        XCTAssertNotNil(data)
        let decoded = QuipDragType.decode(data)
        XCTAssertEqual(decoded, g)
    }

    func testDecodeRejectsMissingOrGarbageData() {
        XCTAssertNil(QuipDragType.decode(nil))
        XCTAssertNil(QuipDragType.decode(Data("not json".utf8)))
    }

    func testDroppingTrendingGifAutoFavouritesAndFiles() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Reactions")!
        // A GIF that isn't a favourite yet — like one dragged from Trending.
        let dropped = QuipDragType.decode(QuipDragType.encode(gif("t")))!
        XCTAssertFalse(lib.isFavorite(dropped))

        lib.setMembership(dropped, inCollection: c.id, member: true)

        XCTAssertTrue(lib.isFavorite(dropped))
        XCTAssertTrue(lib.isMember(dropped, ofCollection: c.id))
    }

    func testReDroppingSameGifDoesNotDuplicateMembership() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "R")!
        let g = gif("a")
        lib.setMembership(g, inCollection: c.id, member: true)
        lib.setMembership(g, inCollection: c.id, member: true)
        XCTAssertEqual(lib.collections.first { $0.id == c.id }?.gifIDs.count, 1)
    }

    /// Dropping a search result onto the "All" chip favourites it without filing it
    /// into any collection — the drawer's "just save it" drop.
    func testDroppingOnAllFavouritesWithoutFiling() {
        let lib = makeLibrary()
        let c = lib.createCollection(named: "Reactions")!
        let dropped = QuipDragType.decode(QuipDragType.encode(gif("t")))!
        XCTAssertFalse(lib.isFavorite(dropped))

        // The "All" drop path: favourite only, never touch a collection.
        if !lib.isFavorite(dropped) { lib.toggleFavorite(dropped) }

        XCTAssertTrue(lib.isFavorite(dropped))
        XCTAssertFalse(lib.isMember(dropped, ofCollection: c.id))
    }

    /// Dropping a GIF on "All" when it's already a favourite is a no-op — it stays
    /// favourited and isn't duplicated.
    func testDroppingAlreadyFavouriteOnAllIsNoOp() {
        let lib = makeLibrary()
        let g = gif("a")
        lib.toggleFavorite(g)
        XCTAssertEqual(lib.favorites.count, 1)

        if !lib.isFavorite(g) { lib.toggleFavorite(g) }   // the All-drop guard

        XCTAssertTrue(lib.isFavorite(g))
        XCTAssertEqual(lib.favorites.count, 1)
    }

    /// Dropping a GIF on "＋" creates a collection and files the GIF into it,
    /// auto-favouriting on the way — the drawer's create-from-GIF drop.
    func testCreateCollectionFromDroppedGifFilesAndFavourites() {
        let lib = makeLibrary()
        let dropped = QuipDragType.decode(QuipDragType.encode(gif("t")))!
        XCTAssertFalse(lib.isFavorite(dropped))

        // The "＋" commit path: create, then file the pending GIF into the result.
        let created = lib.createCollection(named: "New Tag", emoji: "🔥", showsName: true)!
        lib.setMembership(dropped, inCollection: created.id, member: true)

        XCTAssertTrue(lib.isFavorite(dropped))
        XCTAssertTrue(lib.isMember(dropped, ofCollection: created.id))
    }

    /// At the collection cap, a ＋-drop can't create a new collection — but the GIF is
    /// favourited before the create is attempted, so it's saved rather than lost.
    func testCreateFromDropAtCollectionCapKeepsGifFavourited() {
        let lib = makeLibrary()
        for i in 0..<GifLibrary.collectionsLimit {
            XCTAssertNotNil(lib.createCollection(named: "C\(i)"))
        }
        let dropped = gif("t")
        // The ＋-drop favourites immediately (beginCreateFromDrag), before creating.
        lib.toggleFavorite(dropped)
        // Creating past the cap fails, so no collection is added…
        XCTAssertNil(lib.createCollection(named: "Overflow"))
        XCTAssertEqual(lib.collections.count, GifLibrary.collectionsLimit)
        // …but the dragged GIF is still saved.
        XCTAssertTrue(lib.isFavorite(dropped))
    }
}

/// Covers `TempClips`: the trim keeps the clip list bounded, and the serialized
/// `newGifURL` stays correct under the concurrent access it sees in production (a
/// clipboard copy on the main actor overlapping a drag-out on a URLSession thread).
final class TempClipsTests: XCTestCase {
    /// Trim runs before each new clip is minted, so the directory settles at the
    /// cap plus the one just-created clip — bounded, and never dropping the newest.
    func testTrimKeepsClipCountBounded() throws {
        TempClips.prepare()
        let fm = FileManager.default
        var urls: [URL] = []
        for _ in 0..<(TempClips.maxClips + 10) {
            let url = TempClips.newGifURL()
            try Data([0x47]).write(to: url)   // one byte is enough to make it a real file
            urls.append(url)
        }
        let remaining = try fm.contentsOfDirectory(at: TempClips.directory, includingPropertiesForKeys: nil)
        XCTAssertLessThanOrEqual(remaining.count, TempClips.maxClips + 1)
        XCTAssertTrue(fm.fileExists(atPath: urls.last!.path), "the newest clip is never trimmed")
    }

    func testConcurrentNewGifURLsAreUnique() async {
        TempClips.prepare()
        let count = 100
        let urls = await withTaskGroup(of: URL.self) { group -> [URL] in
            for _ in 0..<count { group.addTask { TempClips.newGifURL() } }
            var collected: [URL] = []
            for await url in group { collected.append(url) }
            return collected
        }
        XCTAssertEqual(Set(urls.map(\.lastPathComponent)).count, count)
    }
}
