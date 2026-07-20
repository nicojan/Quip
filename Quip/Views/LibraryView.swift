import SwiftUI

/// Shown when there's no active search: favorites (filterable), recently copied,
/// then trending.
struct LibraryView: View {
    @Environment(GifLibrary.self) private var library
    let columns: [GridItem]
    /// Fixed width of a cell in the horizontal Favorites / Recently-copied strips,
    /// matched to the vertical Trending grid (computed by MenuContentView).
    let cellWidth: CGFloat
    /// Number of rows in each horizontal strip (2 or 3, by popover height).
    let libraryRows: Int
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
            // Pinned section headers keep the Favorites controls (title + collection
            // pills + filter) stuck to the top while you scroll the favourites grid.
            // The next section's header (Recently copied / Trending) pushes them up
            // once you scroll past, so the pills stay only while they're relevant.
            LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                Section {
                    favoritesContent
                } header: {
                    favoritesHeader
                }

                if !library.recents.isEmpty {
                    Section {
                        horizontalGrid(library.recents)
                    } header: {
                        pinnedHeader {
                            HStack {
                                sectionHeader("Recently copied")
                                Spacer()
                                Button("Clear") { library.clearRecents() }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                    .foregroundStyle(Theme.accentText)
                            }
                        }
                    }
                }

                if !trending.isEmpty {
                    Section {
                        grid(trending)
                    } header: {
                        pinnedHeader { sectionHeader("Trending") }
                    }
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
        #if DEBUG
        // Lets the demo director drive chip selection (private view state) so a
        // recorded clip can show collection filtering. No effect in Release.
        .onReceive(NotificationCenter.default.publisher(for: .quipDemoSelectCollection)) { note in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedCollectionID = note.object as? String
            }
        }
        #endif
    }

    /// The pinned Favorites header: title, collection pills, and (past 6 favourites)
    /// the filter field — everything that should stay put while the grid scrolls.
    private var favoritesHeader: some View {
        pinnedHeader {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Favorites")
                if !library.favorites.isEmpty {
                    CollectionChipsRow(selectedID: $selectedCollectionID)
                    if showFilterField {
                        TextField("Filter favorites", text: $favoriteFilter)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder private var favoritesContent: some View {
        if library.favorites.isEmpty {
            hint("Star a GIF to save it here.")
        } else if favoritesInScope.isEmpty {
            hint("Nothing here yet. Drag a GIF onto its chip above, or right-click one to add it.")
        } else if filteredFavorites.isEmpty {
            hint("No favorites match “\(favoriteFilter)”.")
        } else {
            horizontalGrid(filteredFavorites)
        }
    }

    /// Wraps a pinned section header in a full-width opaque background, so grid
    /// cells scrolling underneath don't show through the pinned bar.
    private func pinnedHeader<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(Theme.surface)
    }

    /// Trending: the main vertical grid that fills the popover and scrolls down.
    private func grid(_ gifs: [Gif]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(gifs) { gif in cell(gif) }
        }
    }

    /// Favorites / Recently copied: a fixed-height strip of `libraryRows` rows that
    /// scrolls sideways, so a long list stays capped instead of pushing Trending
    /// off the bottom.
    ///
    /// The box background sits *inside* the scroller, sized to the full row, so its
    /// right edge stays off-screen until you reach the end — it reads as one long
    /// box, not a closed panel. No scroll indicator: the peeking next cell (see
    /// `libraryCellWidth`) is the scroll cue.
    ///
    /// Rows grow with the content: one row until it fills the width, a second once
    /// the first is full, a third once the second is full, then it scrolls sideways
    /// — so a handful of favourites never sits in a tall, mostly-empty box.
    /// (`LazyHGrid` fills column-major, so capping the row count does exactly this.)
    private func horizontalGrid(_ gifs: [Gif]) -> some View {
        let perRow = max(1, columns.count)
        let needed = (gifs.count + perRow - 1) / perRow   // ceil(count / perRow)
        let rowCount = max(1, min(libraryRows, needed))
        let rows = Array(repeating: GridItem(.fixed(92), spacing: 8), count: rowCount)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, alignment: .top, spacing: 8) {
                ForEach(gifs) { gif in
                    cell(gif).frame(width: cellWidth)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.corner)
                            .strokeBorder(Color.white.opacity(0.16))
                    )
            )
        }
    }

    private func cell(_ gif: Gif) -> some View {
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }
}
