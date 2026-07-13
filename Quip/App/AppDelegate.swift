import AppKit
import SwiftUI
import Sparkle
import KeyboardShortcuts

/// Owns the menu-bar status item, the popover, the Settings window, and the
/// Sparkle updater. Using AppKit here (rather than SwiftUI `MenuBarExtra` /
/// `Settings`) so the global hotkey can open the popover and so opening Settings
/// doesn't depend on the `showSettingsWindow:` responder action, which isn't
/// reachable in an agent (LSUIElement) app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?

    /// Owns the Sparkle updater for the app's lifetime: drives "Check for
    /// Updates…" and the scheduled background checks (see Info.plist).
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        TempClips.prepare()   // clear last session's copy/drag temp files

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.square.stack", accessibilityDescription: "Quip")
            button.action = #selector(handleStatusClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

    // Left-click toggles the popover; right-click (or control-click) shows a menu.
    @objc private func handleStatusClick() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.type == .rightMouseDown
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        if popover.isShown { popover.performClose(nil) }

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Quip", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Assign the menu and click to pop it up under the item, then clear it so
        // the next left-click toggles the popover instead of opening the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettingsFromMenu() { openSettings() }

    @objc private func quit() { NSApp.terminate(nil) }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NotificationCenter.default.post(name: .quipPopoverShown, object: nil)
        }
    }

    /// Shows our own Settings window (created lazily). Reliable in an agent app,
    /// unlike routing through the SwiftUI Settings scene.
    private func openSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(updater: updaterController.updater)
                    .environment(GifLibrary.shared)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "Quip Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .quipSettingsShown, object: nil)
    }
}
