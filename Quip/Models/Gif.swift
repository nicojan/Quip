import Foundation

/// A single GIF result. `Sendable` so it can cross the client/UI boundary under
/// Swift concurrency.
struct Gif: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let gifURL: String       // animated "fixed_width" rendition
    let previewURL: String   // still preview ("fixed_width_still"), falls back to gifURL
    let title: String

    init(id: String, gifURL: String, previewURL: String, title: String = "") {
        self.id = id
        self.gifURL = gifURL
        self.previewURL = previewURL
        self.title = title
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
        self.title = (dict["title"] as? String) ?? ""
    }
}
