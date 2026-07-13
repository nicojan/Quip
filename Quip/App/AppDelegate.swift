import AppKit
import SwiftUI
import KeyboardShortcuts

/// Owns the menu-bar status item and the popover. Using AppKit here (rather than
/// SwiftUI `MenuBarExtra`) so the global hotkey can open the popover
/// programmatically — `MenuBarExtra` can't be opened in code.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.square.stack", accessibilityDescription: "Quip")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(
                openSettings: { [weak self] in self?.openSettings() },
                closePopover: { [weak self] in self?.popover.performClose(nil) }
            )
            .environment(GifLibrary.shared)
        )

        // Seed the default shortcut exactly once, so a user who later clears it
        // (to disable) doesn't get it forced back on the next launch.
        if !UserDefaults.standard.bool(forKey: "didInitSummonShortcut") {
            KeyboardShortcuts.setShortcut(.init(.g, modifiers: [.command, .shift]), for: .summonQuip)
            UserDefaults.standard.set(true, forKey: "didInitSummonShortcut")
        }
        KeyboardShortcuts.onKeyUp(for: .summonQuip) { [weak self] in
            self?.togglePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NotificationCenter.default.post(name: .quipPopoverShown, object: nil)
        }
    }

    /// Opens the SwiftUI `Settings` scene from the detached popover, where the
    /// SwiftUI `SettingsLink`/`openSettings` environment isn't available.
    private func openSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Defer so the responder chain settles after the popover closes. Don't
        // gate on NSApp.responds(to:) — the Settings action lives in the
        // responder chain (installed by the SwiftUI Settings scene), not on
        // NSApplication, so responds(to:) is false and would skip the call.
        // sendAction returns whether it was handled; fall back to the older name.
        DispatchQueue.main.async {
            if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
}
