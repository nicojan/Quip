import SwiftUI

/// Shown when there's no active search: favorites (filterable), recently copied,
/// then trending.
struct LibraryView: View {
    @Environment(GifLibrary.self) private var library
    let columns: [GridItem]
    let trending: [Gif]
    let isFavorite: (Gif) -> Bool
    let justCopied: (Gif) -> Bool
    let onCopy: (Gif) -> Void
    let onCopyLink: (Gif) -> Void
    let onToggleFavorite: (Gif) -> Void

    @State private var favoriteFilter = ""

    private var filteredFavorites: [Gif] {
        let query = favoriteFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return library.favorites }
        return library.favorites.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Favorites")
                if library.favorites.isEmpty {
                    hint("Star a GIF to save it here.")
                } else {
                    if library.favorites.count > 6 {
                        TextField("Filter favorites", text: $favoriteFilter)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    if filteredFavorites.isEmpty {
                        hint("No favorites match “\(favoriteFilter)”.")
                    } else {
                        grid(filteredFavorites)
                    }
                }

                if !library.recents.isEmpty {
                    HStack {
                        sectionHeader("Recently copied")
                        Spacer()
                        Button("Clear") { library.clearRecents() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Theme.accentText)
                    }
                    .padding(.top, 4)
                    grid(library.recents)
                }

                if !trending.isEmpty {
                    sectionHeader("Trending")
                        .padding(.top, 4)
                    grid(trending)
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
                    onCopyLink: { onCopyLink(gif) },
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
