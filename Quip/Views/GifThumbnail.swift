import SwiftUI
import AppKit
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

    @Environment(DragContext.self) private var dragContext

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
            .onDrag {
                // Record the GIF for an in-app chip drop; the provider still carries
                // the .gif file for external drag-to-insert. See DragContext.
                dragContext.gif = gif
                return QuipDragProvider.make(for: gif)
            } preview: {
                dragPreview
            }
            .onHover { hovering = $0 }
            .help("Click to copy · ⌥-click to copy link · drag to insert, or onto a collection to file")
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

    /// A small, faint preview shown under the cursor while dragging — kept
    /// see-through so it doesn't cover the collection pills it's being dropped onto.
    private var dragPreview: some View {
        Color.clear
            .frame(width: 110, height: 74)
            .overlay {
                if let url = URL(string: gif.gifURL) {
                    AnimatedImage(url: url)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.thumbCorner))
            .opacity(0.3)
    }

    @ViewBuilder private var star: some View {
        if hovering || isFavorite {
            Button(action: onToggleFavorite) {
                Group {
                    if isFavorite {
                        // Filled HIG-yellow star that lifts off the thumbnail with a
                        // drop shadow — no backing circle.
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(nsColor: .systemYellow))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    } else {
                        // Empty star, kept legible on busy thumbnails: a full-white
                        // outline with a drop shadow so it separates from bright GIFs,
                        // rather than a faint inner-shadow outline that washes out
                        // against light content. No backing circle.
                        Image(systemName: "star")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    }
                }
                .font(.callout)
                .padding(4)
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
