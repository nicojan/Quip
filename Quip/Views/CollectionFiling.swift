import Foundation

/// Everything a GIF cell needs to file itself into collections, bundled so the
/// grids forward one value instead of several closures. Filing a GIF that isn't
/// yet a favourite auto-favourites it first (handled by `GifLibrary`).
struct CollectionFiling {
    let collections: [GifCollection]
    /// The collection ids a given GIF currently belongs to.
    let memberIDs: (Gif) -> Set<String>
    /// Toggle a GIF's membership in one collection.
    let toggle: (Gif, String) -> Void
}
