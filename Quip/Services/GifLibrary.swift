import Foundation
import Observation

/// Persistent store for favorited GIFs and recently-copied GIFs, backed by
/// UserDefaults (JSON). `defaults` is injectable so tests use an isolated suite.
@MainActor
@Observable
final class GifLibrary {
    /// Shared app-wide store. The menu-bar popover (AppKit-hosted) and the
    /// Settings scene are separate view trees, so they share this one instance.
    static let shared = GifLibrary()

    private(set) var favorites: [Gif] = []
    private(set) var recents: [Gif] = []
    private(set) var collections: [GifCollection] = []

    static let recentsLimit = 24
    /// A generous ceiling so favorites don't grow the UserDefaults plist without
    /// bound. Far above realistic use; the oldest is dropped past this.
    static let favoritesLimit = 500
    /// Ceiling on named collections; creation past this is rejected rather than
    /// evicting a curated bucket.
    static let collectionsLimit = 50

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let favoritesKey = "favoriteGifs"
    @ObservationIgnored private let recentsKey = "recentGifs"
    @ObservationIgnored private let collectionsKey = "favoriteCollections"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load(favoritesKey, from: defaults)
        recents = Self.load(recentsKey, from: defaults)
        collections = Self.load(collectionsKey, from: defaults)
    }

    func isFavorite(_ gif: Gif) -> Bool {
        favorites.contains { $0.id == gif.id }
    }

    func toggleFavorite(_ gif: Gif) {
        if let index = favorites.firstIndex(where: { $0.id == gif.id }) {
            favorites.remove(at: index)
            removeFromAllCollections(gif.id)   // un-favoriting drops it from every bucket
        } else {
            favorites.insert(gif, at: 0)
            if favorites.count > Self.favoritesLimit {
                // Drop the oldest past the cap, and cascade those ids out of
                // collections so no orphan membership lingers in storage.
                let droppedIDs = favorites[Self.favoritesLimit...].map(\.id)
                favorites = Array(favorites.prefix(Self.favoritesLimit))
                for id in droppedIDs { removeFromAllCollections(id) }
            }
        }
        save(favorites, favoritesKey)
    }

    // MARK: Collections

    /// Creates a named collection at the front. Trims the name; returns nil for a
    /// blank name or when the count ceiling is reached.
    @discardableResult
    func createCollection(named name: String) -> GifCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, collections.count < Self.collectionsLimit else { return nil }
        let collection = GifCollection(name: trimmed)
        collections.insert(collection, at: 0)
        save(collections, collectionsKey)
        return collection
    }

    /// Renames a collection. Trims the name; a blank name is ignored.
    func renameCollection(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].name = trimmed
        save(collections, collectionsKey)
    }

    func deleteCollection(_ id: String) {
        collections.removeAll { $0.id == id }
        save(collections, collectionsKey)
    }

    func isMember(_ gif: Gif, ofCollection id: String) -> Bool {
        collections.first { $0.id == id }?.gifIDs.contains(gif.id) ?? false
    }

    /// Adds or removes a GIF from a collection. Adding auto-favorites the GIF
    /// first — you can only collect something you've saved.
    func setMembership(_ gif: Gif, inCollection id: String, member: Bool) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        if member {
            if !isFavorite(gif) { toggleFavorite(gif) }
            if !collections[index].gifIDs.contains(gif.id) {
                collections[index].gifIDs.append(gif.id)
            }
        } else {
            collections[index].gifIDs.removeAll { $0 == gif.id }
        }
        save(collections, collectionsKey)
    }

    /// The favorited GIFs in a collection, in favorites order. Orphaned ids (a
    /// member no longer favorited) are dropped for free.
    func gifs(inCollection id: String) -> [Gif] {
        guard let collection = collections.first(where: { $0.id == id }) else { return [] }
        let members = Set(collection.gifIDs)
        return favorites.filter { members.contains($0.id) }
    }

    private func removeFromAllCollections(_ gifID: String) {
        var changed = false
        for i in collections.indices where collections[i].gifIDs.contains(gifID) {
            collections[i].gifIDs.removeAll { $0 == gifID }
            changed = true
        }
        if changed { save(collections, collectionsKey) }
    }

    /// Records a copied GIF: de-dupes by id, moves it to the front, caps the list.
    func addRecent(_ gif: Gif) {
        recents.removeAll { $0.id == gif.id }
        recents.insert(gif, at: 0)
        if recents.count > Self.recentsLimit {
            recents = Array(recents.prefix(Self.recentsLimit))
        }
        save(recents, recentsKey)
    }

    func clearRecents() {
        recents.removeAll()
        save(recents, recentsKey)
    }

    func clearFavorites() {
        favorites.removeAll()
        save(favorites, favoritesKey)
        // Nothing left to belong to a bucket — empty every collection's membership.
        guard collections.contains(where: { !$0.gifIDs.isEmpty }) else { return }
        for i in collections.indices { collections[i].gifIDs.removeAll() }
        save(collections, collectionsKey)
    }

    private func save<T: Encodable>(_ items: [T], _ key: String) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> [T] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Fast path.
        if let decoded = try? JSONDecoder().decode([T].self, from: data) {
            return decoded
        }
        // Tolerant fallback: decode each element independently so one bad or
        // outdated record doesn't discard the whole list.
        guard let rawArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        let decoder = JSONDecoder()
        return rawArray.compactMap { element in
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else {
                return nil
            }
            return try? decoder.decode(T.self, from: elementData)
        }
    }
}
