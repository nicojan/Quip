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
    var recentSearches: [String] = []
    /// The id of the GIF most recently copied, for a brief "Copied!" overlay on
    /// that thumbnail. Cleared after a short delay.
    var copiedGifID: String?
    /// The id of a GIF whose copy just failed, for a brief transient overlay.
    /// Kept separate from `errorMessage` so a copy failure never replaces the
    /// whole results/library view.
    var copyFailedGifID: String?

    @ObservationIgnored private let client = GiphyClient()
    @ObservationIgnored private let maxRecentSearches = 5
    @ObservationIgnored private let recentSearchesKey = "recentSearches"
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var suggestTask: Task<Void, Never>?
    @ObservationIgnored private var copiedResetTask: Task<Void, Never>?
    @ObservationIgnored private var copyFailedResetTask: Task<Void, Never>?

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    /// Explicit search (Return / chip / suggestion tap): records the term, runs.
    func search(apiKey: String, content: GiphyClient.Content, rating: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        suggestions = []
        addRecentSearch(term)
        run(query: term, apiKey: apiKey, content: content, rating: rating)
    }

    /// Debounced as-you-type search plus autocomplete; does not record recents.
    func liveSearch(apiKey: String, content: GiphyClient.Content, rating: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        updateSuggestions(apiKey: apiKey)
        guard !term.isEmpty else {
            results = []
            errorMessage = nil
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
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil
            do {
                let gifs = try await self.client.search(term, apiKey: apiKey, content: content, rating: rating)
                if Task.isCancelled { return }
                self.results = gifs
                self.errorMessage = gifs.isEmpty ? "No GIFs found." : nil
            } catch {
                if Task.isCancelled { return }
                self.results = []
                self.errorMessage = (error as? GiphyClient.GiphyError)?.errorDescription
                    ?? error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func runRecentSearch(_ term: String, apiKey: String, content: GiphyClient.Content, rating: String) {
        query = term
        search(apiKey: apiKey, content: content, rating: rating)
    }

    /// Loads trending for the empty state. Silent on failure — it's a nicety.
    func loadTrending(apiKey: String, content: GiphyClient.Content, rating: String) {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let gifs = (try? await self.client.trending(apiKey: apiKey, content: content, rating: rating)) ?? []
            if !gifs.isEmpty { self.trending = gifs }
        }
    }

    private func updateSuggestions(apiKey: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestTask?.cancel()
        guard term.count >= 2 else { suggestions = []; return }
        suggestTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            let terms = (try? await self.client.autocomplete(term, apiKey: apiKey)) ?? []
            if Task.isCancelled { return }
            self.suggestions = terms
        }
    }

    /// Downloads the GIF and puts it on the pasteboard as a file, so it pastes
    /// into Messages, Slack, etc. as an animated attachment. Records it as recent
    /// on success.
    func copy(_ gif: Gif, into library: GifLibrary) {
        guard let url = URL(string: gif.gifURL) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
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

    /// Copies the GIF's Giphy page/asset URL as text (⌥-click), for apps that
    /// prefer a link over a file.
    func copyLink(_ gif: Gif) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(gif.gifURL, forType: .string)
        markCopied(gif.id)
    }

    private func markCopied(_ id: String) {
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

    private func addRecentSearch(_ term: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        recentSearches.insert(term, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}
