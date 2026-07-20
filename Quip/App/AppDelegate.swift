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

    /// Usable height of the display the popover opens on (`visibleFrame`, so it
    /// never clips under the menu bar/Dock), injected into the content so the
    /// `tall` layout can be 80% of it. Refreshed before each show (see `togglePopover`).
    private let layoutMetrics = LayoutMetrics(launchScreenHeight: NSScreen.main?.visibleFrame.height ?? 800)

    /// The GIF being dragged inside Quip, so a chip drop can file it (the drag
    /// pasteboard can't carry it — see `DragContext`).
    private let dragContext = DragContext()

    /// Owns the Sparkle updater for the app's lifetime: drives "Check for
    /// Updates…" and the scheduled background checks (see Info.plist). Created in
    /// `applicationDidFinishLaunching` so `self` can be the user-driver delegate
    /// (for gentle reminders — see the SPUStandardUserDriverDelegate extension).
    private var updaterController: SPUStandardUpdaterController!

    /// A scheduled (background) update Sparkle asked us to present gently, if any.
    /// Set while the status item is badged; drives the "Install Update…" menu item.
    private var pendingUpdate: SUAppcastItem?
    /// The violet dot overlaid on the status item when `pendingUpdate` is set.
    private var updateBadge: NSView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        TempClips.prepare()   // clear last session's copy/drag temp files
        GifImageCache.configure()   // cap the on-disk image cache

        migrateLayoutPreference()

        // Start the updater (userDriverDelegate: self routes scheduled-update
        // alerts through our gentle-reminder methods instead of a stolen-focus modal).
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.square.stack", accessibilityDescription: "Quip")
            button.action = #selector(handleStatusClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.delegate = self   // posts .quipPopoverClosed on every close path
        // The popover is designed dark-only (fixed Theme.surface background); pin
        // its appearance so semantic text/control colors don't flip to light and
        // render dark-on-dark when the OS is in light mode.
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 320, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(
                openSettings: { [weak self] in self?.openSettings() },
                closePopover: { [weak self] in self?.popover.performClose(nil) }
            )
            .environment(GifLibrary.shared)
            .environment(layoutMetrics)
            .environment(dragContext)
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

        // While the macOS emoji picker is open the popover must not auto-dismiss
        // (see PopoverEvents). Flip to app-defined during picking, back to
        // transient after.
        NotificationCenter.default.addObserver(
            forName: .quipSuspendPopoverAutoClose, object: nil, queue: .main
        ) { [weak self] _ in
            self?.popover.behavior = .applicationDefined
        }
        NotificationCenter.default.addObserver(
            forName: .quipResumePopoverAutoClose, object: nil, queue: .main
        ) { [weak self] _ in
            self?.popover.behavior = .transient
        }

        // Resize through NSPopover when the layout mode changes while open, so the
        // anchor arrow re-anchors instead of stranding at the previous width.
        NotificationCenter.default.addObserver(
            forName: .quipLayoutModeChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            let mode = LayoutMode(rawValue: UserDefaults.standard.string(forKey: "layoutMode") ?? "") ?? .narrow
            self.popover.contentSize = NSSize(
                width: mode.width,
                height: mode.height(forScreenHeight: self.layoutMetrics.launchScreenHeight)
            )
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
        menu.autoenablesItems = false
        // Surface a pending gentle-reminder update as an actionable menu item.
        if pendingUpdate != nil {
            let updateItem = NSMenuItem(title: "Install Update…", action: #selector(installPendingUpdate), keyEquivalent: "")
            updateItem.target = self
            menu.addItem(updateItem)
            menu.addItem(.separator())
        }
        let checkItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        checkItem.target = self
        checkItem.isEnabled = updaterController.updater.canCheckForUpdates
        menu.addItem(checkItem)
        menu.addItem(.separator())
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

    /// User-initiated update check from the menu-bar menu. Shows Sparkle's standard
    /// UI (progress, then "up to date" or the update prompt) — only *scheduled*
    /// checks are deferred to the gentle-reminder badge.
    @objc private func checkForUpdatesFromMenu() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.updater.checkForUpdates()
    }

    /// Brings the deferred update into focus. Sparkle re-presents the update it
    /// already found (checkForUpdates is the documented way to surface a pending
    /// gentle reminder), then shows its standard install UI.
    @objc private func installPendingUpdate() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.updater.checkForUpdates()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    /// Overlays (or removes) a small violet dot on the status item to signal a
    /// pending update without stealing focus. Kept as a subview so the template
    /// menu-bar icon still adapts to light/dark and selection states.
    private func setUpdateBadge(_ visible: Bool) {
        guard let button = statusItem.button else { return }
        if visible {
            let dot = updateBadge ?? {
                let view = NSView()
                view.wantsLayer = true
                view.layer?.backgroundColor = Theme.accentNSColor.cgColor
                button.addSubview(view)
                updateBadge = view
                return view
            }()
            let size: CGFloat = 6
            dot.frame = NSRect(x: button.bounds.maxX - size - 2,
                               y: button.bounds.maxY - size - 3,
                               width: size, height: size)
            dot.layer?.cornerRadius = size / 2
        } else {
            updateBadge?.removeFromSuperview()
            updateBadge = nil
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Size to the display we're opening on before showing, so the `tall`
            // layout (80% of usable height) opens at the right size with no flash.
            let screenHeight = (button.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
            layoutMetrics.launchScreenHeight = screenHeight
            let mode = LayoutMode(rawValue: UserDefaults.standard.string(forKey: "layoutMode") ?? "") ?? .narrow
            popover.contentSize = NSSize(width: mode.width, height: mode.height(forScreenHeight: screenHeight))

            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NotificationCenter.default.post(name: .quipPopoverShown, object: nil)
        }
    }

    /// One-time migration from the old two-state `isCompactLayout` bool to the
    /// three-way `layoutMode`, so an upgrading user keeps their layout choice.
    private func migrateLayoutPreference() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "layoutMode") == nil,
              defaults.object(forKey: "isCompactLayout") != nil else { return }
        let mode = LayoutMode(legacyIsCompact: defaults.bool(forKey: "isCompactLayout"))
        defaults.set(mode.rawValue, forKey: "layoutMode")
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

// MARK: - Popover close events

extension AppDelegate: @preconcurrency NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // Re-arm transient auto-close in case it was suspended for emoji picking
        // and the popover closed by another path first.
        popover.behavior = .transient
        NotificationCenter.default.post(name: .quipPopoverClosed, object: nil)
    }
}

// MARK: - Gentle update reminders

/// Quip is a menu-bar (LSUIElement) app, so a background-scheduled update alert
/// would otherwise appear in a stolen-focus modal the user is likely to miss.
/// Instead we defer scheduled alerts, badge the status item, and let the user
/// pull the update up from the right-click menu. User-initiated checks (the
/// Settings button) are left to Sparkle's standard immediate UI.
extension AppDelegate: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Let Sparkle present immediately only when it's already in focus;
        // otherwise we handle it gently (badge the status item).
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }   // Sparkle is showing it; nothing to do
        pendingUpdate = update
        setUpdateBadge(true)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // User engaged with the update alert — clear the gentle indicator.
        pendingUpdate = nil
        setUpdateBadge(false)
    }

    func standardUserDriverWillFinishUpdateSession() {
        // Session ended (installed, skipped, or dismissed) — clear any indicator.
        pendingUpdate = nil
        setUpdateBadge(false)
    }
}
