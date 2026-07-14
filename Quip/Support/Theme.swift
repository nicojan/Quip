import SwiftUI
import AppKit

/// Quip's visual tokens — a slate surface with a single violet accent, from the
/// Chorus family palette.
enum Theme {
    static let accent = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)   // #7C3AED — fills, icons, borders
    /// AppKit twin of `accent`, for status-item / menu-bar drawing (e.g. the
    /// update badge) where SwiftUI `Color` isn't available.
    static let accentNSColor = NSColor(srgbRed: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1) // #7C3AED
    /// Lighter violet for small text on the dark surface. #7C3AED text is only
    /// 3.36:1 on `surface` (fails WCAG AA 4.5:1); #A78BFA (violet-400) is 7.03:1.
    static let accentText = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255) // #A78BFA
    static let accentPink = Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255) // #DB2777
    static let surface = Color(red: 11 / 255, green: 15 / 255, blue: 26 / 255)     // near-black slate
    static let cardStroke = Color.white.opacity(0.08)

    static let corner: CGFloat = 10
    static let thumbCorner: CGFloat = 8
}
