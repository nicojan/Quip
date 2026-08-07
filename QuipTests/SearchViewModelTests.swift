import XCTest
@testable import Quip

/// A configurable offline `GifBackend` for driving the view model without a
/// network. An actor so its mutable state is safe across the concurrency hops the
/// view model makes.
private actor MockBackend: GifBackend {
    private var searchResults: [Gif]
    private var searchError: Error?
    private var trendingByContent: [GiphyClient.Content: [Gif]]
    private var fetchError: Error?
    /// Held until `releaseTrending()` is called, so a test can keep one trending
    /// fetch in flight while the mode changes under it.
    private var trendingGate: Bool = false
    private(set) var searchCount = 0
    private(set) var trendingCount = 0

    init(searchResults: [Gif] = [], searchError: Error? = nil,
         trending: [GiphyClient.Content: [Gif]] = [:],
         gateTrending: Bool = false) {
        self.searchResults = searchResults
        self.searchError = searchError
        self.trendingByContent = trending
        self.trendingGate = gateTrending
    }

    func configure(searchResults: [Gif], searchError: Error?) {
        self.searchResults = searchResults
        self.searchError = searchError
    }

    func configure(fetchError: Error?) { self.fetchError = fetchError }

    func releaseTrending() { trendingGate = false }

    func search(_ query: String, apiKey: String,
                content: GiphyClient.Content, rating: String) async throws -> [Gif] {
        searchCount += 1
        if let searchError { throw searchError }
        return searchResults
    }

    func trending(apiKey: String, content: GiphyClient.Content,
                  rating: String) async throws -> [Gif] {
        trendingCount += 1
        while trendingGate {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return trendingByContent[content] ?? []
    }

    func autocomplete(_ query: String, apiKey: String) async throws -> [String] { [] }

    func fetchData(for gif: Gif) async throws -> Data {
        if let fetchError { throw fetchError }
        return Data()
    }
}

private struct TestError: Error {}

@MainActor
final class SearchViewModelTests: XCTestCase {
    private func gif(_ id: String) -> Gif {
        Gif(id: id, gifURL: "https://example.com/\(id).gif", previewURL: "https://example.com/\(id)_s.gif")
    }

    /// Polls until `condition` holds or the timeout elapses, yielding to let the
    /// view model's main-actor tasks run in between.
    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s")
    }

    /// `waitUntil` for a condition that has to await the mock actor.
    private func waitUntilAsync(timeout: TimeInterval = 2, _ condition: () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        let met = await condition()
        XCTAssertTrue(met, "condition not met within \(timeout)s")
    }

    // MARK: Settings-change refresh (bug #1)

    func testSettingsChangeReRunsAfterErroredSearch() async {
        let backend = MockBackend(searchError: TestError())
        let vm = SearchViewModel(backend: backend)
        vm.query = "cats"
        vm.search(apiKey: "K", content: .gifs, rating: "pg-13")
        await waitUntil { vm.errorMessage != nil }
        XCTAssertTrue(vm.results.isEmpty)

        // The last search errored under (gifs, pg-13). Fix the backend, change the
        // rating, and reopen: the query must re-run under the new mode rather than
        // sit on the stale error from the old one.
        await backend.configure(searchResults: [gif("a")], searchError: nil)
        vm.refreshForSettings(apiKey: "K", content: .gifs, rating: "g")
        await waitUntil { vm.results.map(\.id) == ["a"] }
        XCTAssertNil(vm.errorMessage)
    }

    func testSettingsRefreshNoOpsWhenModeUnchanged() async {
        let backend = MockBackend(searchResults: [gif("a")])
        let vm = SearchViewModel(backend: backend)
        vm.query = "cats"
        vm.search(apiKey: "K", content: .gifs, rating: "pg-13")
        await waitUntil { !vm.results.isEmpty }
        let baseline = await backend.searchCount

        // Same content and rating: reopening must not fire a redundant search.
        vm.refreshForSettings(apiKey: "K", content: .gifs, rating: "pg-13")
        try? await Task.sleep(for: .milliseconds(30))
        let after = await backend.searchCount
        XCTAssertEqual(after, baseline)
    }

    // MARK: Trending mode staleness (bug #2)

    func testTrendingClearsWhenContentChanges() async {
        let backend = MockBackend(trending: [.gifs: [gif("g")], .stickers: [gif("s")]])
        let vm = SearchViewModel(backend: backend)
        vm.loadTrending(apiKey: "K", content: .gifs, rating: "pg-13")
        await waitUntil { vm.trending.map(\.id) == ["g"] }

        // Switching content must drop the stale gifs grid immediately, not flash it
        // until the stickers fetch lands.
        vm.loadTrending(apiKey: "K", content: .stickers, rating: "pg-13")
        XCTAssertTrue(vm.trending.isEmpty, "stale trending should clear synchronously")
        await waitUntil { vm.trending.map(\.id) == ["s"] }
    }

    /// A settings change while a trending fetch is in flight must not publish the
    /// old mode's grid — and must not leave it stamped as current, which would stop
    /// anything from refetching.
    func testTrendingInFlightDiscardsResultForAChangedMode() async {
        let backend = MockBackend(
            trending: [.gifs: [gif("g")], .stickers: [gif("s")]],
            gateTrending: true
        )
        let vm = SearchViewModel(backend: backend)
        vm.loadTrending(apiKey: "K", content: .gifs, rating: "pg-13")
        await waitUntilAsync { await backend.trendingCount == 1 }

        // Stickers wanted now, while the gifs fetch is still held open.
        vm.loadTrending(apiKey: "K", content: .stickers, rating: "pg-13")
        await backend.releaseTrending()

        // The gifs result is dropped; the stickers grid replaces it.
        await waitUntil { vm.trending.map(\.id) == ["s"] }
    }

    // MARK: Copy overlays

    /// The cell reads `copiedGifID` and `copyFailedGifID` independently and prefers
    /// "Copied!", so a failure that follows a success on the same GIF has to clear it
    /// — otherwise a copy that put nothing on the clipboard reports success.
    func testFailedCopyClearsALiveCopiedOverlay() async {
        let backend = MockBackend()
        let vm = SearchViewModel(backend: backend)
        let library = GifLibrary(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let target = gif("a")

        vm.copy(target, into: library)
        await waitUntil { vm.copiedGifID == "a" }

        await backend.configure(fetchError: TestError())
        vm.copy(target, into: library)
        await waitUntil { vm.copyFailedGifID == "a" }
        XCTAssertNil(vm.copiedGifID, "a failed copy must not leave 'Copied!' up")
    }

    func testSuccessfulCopyClearsALiveFailureOverlay() async {
        let backend = MockBackend()
        await backend.configure(fetchError: TestError())
        let vm = SearchViewModel(backend: backend)
        let library = GifLibrary(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let target = gif("a")

        vm.copy(target, into: library)
        await waitUntil { vm.copyFailedGifID == "a" }

        await backend.configure(fetchError: nil)
        vm.copy(target, into: library)
        await waitUntil { vm.copiedGifID == "a" }
        XCTAssertNil(vm.copyFailedGifID)
    }

    func testReopenWithinWindowKeepsResults() {
        var clock = Date(timeIntervalSince1970: 0)
        let vm = SearchViewModel(now: { clock })

        vm.handlePopoverOpen()          // first open, stamps activity
        vm.query = "cats"
        vm.results = [gif("a")]

        clock = clock.addingTimeInterval(SearchViewModel.inactivityResetInterval - 1)
        vm.handlePopoverOpen()          // reopened just inside the window

        XCTAssertEqual(vm.query, "cats")
        XCTAssertEqual(vm.results.map(\.id), ["a"])
    }

    func testReopenAfterWindowResetsToHome() {
        var clock = Date(timeIntervalSince1970: 0)
        let vm = SearchViewModel(now: { clock })

        vm.handlePopoverOpen()
        vm.query = "cats"
        vm.results = [gif("a")]
        vm.suggestions = ["cats", "cars"]
        vm.errorMessage = "Something failed."
        vm.noResults = true

        clock = clock.addingTimeInterval(SearchViewModel.inactivityResetInterval + 1)
        vm.handlePopoverOpen()          // reopened past the window

        XCTAssertEqual(vm.query, "")
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.noResults)
    }

    // The window measures time *closed*, not time since the last search/copy:
    // stamping on close keeps a long read from dropping results on a quick reopen.
    func testCloseStampKeepsResultsAcrossBriefReopen() {
        var clock = Date(timeIntervalSince1970: 0)
        let vm = SearchViewModel(now: { clock })

        vm.handlePopoverOpen()          // T0: first open, last action here
        vm.query = "cats"
        vm.results = [gif("a")]

        clock = clock.addingTimeInterval(200)   // 200s of reading, no search/copy
        vm.handlePopoverClose()                 // stamps the close
        clock = clock.addingTimeInterval(5)      // reopen 5s later
        vm.handlePopoverOpen()

        XCTAssertEqual(vm.query, "cats")         // closed only 5s — nothing dropped
        XCTAssertEqual(vm.results.map(\.id), ["a"])
    }

    func testFirstOpenNeverResets() {
        var clock = Date(timeIntervalSince1970: 1000)
        let vm = SearchViewModel(now: { clock })

        vm.query = "preset"
        vm.handlePopoverOpen()          // no prior activity — nothing to reset
        XCTAssertEqual(vm.query, "preset")
    }

    // MARK: Clear recent searches

    func testClearRecentSearchesEmptiesAndPersists() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let vm = SearchViewModel(backend: MockBackend(), recentSearchDefaults: defaults)
        vm.query = "cats"; vm.search(apiKey: "K", content: .gifs, rating: "pg-13")
        vm.query = "dogs"; vm.search(apiKey: "K", content: .gifs, rating: "pg-13")
        XCTAssertEqual(vm.recentSearches, ["dogs", "cats"])

        vm.clearRecentSearches()
        XCTAssertTrue(vm.recentSearches.isEmpty)
        // The cleared state survives a reload from the same defaults.
        let reloaded = SearchViewModel(backend: MockBackend(), recentSearchDefaults: defaults)
        XCTAssertTrue(reloaded.recentSearches.isEmpty)
    }
}
