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
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
