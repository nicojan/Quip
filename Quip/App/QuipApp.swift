import SwiftUI
import Sparkle

@main
struct QuipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
        // The menu-bar status item and popover are managed by AppDelegate.
        // This scene provides the Settings window.
        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(GifLibrary.shared)
        }
    }
}
