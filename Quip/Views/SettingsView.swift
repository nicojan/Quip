import SwiftUI
import Sparkle
import KeyboardShortcuts

struct SettingsView: View {
    let updater: SPUUpdater

    @Environment(GifLibrary.self) private var library
    @AppStorage("giphyApiKey") private var apiKey = ""
    @AppStorage("isCompactLayout") private var isCompact = false
    @AppStorage("giphyRating") private var rating = GiphyClient.defaultRating
    @AppStorage("useStickers") private var useStickers = false
    @State private var startAtLogin = false
    @State private var loginError: String?
    @State private var revealKey = false
    @State private var cacheBytes: UInt64 = 0

    var body: some View {
        Form {
            Section("Giphy") {
                HStack {
                    Group {
                        if revealKey {
                            TextField("Giphy API key", text: $apiKey)
                        } else {
                            SecureField("Giphy API key", text: $apiKey)
                        }
                    }
                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealKey ? "Hide API key" : "Show API key")
                }
                Link("Get a free Giphy API key (choose the API option, not SDK) ↗",
                     destination: URL(string: "https://developers.giphy.com/dashboard/")!)
                    .font(.caption)
            }

            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Summon Quip:", name: .summonQuip)
                Text("Click to record a shortcut, or clear it to turn the global shortcut off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Start at login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, enabled in
                        // Skip the programmatic re-sync below (guards against a loop).
                        guard enabled != LoginItem.isEnabled else { return }
                        do {
                            try LoginItem.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = "macOS wouldn't change this. Set it in System Settings › General › Login Items."
                        }
                        startAtLogin = LoginItem.isEnabled   // reflect what actually happened
                    }
                if startAtLogin, LoginItem.needsApproval {
                    Text("Approve Quip in System Settings › General › Login Items to finish turning this on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(Theme.accentText)
                }
                Picker("Layout", selection: $isCompact) {
                    Text("Narrow (2 per row)").tag(false)
                    Text("Wide (5 per row)").tag(true)
                }
            }

            Section("Content") {
                Toggle("Search stickers instead of GIFs", isOn: $useStickers)
                Picker("Content rating", selection: $rating) {
                    Text("G").tag("g")
                    Text("PG").tag("pg")
                    Text("PG-13").tag("pg-13")
                    Text("R").tag("r")
                }
            }

            Section("Library") {
                Button("Clear favorites") { library.clearFavorites() }
                Button("Clear recent GIFs") { library.clearRecents() }
            }

            Section("Cache") {
                LabeledContent("Cached GIFs on disk", value: cacheSizeText)
                Button("Clear image cache") {
                    GifImageCache.clear { refreshCacheSize() }
                }
                .disabled(cacheBytes == 0)
                Text("Favorites and recent GIFs are cached here so Quip doesn't re-download them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                CheckForUpdatesButton(updater: updater)
                Text("Quip checks for updates automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 4) {
                    Text("Built with")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .accessibilityHidden(true)
                    Text("by")
                    Link("Nico Jan", destination: URL(string: "https://nicojan.com/")!)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 640)
        .onAppear { refreshWindowState() }
        .onReceive(NotificationCenter.default.publisher(for: .quipSettingsShown)) { _ in
            refreshWindowState()
        }
    }

    private func refreshWindowState() {
        startAtLogin = LoginItem.isEnabled
        refreshCacheSize()
    }

    private var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheBytes), countStyle: .file)
    }

    private func refreshCacheSize() {
        Task { @MainActor in
            cacheBytes = await Task.detached(priority: .utility) {
                GifImageCache.diskSizeBytes()
            }.value
        }
    }
}
