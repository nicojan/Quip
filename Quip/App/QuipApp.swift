import SwiftUI
import Sparkle

@main
struct QuipApp: App {
    @State private var library = GifLibrary()

    /// Owns the Sparkle updater for the app's lifetime: drives "Check for
    /// Updates…" and runs the scheduled background checks (see Info.plist).
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(library)
        } label: {
            Image(systemName: "play.square.stack")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(library)
        }
    }
}
