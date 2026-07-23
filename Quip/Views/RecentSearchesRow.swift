import SwiftUI

/// Horizontally scrollable chips of recent searches — full terms, no
/// truncation (InaGif clipped these to "c…").
struct RecentSearchesRow: View {
    let searches: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(searches, id: \.self) { term in
                    Button(term) { onSelect(term) }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 1)
            // Kill the horizontal scroller — "Always show scroll bars" overrides
            // showsIndicators. A clipped chip at the edge is the scroll cue.
            .hideScrollers()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
