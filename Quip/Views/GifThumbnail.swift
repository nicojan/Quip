import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SDWebImageSwiftUI

/// One GIF cell: the animated thumbnail, a hover-revealed favorite star, a
/// click-to-copy tap target (⌥-click copies the link), and drag-out support.
struct GifThumbnail: View {
    let gif: Gif
    let isFavorite: Bool
    let justCopied: Bool
    let copyFailed: Bool
    let onCopy: () -> Void
    let onCopyLink: () -> Void
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
            .overlay {
                if justCopied {
                    copiedOverlay
                } else if copyFailed {
                    failedOverlay
                } else if hovering {
                    copyHint
                }
            }
            .scaleEffect(hovering ? 1.04 : 1)
            .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: 6, y: 2)
            .zIndex(hovering ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: Theme.thumbCorner))
            .onTapGesture {
                // ⌥-click copies the link instead of the file.
                if NSEvent.modifierFlags.contains(.option) { onCopyLink() } else { onCopy() }
            }
            .onDrag(dragProvider)
            .onHover { hovering = $0 }
            .help("Click to copy · ⌥-click to copy link · drag to insert")
    }

    /// Drags the GIF out as a file, downloading on demand so it drops into
    /// Messages, Finder, etc. as an animated attachment.
    private func dragProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = "quip.gif"
        let urlString = gif.gifURL
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.gif.identifier, fileOptions: [], visibility: .all
        ) { completion in
            guard let url = URL(string: urlString) else {
                completion(nil, false, nil)
                return nil
            }
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data else { completion(nil, false, error); return }
                let file = TempClips.newGifURL()
                do {
                    try data.write(to: file)
                    completion(file, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            task.resume()
            return nil
        }
        return provider
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

    private var copiedOverlay: some View {
        RoundedRectangle(cornerRadius: Theme.thumbCorner)
            .fill(Theme.accent.opacity(0.82))
            .overlay(
                VStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.title3)
                    Text("Copied!").font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
            )
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private var failedOverlay: some View {
        RoundedRectangle(cornerRadius: Theme.thumbCorner)
            .fill(Color.red.opacity(0.82))
            .overlay(
                VStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.title3)
                    Text("Couldn't copy").font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
            )
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}
