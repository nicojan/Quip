import XCTest
@testable import Quip

/// A configurable offline `GifBackend` for driving the view model without a
/// network. An actor so its mutable state is safe across the concurrency hops the
/// view model makes.
private actor MockBackend: GifBackend {
    private var searchResults: [Gif]
    private var searchError: Error?
    private var trendingByContent: [GiphyClient.Content: [Gif]]
    private(set) var searchCount = 0

    init(searchResults: [Gif] = [], searchError: Error? = nil,
         trending: [GiphyClient.Content: [Gif]] = [:]) {
        self.searchResults = searchResults
        self.searchError = searchError
        self.trendingByContent = trending
    }

    func configure(searchResults: [Gif], searchError: Error?) {
        self.searchResults = searchResults
        self.searchError = searchError
    }

    func search(_ query: String, apiKey: String,
                content: GiphyClient.Content, rating: String) async throws -> [Gif] {
        searchCount += 1
        if let searchError { throw searchError }
        return searchResults
    }

    func trending(apiKey: String, content: GiphyClient.Content,
                  rating: String) async throws -> [Gif] {
        trendingByContent[content] ?? []
    }

    func autocomplete(_ query: String, apiKey: String) async throws -> [String] { [] }
    func fetchData(for gif: Gif) async throws -> Data { Data() }
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
}
