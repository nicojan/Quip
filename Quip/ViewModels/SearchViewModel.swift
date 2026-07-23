import SwiftUI
import AppKit
import Observation

/// Drives search, results, trending, autocomplete, and copy-to-clipboard. All
/// UI state lives on the main actor.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [Gif] = []
    var trending: [Gif] = []
    var suggestions: [String] = []
    var isLoading = false
    var errorMessage: String?
    /// True only after a completed search returned zero hits — a neutral empty
    /// state, distinct from `errorMessage` (a failure) and from "haven't searched
    /// yet" (so it never flashes mid-type).
    var noResults = false
    var recentSearches: [String] = []
    /// The id of the GIF most recently copied, for a brief "Copied!" overlay on
    /// that thumbnail. Cleared after a short delay.
    var copiedGifID: String?
    /// The id of a GIF whose copy just failed, for a brief transient overlay.
    /// Kept separate from `errorMessage` so a copy failure never replaces the
    /// whole results/library view.
    var copyFailedGifID: String?

    /// How long the popover can sit closed before reopening it drops the last
    /// search and returns to the home page. Reopen sooner than this and your
    /// results are still there.
    static let inactivityResetInterval: TimeInterval = 120

    @ObservationIgnored private let backend: GifBackend
    /// Store for the recent-search terms. Injectable (like `GifLibrary`'s) so the
    /// demo harness keeps its throwaway terms out of the real defaults.
    @ObservationIgnored private let recentDefaults: UserDefaults
    @ObservationIgnored private let maxRecentSearches = 5
    @ObservationIgnored private let recentSearchesKey = "recentSearches"
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var suggestTask: Task<Void, Never>?
    @ObservationIgnored private var copiedResetTask: Task<Void, Never>?
    @ObservationIgnored private var copyFailedResetTask: Task<Void, Never>?
    /// Set when the query is changed programmatically (a chip/suggestion tap), so
    /// the `onChange`-driven live search that echoes the change is skipped instead
    /// of cancelling the explicit search and re-running it after the debounce.
    @ObservationIgnored private var suppressNextLiveSearch = false
    /// Guards against overlapping trending fetches — notably the two that fire on
    /// the very first open (onAppear plus the shown notification).
    @ObservationIgnored private var isFetchingTrending = false
    /// The clock, injectable so tests can drive the inactivity window.
    @ObservationIgnored private let now: () -> Date
    /// When the user last opened, closed, or acted on the popover; nil until the
    /// first open. Drives the inactivity reset.
    @ObservationIgnored private var lastActiveAt: Date?
    /// The content type and rating the on-screen `results` were fetched under, so
    /// a reopen after a Settings change can tell they've gone stale. Stamped on
    /// both a completed search and a failed one, so a settings change re-runs even
    /// when the last search errored or found nothing.
    @ObservationIgnored private var resultsContent: GiphyClient.Content?
    @ObservationIgnored private var resultsRating: String?
    /// The content type and rating the on-screen `trending` was fetched under, so a
    /// reopen after a Settings change can drop the stale, wrong-mode grid instead of
    /// showing it until the refetch lands.
    @ObservationIgnored private var trendingContent: GiphyClient.Content?
    @ObservationIgnored private var trendingRating: String?

    init(backend: GifBackend = GiphyClient(),
         recentSearchDefaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init) {
        self.backend = backend
        self.recentDefaults = recentSearchDefaults
        self.now = now
        recentSearches = recentSearchDefaults.stringArray(forKey: recentSearchesKey) ?? []
    }

    /// Called each time the popover opens. If it's been idle past the reset
    /// window, clears the last search so we land on the home page; otherwise the
    /// previous results stay. Always stamps the activity time.
    func handlePopoverOpen() {
        if let last = lastActiveAt, now().timeIntervalSince(last) > Self.inactivityResetInterval {
            resetToHome()
        }
        markActive()
    }

    /// Called when the popover closes, so the inactivity window measures time
    /// spent closed — not time since the last search or copy. Without this, a
    /// long read with no copy would count as idle and drop results on a reopen a
    /// second later.
    func handlePopoverClose() {
        markActive()
    }

    /// On popover open: if the content type or rating changed in Settings since
    /// the on-screen state was produced, re-run the active query so we don't keep
    /// showing wrong-mode results — or a stale "No GIFs found" / error from the old
    /// mode. No-op on the home page (empty query).
    func refreshForSettings(apiKey: String, content: GiphyClient.Content, rating: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        guard resultsContent != content || resultsRating != rating else { return }
        run(query: term, apiKey: apiKey, content: content, rating: rating)
    }

    /// Clears the current search back to the home state (recents + trending).
    /// Leaves recent searches and trending intact.
    private func resetToHome() {
        searchTask?.cancel()
        suggestTask?.cancel()
        query = ""
        results = []
        suggestions = []
        errorMessage = nil
        noResults = false
        isLoading = false
    }

    private func markActive() { lastActiveAt = now() }

    /// Explicit search (Return / chip / suggestion tap): records the term, runs.
    func search(apiKey: String, content: GiphyClient.Content, rating: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        suggestTask?.cancel()   // don't let a stale autocomplete repaint chips
        suggestions = []
        addRecentSearch(term)
        run(query: term, apiKey: apiKey, content: content, rating: rating)
    }

    /// Run a term picked from a recent or suggestion chip. Fills the field and
    /// searches, suppressing the live-search echo that setting the field triggers.
    func runPicked(_ term: String, apiKey: String, content: GiphyClient.Content, rating: String) {
        suppressNextLiveSearch = (term != query)
        query = term
        search(apiKey: apiKey, content: content, rating: rating)
    }

    /// Debounced as-you-type search plus autocomplete; does not record recents.
    func liveSearch(apiKey: String, content: GiphyClient.Content, rating: String) {
        if suppressNextLiveSearch {
            suppressNextLiveSearch = false
            return
        }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        updateSuggestions(apiKey: apiKey)
        guard !term.isEmpty else {
            results = []
            errorMessage = nil
            noResults = false
            isLoading = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            self.run(query: term, apiKey: apiKey, content: content, rating: rating)
        }
    }

    private func run(query term: String, apiKey: String, content: GiphyClient.Content, rating: String) {
        markActive()
        searchTask?.cancel()
        // Set loading synchronously — not inside the task — so a task cancelled
        // before its body runs can't later flip isLoading back on and strand a
        // spinner on an already-cleared field.
        isLoading = true
        errorMessage = nil
        noResults = false
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let gifs = try await self.backend.search(term, apiKey: apiKey, content: content, rating: rating)
                if Task.isCancelled { return }
                let deduped = gifs.dedupedByID()
                self.results = deduped
                self.errorMessage = nil          // empty is a state the view shows, not an error
                self.noResults = deduped.isEmpty
                self.resultsContent = content
                self.resultsRating = rating
            } catch {
                if Task.isCancelled { return }
                self.results = []
                self.errorMessage = (error as? GiphyClient.GiphyError)?.errorDescription
                    ?? error.localizedDescription
                // Stamp the failed mode too, so a later Settings change re-runs the
                // query instead of leaving a stale error from the old mode up.
                self.resultsContent = content
                self.resultsRating = rating
            }
            self.isLoading = false
        }
    }

    /// Loads trending for the empty state. Silent on failure — it's a nicety.
    func loadTrending(apiKey: String, content: GiphyClient.Content, rating: String) {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Content or rating changed since the shown trending was fetched: drop the
        // stale, wrong-mode grid now instead of flashing it until the refetch lands.
        if trendingContent != content || trendingRating != rating {
            trending = []
        }
        guard !isFetchingTrending else { return }
        isFetchingTrending = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isFetchingTrending = false }
            let gifs = (try? await self.backend.trending(apiKey: apiKey, content: content, rating: rating)) ?? []
            if !gifs.isEmpty {
                self.trending = gifs.dedupedByID()
                self.trendingContent = content
                self.trendingRating = rating
            }
        }
    }

    private func updateSuggestions(apiKey: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestTask?.cancel()
        guard term.count >= 2 else { suggestions = []; return }
        suggestTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            let terms = (try? await self.backend.autocomplete(term, apiKey: apiKey)) ?? []
            if Task.isCancelled { return }
            var seen = Set<String>()
            self.suggestions = terms.filter { seen.insert($0).inserted }   // no dup ForEach ids
        }
    }

    /// Downloads the GIF and puts it on the pasteboard as a file, so it pastes
    /// into Messages, Slack, etc. as an animated attachment. Records it as recent
    /// on success.
    func copy(_ gif: Gif, into library: GifLibrary) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // The backend rejects a non-2xx (a CDN error page still arrives as
                // bytes), so we never write a corrupt file or flash a false "Copied!".
                let data = try await self.backend.fetchData(for: gif)
                let file = TempClips.newGifURL()
                try data.write(to: file)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([file as NSURL])
                library.addRecent(gif)
                self.markCopied(gif.id)
            } catch {
                // Transient, non-destructive — never route through errorMessage,
                // which gates the whole content region.
                self.markCopyFailed(gif.id)
            }
        }
    }

    /// Copies the GIF's canonical giphy.com page URL as text (⌥-click), for apps
    /// that prefer a link over a file — it unfurls to a preview in most of them.
    /// Falls back to the media URL for older records with no page URL.
    func copyLink(_ gif: Gif) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(gif.pageURL, forType: .string)
        markCopied(gif.id)
    }

    private func markCopied(_ id: String) {
        markActive()
        withAnimation { copiedGifID = id }
        copiedResetTask?.cancel()
        copiedResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }
            withAnimation { if self.copiedGifID == id { self.copiedGifID = nil } }
        }
    }

    private func markCopyFailed(_ id: String) {
        withAnimation { copyFailedGifID = id }
        copyFailedResetTask?.cancel()
        copyFailedResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            withAnimation { if self.copyFailedGifID == id { self.copyFailedGifID = nil } }
        }
    }

    /// Clears the recent-search terms (the chip row on the home page). Leaves
    /// trending and the library untouched.
    func clearRecentSearches() {
        recentSearches = []
        recentDefaults.removeObject(forKey: recentSearchesKey)
    }

    private func addRecentSearch(_ term: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        recentSearches.insert(term, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        recentDefaults.set(recentSearches, forKey: recentSearchesKey)
    }
}
