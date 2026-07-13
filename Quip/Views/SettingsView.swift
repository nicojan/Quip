import SwiftUI
import Sparkle

struct SettingsView: View {
    let updater: SPUUpdater

    @Environment(GifLibrary.self) private var library
    @AppStorage("giphyApiKey") private var apiKey = ""
    @AppStorage("isCompactLayout") private var isCompact = false
    @State private var startAtLogin = false

    var body: some View {
        Form {
            Section("Giphy") {
                TextField("Giphy API key", text: $apiKey)
                Link("Get a free Giphy API key ↗",
                     destination: URL(string: "https://developers.giphy.com/dashboard/")!)
                    .font(.caption)
            }

            Section("General") {
                Toggle("Start at login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                    }
                Picker("Default layout", selection: $isCompact) {
                    Text("Narrow — 2 per row").tag(false)
                    Text("Wide — 5 per row").tag(true)
                }
            }

            Section("Library") {
                Button("Clear favorites") { library.clearFavorites() }
                Button("Clear recent GIFs") { library.clearRecents() }
            }

            Section("Updates") {
                CheckForUpdatesButton(updater: updater)
                Text("Quip checks for updates automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .onAppear { startAtLogin = LoginItem.isEnabled }
    }
}
