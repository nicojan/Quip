import SwiftUI
import SDWebImageSwiftUI

/// One GIF cell: the animated thumbnail, a hover-revealed favorite star, and a
/// click-to-copy tap target.
struct GifThumbnail: View {
    let gif: Gif
    let isFavorite: Bool
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void

    @State private var hovering = false

    var body: some View {
        AnimatedImage(url: URL(string: gif.gifURL))
            .resizable()
            .indicator(.activity)
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .clipped()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: Theme.thumbCorner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.thumbCorner)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) { star }
            .overlay { if hovering { copyHint } }
            .contentShape(RoundedRectangle(cornerRadius: Theme.thumbCorner))
            .onTapGesture(perform: onCopy)
            .onHover { hovering = $0 }
            .help("Click to copy")
    }

    @ViewBuilder private var star: some View {
        if hovering || isFavorite {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption2)
                    .padding(5)
                    .background(.black.opacity(0.5), in: Circle())
                    .foregroundStyle(isFavorite ? Theme.accent : .white)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    private var copyHint: some View {
        RoundedRectangle(cornerRadius: Theme.thumbCorner)
            .fill(.black.opacity(0.28))
            .overlay(
                Image(systemName: "doc.on.clipboard")
                    .font(.callout)
                    .foregroundStyle(.white)
            )
            .allowsHitTesting(false)
    }
}
