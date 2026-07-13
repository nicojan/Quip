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

    static let recentsLimit = 24
    /// A generous ceiling so favorites don't grow the UserDefaults plist without
    /// bound. Far above realistic use; the oldest is dropped past this.
    static let favoritesLimit = 500

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let favoritesKey = "favoriteGifs"
    @ObservationIgnored private let recentsKey = "recentGifs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load(favoritesKey, from: defaults)
        recents = Self.load(recentsKey, from: defaults)
    }

    func isFavorite(_ gif: Gif) -> Bool {
        favorites.contains { $0.id == gif.id }
    }

    func toggleFavorite(_ gif: Gif) {
        if let index = favorites.firstIndex(where: { $0.id == gif.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(gif, at: 0)
            if favorites.count > Self.favoritesLimit {
                favorites = Array(favorites.prefix(Self.favoritesLimit))
            }
        }
        save(favorites, favoritesKey)
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
    }

    private func save(_ gifs: [Gif], _ key: String) {
        if let data = try? JSONEncoder().encode(gifs) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> [Gif] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Fast path.
        if let decoded = try? JSONDecoder().decode([Gif].self, from: data) {
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
            return try? decoder.decode(Gif.self, from: elementData)
        }
    }
}
