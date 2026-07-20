import Foundation
import UniformTypeIdentifiers

/// A private, in-process drag payload that carries a whole `Gif` so a cell can be
/// dropped onto a collection chip to file it. This rides *alongside* the cell's
/// public `.gif` file representation (drag-to-insert): external apps only see the
/// file, so drag-out is untouched, while Quip's chips read this type.
///
/// The payload is the full `Gif`, not just its id — filing a GIF dragged from
/// Trending auto-favorites it, which needs the whole object to store.
enum QuipDragType {
    /// An app-private drag identifier. It is *not* declared in `Info.plist` —
    /// `GENERATE_INFOPLIST_FILE` strips `UTExportedTypeDeclarations`, and it isn't
    /// needed: drag and drop match by identifier, and both the cell that registers
    /// the payload and the chip that reads it use this one constant. Combined with
    /// `.ownProcess` registration visibility, the payload never leaves Quip.
    /// (Covered by `CollectionDropTests.testProviderConformsAndRoundTripsByIdentifier`.)
    static let gifRef = UTType(exportedAs: "com.nicojan.Quip.gif-ref")

    /// Encodes a GIF for the drag pasteboard. Returns nil if the GIF can't encode,
    /// so the caller can skip registering an unusable representation.
    static func encode(_ gif: Gif) -> Data? {
        try? JSONEncoder().encode(gif)
    }

    /// Decodes a dropped payload back into a GIF, or nil if the data is missing or
    /// malformed — the drop is then ignored rather than filing garbage.
    static func decode(_ data: Data?) -> Gif? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Gif.self, from: data)
    }
}
