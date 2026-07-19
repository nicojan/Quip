import XCTest
@testable import Quip

@MainActor
final class SearchViewModelTests: XCTestCase {
    private func gif(_ id: String) -> Gif {
        Gif(id: id, gifURL: "https://example.com/\(id).gif", previewURL: "https://example.com/\(id)_s.gif")
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
