import Foundation

extension Notification.Name {
    /// Posted by AppDelegate when the popover is shown, so the content view can
    /// focus the search field on every open (not just the first).
    static let quipPopoverShown = Notification.Name("quipPopoverShown")
}
