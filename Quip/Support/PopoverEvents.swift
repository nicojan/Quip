import Foundation

extension Notification.Name {
    /// Posted by AppDelegate when the popover is shown, so the content view can
    /// focus the search field and refresh trending on every open (not just the
    /// first — the hosting controller is reused for the app's lifetime).
    static let quipPopoverShown = Notification.Name("quipPopoverShown")

    /// Posted when the popover closes (any path: Esc, click-away, or opening
    /// Settings), so the content view can stamp the inactivity clock — letting a
    /// later reopen measure time spent closed.
    static let quipPopoverClosed = Notification.Name("quipPopoverClosed")

    /// Posted when the Settings window is shown, so it can refresh values that go
    /// stale while it's closed (cache size, login-item state).
    static let quipSettingsShown = Notification.Name("quipSettingsShown")

    /// Posted while the user is picking an emoji for a tag, so AppDelegate can
    /// suspend the popover's transient auto-close: the macOS emoji picker is a
    /// separate panel, and a transient popover would otherwise dismiss the moment
    /// it opens, taking the half-finished tag editor with it.
    static let quipSuspendPopoverAutoClose = Notification.Name("quipSuspendPopoverAutoClose")

    /// Posted when emoji picking ends, restoring the transient auto-close.
    static let quipResumePopoverAutoClose = Notification.Name("quipResumePopoverAutoClose")

    /// Posted when the layout mode changes while the popover is open, so AppDelegate
    /// resizes the popover through `NSPopover.contentSize` — resizing the SwiftUI
    /// content alone leaves the anchor arrow stranded at the old width.
    static let quipLayoutModeChanged = Notification.Name("quipLayoutModeChanged")
}
