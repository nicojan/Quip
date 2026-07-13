import SwiftUI
import AppKit
import Observation

/// Drives search, results, and copy-to-clipboard. All UI state lives on the main
/// actor.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [Gif] = []
    var isLoading = false
    var errorMessage: String?
    var recentSearches: [String] = []
    var showCopied = false

    @ObservationIgnored private let client = GiphyClient()
    @ObservationIgnored private let maxRecentSearches = 5
    @ObservationIgnored private let recentSearchesKey = "recentSearches"
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var copiedResetTask: Task<Void, Never>?

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    /// Explicit search (Return / chip tap): records the term, then runs.
    func search(apiKey: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        addRecentSearch(term)
        run(query: term, apiKey: apiKey)
    }

    /// Debounced as-you-type search; does not record recent searches.
    func liveSearch(apiKey: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        guard !term.isEmpty else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            self.run(query: term, apiKey: apiKey)
        }
    }

    private func run(query term: String, apiKey: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil
            do {
                let gifs = try await self.client.search(term, apiKey: apiKey)
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

    func runRecentSearch(_ term: String, apiKey: String) {
        query = term
        search(apiKey: apiKey)
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
                let file = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("gif")
                try data.write(to: file)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([file as NSURL])
                library.addRecent(gif)
                self.flashCopied()
            } catch {
                self.errorMessage = "Couldn't copy that GIF."
            }
        }
    }

    private func flashCopied() {
        showCopied = true
        copiedResetTask?.cancel()
        copiedResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }
            withAnimation { self.showCopied = false }
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
