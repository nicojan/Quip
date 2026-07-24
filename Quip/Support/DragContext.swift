import Observation

/// The GIF currently being dragged inside Quip. Set when a cell's drag starts and
/// read when it's dropped on a collection chip.
///
/// Why a shared object instead of the drag pasteboard: macOS hands the drop an
/// `NSItemProvider` stripped of its representations for an in-process, own-process
/// custom type, so the payload can't be read back off the provider. The drag's
/// advertised type (`QuipDragType.gifRef`) still gates *which* drags a chip
/// accepts — external GIF drags don't carry it — so this is only ever read for
/// Quip's own drags.
@MainActor
@Observable
final class DragContext {
    var gif: Gif?

    /// True while a GIF is being dragged inside Quip. The filing drawer reads this
    /// to expand on drag and collapse when it clears. A chip *reorder* deliberately
    /// nils `gif` (see `FilingDrawer`), so reordering never trips this.
    var isDragging: Bool { gif != nil }
}
