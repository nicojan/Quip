import SwiftUI

/// The menu-bar popover: header, search, recent searches, results or library,
/// and the GIPHY attribution footer.
struct MenuContentView: View {
    @Environment(GifLibrary.self) private var library
    @AppStorage("giphyApiKey") private var apiKey = ""
    @AppStorage("isCompactLayout") private var isCompact = false
    @State private var vm = SearchViewModel()
    @FocusState private var searchFocused: Bool

    /// Opens the Settings window. Supplied by AppDelegate because the popover is
    /// hosted outside the SwiftUI scene tree, where SettingsLink doesn't work.
    let openSettings: () -> Void

    private var hasKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: isCompact ? 5 : 2)
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            SearchBar(
                text: $vm.query,
                isFocused: $searchFocused,
                onSubmit: { vm.search(apiKey: apiKey) },
                onChange: { vm.liveSearch(apiKey: apiKey) }
            )

            if vm.query.isEmpty && !vm.recentSearches.isEmpty {
                RecentSearchesRow(searches: vm.recentSearches) { term in
                    vm.runRecentSearch(term, apiKey: apiKey)
                }
            }

            content

            footer
        }
        .padding(12)
        .frame(width: isCompact ? 640 : 320, height: isCompact ? 470 : 600)
        .background(Theme.surface)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("Quip")
                .font(.headline)
            Spacer()
            LayoutToggle(isCompact: $isCompact)
            Button { openSettings() } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    // MARK: Content states

    @ViewBuilder private var content: some View {
        if !hasKey {
            noKeyState
        } else if vm.isLoading {
            Spacer(); ProgressView(); Spacer()
        } else if let error = vm.errorMessage {
            messageState(error, systemImage: "exclamationmark.triangle")
        } else if vm.query.isEmpty {
            LibraryView(
                columns: columns,
                isFavorite: { library.isFavorite($0) },
                justCopied: { vm.copiedGifID == $0.id },
                onCopy: copy,
                onToggleFavorite: { library.toggleFavorite($0) }
            )
        } else {
            ResultsGrid(
                gifs: vm.results,
                columns: columns,
                isFavorite: { library.isFavorite($0) },
                justCopied: { vm.copiedGifID == $0.id },
                onCopy: copy,
                onToggleFavorite: { library.toggleFavorite($0) }
            )
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
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func copy(_ gif: Gif) {
        vm.copy(gif, into: library)
    }
}
