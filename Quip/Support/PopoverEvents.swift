import Foundation

extension Notification.Name {
    /// Posted by AppDelegate when the popover is shown, so the content view can
    /// focus the search field and refresh trending on every open (not just the
    /// first — the hosting controller is reused for the app's lifetime).
    static let quipPopoverShown = Notification.Name("quipPopoverShown")

    /// Posted when the Settings window is shown, so it can refresh values that go
    /// stale while it's closed (cache size, login-item state).
    static let quipSettingsShown = Notification.Name("quipSettingsShown")
}
