import Foundation

/// A user-named bucket of favorited GIFs. Membership is stored as GIF ids only —
/// `GifLibrary.favorites` stays the single source of truth for the GIF objects,
/// so the grid for a collection is always derived as `favorites ∩ gifIDs`.
/// Named `GifCollection` (not `Collection`) to avoid shadowing `Swift.Collection`.
struct GifCollection: Identifiable, Codable, Hashable, Sendable {
    let id: String            // UUID string
    var name: String
    var gifIDs: [String]      // deduped on insert; order is not significant

    init(id: String = UUID().uuidString, name: String, gifIDs: [String] = []) {
        self.id = id
        self.name = name
        self.gifIDs = gifIDs
    }

    private enum CodingKeys: String, CodingKey { case id, name, gifIDs }

    /// Tolerant decode mirroring `Gif`: `id` and `name` are required; `gifIDs`
    /// defaults to empty. Combined with per-element loading in `GifLibrary`, a
    /// schema change or one malformed record can't wipe the whole list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gifIDs = try container.decodeIfPresent([String].self, forKey: .gifIDs) ?? []
    }
}
