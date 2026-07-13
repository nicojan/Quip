import SwiftUI

@main
struct QuipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu-bar status item, popover, and Settings window are all managed
        // by AppDelegate (see there for why). SwiftUI needs at least one scene;
        // this empty Settings scene is never shown.
        Settings { EmptyView() }
    }
}
