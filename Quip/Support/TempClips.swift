import Foundation

/// Manages the temporary `.gif` files written for clipboard copy and drag-out.
/// They can't be deleted immediately (the pasteboard / drag holds a file
/// reference the receiver reads later), so instead they live in one dedicated
/// directory that's cleared on each launch — bounding the leak to a session.
enum TempClips {
    static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Quip-clips", isDirectory: true)

    /// Clears last session's clips and recreates the directory. Safe on launch:
    /// a fresh launch means nothing still references the previous files.
    static func prepare() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func newGifURL() -> URL {
        directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("gif")
    }
}
