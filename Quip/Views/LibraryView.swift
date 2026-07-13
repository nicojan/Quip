import SwiftUI

/// Shown when there's no active search: favorites first, then recently copied.
struct LibraryView: View {
    @Environment(GifLibrary.self) private var library
    let columns: [GridItem]
    let isFavorite: (Gif) -> Bool
    let justCopied: (Gif) -> Bool
    let onCopy: (Gif) -> Void
    let onToggleFavorite: (Gif) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Favorites")
                if library.favorites.isEmpty {
                    hint("Star a GIF to save it here.")
                } else {
                    grid(library.favorites)
                }

                if !library.recents.isEmpty {
                    HStack {
                        sectionHeader("Recently copied")
                        Spacer()
                        Button("Clear") { library.clearRecents() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 4)
                    grid(library.recents)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func grid(_ gifs: [Gif]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(gifs) { gif in
                GifThumbnail(
                    gif: gif,
                    isFavorite: isFavorite(gif),
                    justCopied: justCopied(gif),
                    onCopy: { onCopy(gif) },
                    onToggleFavorite: { onToggleFavorite(gif) }
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }
}
