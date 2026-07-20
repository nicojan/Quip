import Foundation

/// A user-named bucket of favorited GIFs. Membership is stored as GIF ids only —
/// `GifLibrary.favorites` stays the single source of truth for the GIF objects,
/// so the grid for a collection is always derived as `favorites ∩ gifIDs`.
/// Named `GifCollection` (not `Collection`) to avoid shadowing `Swift.Collection`.
struct GifCollection: Identifiable, Codable, Hashable, Sendable {
    let id: String            // UUID string
    var name: String          // always set; used for the chip label and for A→Z sorting
    /// Optional emoji shown on the chip. Required when `showsName` is false, so a
    /// name-less chip is never blank (enforced by the create/edit UI).
    var emoji: String?
    /// Whether the chip shows its text `name`. When false the chip shows only the
    /// `emoji`; the `name` is still kept so the tag can sort alphabetically.
    var showsName: Bool
    var gifIDs: [String]      // deduped on insert; order is not significant

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String? = nil,
        showsName: Bool = true,
        gifIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.showsName = showsName
        self.gifIDs = gifIDs
    }

    private enum CodingKeys: String, CodingKey { case id, name, emoji, showsName, gifIDs }

    /// Tolerant decode mirroring `Gif`: `id` and `name` are required; the rest
    /// default so a pre-1.1.9 record (no `emoji`/`showsName`) still loads —
    /// `showsName` defaults to true, matching the old name-always-shown behaviour.
    /// Combined with per-element loading in `GifLibrary`, a schema change or one
    /// malformed record can't wipe the whole list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        showsName = try container.decodeIfPresent(Bool.self, forKey: .showsName) ?? true
        gifIDs = try container.decodeIfPresent([String].self, forKey: .gifIDs) ?? []
    }
}
