import SwiftUI

/// The menu-bar popover: header, search, recent searches, results or library,
/// and the GIPHY attribution footer.
struct MenuContentView: View {
    @Environment(GifLibrary.self) private var library
    @AppStorage("giphyApiKey") private var apiKey = ""
    @AppStorage("isCompactLayout") private var isCompact = false
    @State private var vm = SearchViewModel()
    @FocusState private var searchFocused: Bool

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

            Text("Powered by GIPHY")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: isCompact ? 640 : 320, height: isCompact ? 470 : 600)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { copiedToast }
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
            SettingsLink {
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
                onCopy: copy,
                onToggleFavorite: { library.toggleFavorite($0) }
            )
        } else {
            ResultsGrid(
                gifs: vm.results,
                columns: columns,
                isFavorite: { library.isFavorite($0) },
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
            SettingsLink { Text("Open Settings") }
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

    @ViewBuilder private var copiedToast: some View {
        if vm.showCopied {
            Label("Copied!", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 34)
                .transition(.opacity)
        }
    }

    private func copy(_ gif: Gif) {
        vm.copy(gif, into: library)
    }
}
