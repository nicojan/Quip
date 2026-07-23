import Foundation

/// A single GIF result. `Sendable` so it can cross the client/UI boundary under
/// Swift concurrency.
struct Gif: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let gifURL: String       // animated "fixed_width" rendition
    let previewURL: String   // still preview ("fixed_width_still"), falls back to gifURL
    /// Canonical giphy.com page URL (Giphy's `url` field), copied by ⌥-click for a
    /// clean, unfurl-friendly link. Falls back to `gifURL` when absent.
    let pageURL: String
    let title: String

    init(id: String, gifURL: String, previewURL: String, pageURL: String? = nil, title: String = "") {
        self.id = id
        self.gifURL = gifURL
        self.previewURL = previewURL
        self.pageURL = pageURL ?? gifURL
        self.title = title
    }

    private enum CodingKeys: String, CodingKey { case id, gifURL, previewURL, pageURL, title }

    /// Tolerant decode: only `id` and `gifURL` are required; `previewURL`,
    /// `pageURL`, and `title` fall back to sensible defaults. Combined with
    /// per-element loading in `GifLibrary`, this keeps a persisted favorites/recents
    /// list from being wiped when the schema gains a field or one record is
    /// malformed — a pre-pageURL record simply falls back to `gifURL`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        gifURL = try container.decode(String.self, forKey: .gifURL)
        previewURL = try container.decodeIfPresent(String.self, forKey: .previewURL) ?? gifURL
        pageURL = try container.decodeIfPresent(String.self, forKey: .pageURL) ?? gifURL
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    }

    /// Build from one element of Giphy's search `data[]`. Returns nil if the
    /// shape isn't what we expect, so callers can `compactMap`.
    init?(giphy dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let images = dict["images"] as? [String: Any],
              let fixedWidth = images["fixed_width"] as? [String: Any],
              let url = fixedWidth["url"] as? String else {
            return nil
        }
        self.id = id
        self.gifURL = url
        let still = (images["fixed_width_still"] as? [String: Any])?["url"] as? String
        self.previewURL = still ?? url
        // Giphy's `url` is the shareable giphy.com page; fall back to the media URL.
        let page = (dict["url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.pageURL = page ?? url
        self.title = (dict["title"] as? String) ?? ""
    }
}

extension Array where Element == Gif {
    /// Drops later entries whose id already appeared. Giphy occasionally repeats
    /// an id within one response, which would collide as a SwiftUI `ForEach` id
    /// and drop or glitch cells.
    func dedupedByID() -> [Gif] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
