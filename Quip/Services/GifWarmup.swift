import Foundation
import SDWebImage

/// Loads GIFs into the memory cache before a size change brings them into view.
///
/// When the popover grows, cells slide in from the edge — the next GIFs in a
/// strip, the next rows of the grid. A cell that first appears mid-morph would
/// otherwise sit empty for a few frames while its image comes off disk. Warming
/// them first means the cell finds the image in memory and draws it at once.
///
/// Cache-only: a GIF that isn't on disk yet is skipped rather than fetched, so
/// this never adds network traffic. (Local file URLs, which only the DEBUG demo
/// uses, are always read.)
enum GifWarmup {
    /// Cells per row at the widest layout.
    private static let widestColumns = LayoutMode.allCases.map(\.columns).max() ?? 5
    /// A grid row: a 92-pt cell plus 8-pt spacing.
    private static let gridRowHeight: CGFloat = 100

    /// The strip GIFs the widest layout can show: `rows` rows of five, from each.
    static func stripGifs(favorites: [Gif], recents: [Gif], rows: Int) -> [Gif] {
        let limit = rows * widestColumns
        return unique(Array(favorites.prefix(limit)) + Array(recents.prefix(limit)))
    }

    /// The grid GIFs the widest layout shows in a popover this tall.
    static func gridGifs(_ gifs: [Gif], popoverHeight: CGFloat) -> [Gif] {
        let rows = Int(popoverHeight / gridRowHeight)
        return Array(gifs.prefix(rows * widestColumns))
    }

    /// Starts loading `gifs` into memory; returns at once.
    static func warm(_ gifs: [Gif]) {
        let urls = gifs.compactMap { URL(string: $0.gifURL) }
        guard !urls.isEmpty else { return }
        // Same image class AnimatedImage asks for, so its lookup hits this entry.
        let context: [SDWebImageContextOption: Any] = [.animatedImageClass: SDAnimatedImage.self]
        for url in urls {
            SDWebImageManager.shared.loadImage(
                with: url,
                options: options(for: url),
                context: context,
                progress: nil
            ) { _, _, _, _, _, _ in }
        }
    }

    /// Cache-only for anything on the network; local files (the DEBUG demo) are
    /// read directly.
    static func options(for url: URL) -> SDWebImageOptions {
        url.isFileURL ? [] : [.fromCacheOnly]
    }

    private static func unique(_ gifs: [Gif]) -> [Gif] {
        var seen = Set<String>()
        return gifs.filter { seen.insert($0.id).inserted }
    }
}
