import SwiftUI

/// Quip's visual tokens — a slate surface with a single violet accent, from the
/// Chorus family palette.
enum Theme {
    static let accent = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)   // #7C3AED
    static let accentPink = Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255) // #DB2777
    static let surface = Color(red: 11 / 255, green: 15 / 255, blue: 26 / 255)     // near-black slate
    static let cardStroke = Color.white.opacity(0.08)

    static let corner: CGFloat = 10
    static let thumbCorner: CGFloat = 8
}
