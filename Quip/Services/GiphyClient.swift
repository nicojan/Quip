import Foundation

/// The GIF data source `SearchViewModel` depends on. Production is `GiphyClient`
/// (talks to the network); the DEBUG demo harness swaps in an offline source
/// that serves bundled GIFs, so the demo needs no API key or connection.
protocol GifBackend: Sendable {
    func search(_ query: String, apiKey: String,
                content: GiphyClient.Content, rating: String) async throws -> [Gif]
    func trending(apiKey: String, content: GiphyClient.Content,
                  rating: String) async throws -> [Gif]
    func autocomplete(_ query: String, apiKey: String) async throws -> [String]
    /// Raw bytes of the GIF, for putting a file on the clipboard. Throws on any
    /// failure (including a non-2xx response) so the caller can flag a bad copy.
    func fetchData(for gif: Gif) async throws -> Data
}

/// Talks to the Giphy API. Stateless and `Sendable`; the API key is passed in
/// per call (Quip never bundles one).
struct GiphyClient: Sendable {
    /// GIFs or transparent stickers — the only difference is the path segment.
    enum Content: String, Sendable {
        case gifs
        case stickers
    }

    enum GiphyError: LocalizedError {
        case missingKey
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Add your free Giphy API key in Settings to start searching."
            case .http(let code):
                switch code {
                case 401, 403:
                    return "Giphy turned down that API key. Check it in Settings."
                case 429:
                    return "Too many searches just now. Wait a moment, then try again."
                case 500...599:
                    return "Giphy is having trouble. Try again in a bit."
                default:
                    return "Giphy couldn't handle that search (HTTP \(code))."
                }
            case .badResponse:
                return "Couldn't read Giphy's response."
            }
        }
    }

    static let searchLimit = 36
    static let autocompleteLimit = 6
    static let defaultRating = "pg-13"

    var session: URLSession = .shared

    func search(_ query: String, apiKey: String,
                content: Content = .gifs, rating: String = defaultRating) async throws -> [Gif] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GiphyError.missingKey }
        return try await fetchGifs(from: Self.searchURL(query: query, apiKey: key, content: content, rating: rating))
    }

    func trending(apiKey: String, content: Content = .gifs,
                  rating: String = defaultRating) async throws -> [Gif] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GiphyError.missingKey }
        return try await fetchGifs(from: Self.trendingURL(apiKey: key, content: content, rating: rating))
    }

    /// Autocomplete term suggestions. Returns [] on any error — suggestions are
    /// a nicety, never a hard failure.
    func autocomplete(_ query: String, apiKey: String) async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !term.isEmpty else { return [] }

        let url = try Self.autocompleteURL(query: term, apiKey: key)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { $0["name"] as? String }
    }

    private func fetchGifs(from url: URL) async throws -> [Gif] {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GiphyError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            throw GiphyError.badResponse
        }
        return items.compactMap(Gif.init(giphy:))
    }

    // MARK: URL builders (exposed for testing)

    static func searchURL(query: String, apiKey: String,
                          content: Content = .gifs, rating: String = defaultRating) throws -> URL {
        try url(path: "/v1/\(content.rawValue)/search", apiKey: apiKey, items: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(searchLimit)),
            URLQueryItem(name: "rating", value: rating),
        ])
    }

    static func trendingURL(apiKey: String, content: Content = .gifs,
                            rating: String = defaultRating) throws -> URL {
        try url(path: "/v1/\(content.rawValue)/trending", apiKey: apiKey, items: [
            URLQueryItem(name: "limit", value: String(searchLimit)),
            URLQueryItem(name: "rating", value: rating),
        ])
    }

    static func autocompleteURL(query: String, apiKey: String) throws -> URL {
        try url(path: "/v1/gifs/search/tags", apiKey: apiKey, items: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(autocompleteLimit)),
        ])
    }

    private static func url(path: String, apiKey: String, items: [URLQueryItem]) throws -> URL {
        var components = URLComponents(string: "https://api.giphy.com\(path)")
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)] + items
        // URLComponents leaves '+' literal in query values, and servers read '+'
        // as a space — so encode it, or a query like "c++" reaches Giphy as "c  ".
        let encoded = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = encoded
        guard let url = components?.url else { throw GiphyError.badResponse }
        return url
    }
}

extension GiphyClient: GifBackend {
    /// Downloads the GIF file. A CDN error page (403/404) still arrives as bytes,
    /// so treat any non-2xx as a failure rather than copying a corrupt file.
    func fetchData(for gif: Gif) async throws -> Data {
        guard let url = URL(string: gif.gifURL) else { throw GiphyError.badResponse }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GiphyError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}
