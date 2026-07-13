import SwiftUI

/// Scrollable grid of search results.
struct ResultsGrid: View {
    let gifs: [Gif]
    let columns: [GridItem]
    let isFavorite: (Gif) -> Bool
    let onCopy: (Gif) -> Void
    let onToggleFavorite: (Gif) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(gifs) { gif in
                    GifThumbnail(
                        gif: gif,
                        isFavorite: isFavorite(gif),
                        onCopy: { onCopy(gif) },
                        onToggleFavorite: { onToggleFavorite(gif) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}
