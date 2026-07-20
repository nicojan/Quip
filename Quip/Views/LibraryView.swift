import SwiftUI

/// Shown when there's no active search: favorites (filterable), recently copied,
/// then trending.
struct LibraryView: View {
    @Environment(GifLibrary.self) private var library
    let columns: [GridItem]
    let trending: [Gif]
    let filing: CollectionFiling
    let isFavorite: (Gif) -> Bool
    let justCopied: (Gif) -> Bool
    let copyFailed: (Gif) -> Bool
    let onCopy: (Gif) -> Void
    let onCopyLink: (Gif) -> Void
    let onToggleFavorite: (Gif) -> Void

    @State private var favoriteFilter = ""
    /// Selected collection chip; nil is "All". Persists across a quick reopen and
    /// falls back to All whenever the collection no longer exists (see `favoritesInScope`).
    @State private var selectedCollectionID: String?

    /// Favourites narrowed to the selected collection (or all of them for "All").
    /// Derived from `favorites`, so it keeps favourites order and drops orphaned
    /// ids, and treats a stale/deleted selection as "All".
    private var favoritesInScope: [Gif] {
        guard let id = selectedCollectionID,
              let collection = library.collections.first(where: { $0.id == id }) else {
            return library.favorites
        }
        let members = Set(collection.gifIDs)
        return library.favorites.filter { members.contains($0.id) }
    }

    private var showFilterField: Bool { favoritesInScope.count > 6 }

    private var filteredFavorites: [Gif] {
        // Only apply the filter while its field is shown, so shrinking the list
        // below the threshold can't leave favorites hidden by a filter with no
        // visible control to clear it.
        guard showFilterField else { return favoritesInScope }
        let query = favoriteFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return favoritesInScope }
        return favoritesInScope.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Favorites")
                if library.favorites.isEmpty {
                    hint("Star a GIF to save it here.")
                } else {
                    CollectionChipsRow(selectedID: $selectedCollectionID)
                    if showFilterField {
                        TextField("Filter favorites", text: $favoriteFilter)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    if favoritesInScope.isEmpty {
                        hint("Nothing in this collection yet. Right-click a GIF to add it.")
                    } else if filteredFavorites.isEmpty {
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
        .scrollIndicators(.hidden)
        .onChange(of: favoritesInScope.count) { _, count in
            if count <= 6 { favoriteFilter = "" }   // drop stale filter text
        }
        .onChange(of: selectedCollectionID) { _, _ in
            favoriteFilter = ""   // a fresh scope starts with a clear filter
        }
    }

    private func grid(_ gifs: [Gif]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(gifs) { gif in
                GifThumbnail(
                    gif: gif,
                    isFavorite: isFavorite(gif),
                    justCopied: justCopied(gif),
                    copyFailed: copyFailed(gif),
                    filing: filing,
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
