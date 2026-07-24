import SwiftUI
import UniformTypeIdentifiers

/// The menu-bar popover: header, search, suggestions/recents, results or
/// library, and the footer.
struct MenuContentView: View {
    @Environment(GifLibrary.self) private var library
    @Environment(LayoutMetrics.self) private var metrics
    @Environment(Credentials.self) private var credentials
    @Environment(DragContext.self) private var dragContext
    @AppStorage("layoutMode") private var layoutModeRaw = LayoutMode.narrow.rawValue
    @AppStorage("giphyRating") private var rating = GiphyClient.defaultRating
    @AppStorage("useStickers") private var useStickers = false
    @State private var vm: SearchViewModel
    @FocusState private var searchFocused: Bool
    /// Selected collection chip; nil is "All". Owned here (not in LibraryView) so the
    /// one filing drawer above the content can drive it in both the library and the
    /// search grid.
    @State private var selectedCollectionID: String?
    /// True while the library's favourites section is scrolled into view — drives the
    /// drawer between full pill rows (at top) and the compact row (scrolled down).
    @State private var favoritesInView = true
    /// The transient "Added to …" confirmation after a drop, and a token so an older
    /// timer can't clear a newer toast.
    @State private var filedToast: String?
    @State private var toastGeneration = 0

    /// Supplied by AppDelegate — the popover is hosted outside the SwiftUI scene
    /// tree, so SettingsLink and the dismiss environment aren't available.
    let openSettings: () -> Void
    let closePopover: () -> Void

    /// `viewModel` defaults to a network-backed one; the DEBUG demo harness passes
    /// one wired to an offline backend so it runs with no key or connection.
    init(openSettings: @escaping () -> Void,
         closePopover: @escaping () -> Void,
         viewModel: SearchViewModel = SearchViewModel()) {
        self.openSettings = openSettings
        self.closePopover = closePopover
        _vm = State(initialValue: viewModel)
    }

    /// The Giphy key, from the shared Keychain-backed store. Kept as a computed
    /// property so the rest of the view reads `apiKey` unchanged.
    private var apiKey: String { credentials.apiKey }

    private var content: GiphyClient.Content { useStickers ? .stickers : .gifs }

    private var hasKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var layoutMode: LayoutMode { LayoutMode(rawValue: layoutModeRaw) ?? .narrow }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: layoutMode.columns)
    }

    /// Width of one GIF cell in the horizontal Favorites / Recently-copied strips.
    /// Sized so *half* of the next cell shows past the last full one — an obvious
    /// "peep" that the strip scrolls sideways. So a 2-up layout shows 1.5 cells,
    /// 3-up shows 2.5, 5-up shows 4.5. `content` is the popover width minus the
    /// 12pt outer padding on each side.
    private var libraryCellWidth: CGFloat {
        let cols = CGFloat(layoutMode.columns)
        let visible = cols - 0.5
        let content = layoutMode.width - 24
        return ((content - 8 * cols) / visible).rounded(.down)
    }

    /// Rows in each horizontal strip, by popover height (all layouts are now the
    /// same, tall height — so this is 3 on any normal display, 2 only on a short
    /// screen where 80% leaves little room).
    private var libraryRows: Int {
        layoutMode.height(forScreenHeight: metrics.launchScreenHeight) >= 700 ? 3 : 2
    }

    /// Filing inputs shared by every GIF cell, built from the one shared library.
    private var filing: CollectionFiling {
        CollectionFiling(
            collections: library.collections,
            memberIDs: { gif in
                Set(library.collections.filter { $0.gifIDs.contains(gif.id) }.map(\.id))
            },
            toggle: { gif, id in
                library.setMembership(gif, inCollection: id, member: !library.isMember(gif, ofCollection: id))
            }
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            SearchBar(
                text: $vm.query,
                isFocused: $searchFocused,
                onSubmit: runSearch,
                onChange: { vm.liveSearch(apiKey: apiKey, content: content, rating: rating) }
            )

            suggestionsOrRecents

            // Zero spacing so the drawer sits directly above the grid (its own
            // divider separates them), and an empty drawer — search idle, or home
            // with no favourites — adds no phantom gap above the grid.
            VStack(spacing: 0) {
                if showsGrid {
                    FilingDrawer(
                        selectedID: $selectedCollectionID,
                        role: vm.query.isEmpty ? .home : .search,
                        onFiled: showFiledToast,
                        favoritesInView: favoritesInView
                    )
                }

                contentBody
                    // Catch a GIF dropped on empty grid space (not on a chip): file
                    // nothing, but clear the drag so the drawer collapses. Returns
                    // false so the drop reads as "not filed", not a successful drop.
                    .onDrop(of: [QuipDragType.gifRef], isTargeted: nil) { _ in
                        dragContext.gif = nil
                        return false
                    }
            }

            footer
        }
        .padding(12)
        .frame(
            width: layoutMode.width,
            height: layoutMode.height(forScreenHeight: metrics.launchScreenHeight)
        )
        .background(Theme.surface)
        .overlay(alignment: .top) { filedConfirmation }
        .onAppear { refreshOnOpen() }
        .onReceive(NotificationCenter.default.publisher(for: .quipPopoverShown)) { _ in
            refreshOnOpen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quipPopoverClosed)) { _ in
            vm.handlePopoverClose()
            // A drag that ended by leaving the popover (drag-out to another app)
            // never hit a chip, so clear it here — otherwise the drawer would reopen
            // still expanded.
            dragContext.gif = nil
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
        .onChange(of: layoutModeRaw) { _, _ in
            // Let AppDelegate resize the popover so its arrow re-anchors — the
            // SwiftUI frame change alone leaves the arrow at the old width.
            NotificationCenter.default.post(name: .quipLayoutModeChanged, object: nil)
        }
        .onExitCommand(perform: closePopover)   // Esc closes the popover
    }

    /// Runs on every popover open (onAppear fires only once because the hosting
    /// controller is reused, so the notification carries the rest). Focuses the
    /// field and refreshes trending — which also picks up a key added after first
    /// open and any rating/stickers change.
    private func refreshOnOpen() {
        vm.handlePopoverOpen()   // reset to home if it's been idle a while
        focusSearchSoon()
        vm.loadTrending(apiKey: apiKey, content: content, rating: rating)
        // Re-run the active query if stickers/rating changed while we were closed,
        // so we don't show wrong-mode results.
        vm.refreshForSettings(apiKey: apiKey, content: content, rating: rating)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("Quip")
                .font(.headline)
            Spacer()
            LayoutToggle(mode: Binding(
                get: { layoutMode },
                set: { layoutModeRaw = $0.rawValue }
            ))
            Button { openSettings() } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    // Suggestions while typing; recent searches when the field is empty.
    @ViewBuilder private var suggestionsOrRecents: some View {
        if !vm.query.isEmpty, !vm.suggestions.isEmpty {
            RecentSearchesRow(searches: vm.suggestions) { term in
                vm.runPicked(term, apiKey: apiKey, content: content, rating: rating)
            }
        } else if vm.query.isEmpty, !vm.recentSearches.isEmpty {
            HStack(spacing: 8) {
                RecentSearchesRow(searches: vm.recentSearches) { term in
                    vm.runPicked(term, apiKey: apiKey, content: content, rating: rating)
                }
                Button("Clear") { withAnimation { vm.clearRecentSearches() } }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Theme.accentText)
                    .help("Clear recent searches")
                    .accessibilityLabel("Clear recent searches")
            }
        }
    }

    // MARK: Content states

    @ViewBuilder private var contentBody: some View {
        if !hasKey {
            noKeyState
        } else if vm.isLoading, vm.results.isEmpty {
            // Full spinner only when there's nothing to show; a refine-load keeps
            // the current results up (see the ResultsGrid branch below).
            Spacer(); ProgressView(); Spacer()
        } else if let error = vm.errorMessage {
            messageState(error, systemImage: "exclamationmark.triangle")
        } else if vm.noResults {
            messageState("No GIFs found. Try another word.", systemImage: "magnifyingglass")
        } else if vm.query.isEmpty {
            LibraryView(
                columns: columns,
                cellWidth: libraryCellWidth,
                libraryRows: libraryRows,
                trending: vm.trending,
                filing: filing,
                selectedCollectionID: $selectedCollectionID,
                favoritesInView: $favoritesInView,
                isFavorite: { library.isFavorite($0) },
                justCopied: { vm.copiedGifID == $0.id },
                copyFailed: { vm.copyFailedGifID == $0.id },
                onCopy: copy,
                onCopyLink: { vm.copyLink($0) },
                onToggleFavorite: { library.toggleFavorite($0) }
            )
        } else {
            ResultsGrid(
                gifs: vm.results,
                columns: columns,
                filing: filing,
                isFavorite: { library.isFavorite($0) },
                justCopied: { vm.copiedGifID == $0.id },
                copyFailed: { vm.copyFailedGifID == $0.id },
                onCopy: copy,
                onCopyLink: { vm.copyLink($0) },
                onToggleFavorite: { library.toggleFavorite($0) }
            )
            .overlay(alignment: .top) {
                // A refine keeps the old results up with a small badge, instead of
                // blanking the grid to a full-screen spinner on every keystroke.
                if vm.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 4)
                }
            }
        }
    }

    private var noKeyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "key.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Add your free Giphy API key to start searching.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Create a key at developers.giphy.com, then paste it in Settings.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") { openSettings() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private func messageState(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Powered by GIPHY")
            Text("•")
            HStack(spacing: 3) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text("by")
                Link("Nico Jan", destination: URL(string: "https://nicojan.com/")!)
                    .tint(Theme.accentText)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// Whether a GIF grid (library or results) is on screen — the states where the
    /// filing drawer belongs. Hidden for the no-key, error, empty, and
    /// full-spinner states, which show a message instead of a grid.
    private var showsGrid: Bool {
        hasKey
            && vm.errorMessage == nil
            && !vm.noResults
            && !(vm.isLoading && vm.results.isEmpty)
    }

    /// The transient "Added to …" confirmation shown after a drop — the only "it
    /// worked" cue in search, where the grid doesn't change when a GIF is filed.
    @ViewBuilder private var filedConfirmation: some View {
        if let filedToast {
            Label("Added to \(filedToast)", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.accent, in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showFiledToast(_ name: String) {
        toastGeneration += 1
        let generation = toastGeneration
        withAnimation(.easeOut(duration: 0.2)) { filedToast = name }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1600))
            // Only clear if a newer toast hasn't replaced this one.
            if toastGeneration == generation {
                withAnimation(.easeOut(duration: 0.2)) { filedToast = nil }
            }
        }
    }

    private func runSearch() {
        vm.search(apiKey: apiKey, content: content, rating: rating)
    }

    private func copy(_ gif: Gif) {
        vm.copy(gif, into: library)
    }

    private func focusSearchSoon() {
        // Reset first: @FocusState isn't cleared when the popover closes, so
        // re-assigning true would be a no-op and the field wouldn't regain focus
        // on reopen. Toggle false → true across a runloop tick.
        searchFocused = false
        DispatchQueue.main.async { searchFocused = true }
    }
}
