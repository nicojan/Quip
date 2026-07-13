import Foundation

/// Talks to the Giphy search API. Stateless and `Sendable`; the API key is
/// passed in per call (Quip never bundles one).
struct GiphyClient: Sendable {
    enum GiphyError: LocalizedError {
        case missingKey
        case http(Int, String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Add your free Giphy API key in Settings to start searching."
            case .http(let code, let body):
                let detail = body.isEmpty ? "" : " \(body)"
                return "Giphy request failed (HTTP \(code)).\(detail)"
            case .badResponse:
                return "Couldn't read Giphy's response."
            }
        }
    }

    static let searchLimit = 36
    var session: URLSession = .shared

    func search(_ query: String, apiKey: String) async throws -> [Gif] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GiphyError.missingKey }

        let url = try Self.searchURL(query: query, apiKey: key)
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GiphyError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            throw GiphyError.badResponse
        }
        return items.compactMap(Gif.init(giphy:))
    }

    /// Percent-encodes the query and builds the search URL. Exposed for testing.
    static func searchURL(query: String, apiKey: String) throws -> URL {
        var components = URLComponents(string: "https://api.giphy.com/v1/gifs/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(searchLimit)),
            URLQueryItem(name: "rating", value: "pg-13"),
        ]
        guard let url = components?.url else { throw GiphyError.badResponse }
        return url
    }
}
