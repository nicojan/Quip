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
    let filing: CollectionFiling
    let onCopy: () -> Void
    let onCopyLink: () -> Void
    let onToggleFavorite: () -> Void

    @State private var hovering = false
    @State private var loadFailed = false

    var body: some View {
        // A fixed column-width × 92 box holds the fill-scaled GIF. The box has no
        // aspect ratio of its own, so — unlike applying `.scaledToFill()` directly
        // to `AnimatedImage`, whose ideal size is the GIF's full pixel dimensions —
        // its width can never exceed the grid column. Wide GIFs overflow *inside*
        // the box and are clipped, instead of bleeding over the neighbouring cell
        // and covering its favorite star.
        Color.white.opacity(0.04)
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .overlay {
                if let url = URL(string: gif.gifURL), !loadFailed {
                    AnimatedImage(url: url)
                        .onFailure { _ in loadFailed = true }
                        .resizable()
                        .indicator(.activity)
                        .scaledToFill()
                } else {
                    // Malformed URL or a failed load: a static placeholder instead
                    // of a spinner that would otherwise turn forever.
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
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
            // The tap target is a plain view, so spell out the actions for
            // VoiceOver — otherwise there's no way to copy a GIF without a mouse.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(gif.title.isEmpty ? "GIF" : gif.title)
            .accessibilityValue(isFavorite ? "Favorite" : "")
            .accessibilityHint("Copies the GIF")
            .accessibilityAction { onCopy() }
            .accessibilityAction(named: "Copy link") { onCopyLink() }
            .accessibilityAction(named: isFavorite ? "Remove from favorites" : "Add to favorites") { onToggleFavorite() }
            .contextMenu { collectionMenu }
    }

    /// Right-click menu to file this GIF into a collection. Toggling one on for a
    /// GIF that isn't a favorite yet auto-favorites it first (see `GifLibrary`).
    /// This is also the VoiceOver-reachable filing path, so no per-collection
    /// accessibility actions are stamped onto the cell.
    @ViewBuilder private var collectionMenu: some View {
        Menu("Add to Collection") {
            if filing.collections.isEmpty {
                Button("No collections yet") {}.disabled(true)
            } else {
                let members = filing.memberIDs(gif)
                ForEach(filing.collections) { collection in
                    Button { filing.toggle(gif, collection.id) } label: {
                        if members.contains(collection.id) {
                            Label(collection.name, systemImage: "checkmark")
                        } else {
                            Text(collection.name)
                        }
                    }
                }
            }
        }
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
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                // Reject a non-2xx CDN response so a downloaded error page never
                // drops into Messages/Finder as a broken .gif attachment.
                guard let data,
                      let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    completion(nil, false, error); return
                }
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
