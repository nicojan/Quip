import Foundation

/// Manages the temporary `.gif` files written for clipboard copy and drag-out.
/// They can't be deleted immediately (the pasteboard / drag holds a file
/// reference the receiver reads later), so instead they live in one dedicated
/// directory that's cleared on each launch — bounding the leak to a session.
enum TempClips {
    static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Quip-clips", isDirectory: true)

    /// Serializes directory mutations. `newGifURL` is called both on the main actor
    /// (a copy) and on a background URLSession callback (a drag-out), so the trim's
    /// enumerate-then-remove could otherwise race a concurrent one.
    private static let queue = DispatchQueue(label: "com.nicojan.Quip.tempclips")

    /// Clears last session's clips and recreates the directory. Safe on launch:
    /// a fresh launch means nothing still references the previous files.
    static func prepare() {
        queue.sync {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    static func newGifURL() -> URL {
        queue.sync {
            trim()
            return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("gif")
        }
    }

    /// The most recent clips to keep. A menu-bar app can run for weeks, so
    /// launch-only cleanup isn't enough; trim on each new clip instead. Internal so
    /// the trim behaviour is testable.
    static let maxClips = 50

    /// Keeps only the newest `maxClips` files. The just-copied clips — the ones
    /// the pasteboard or an in-progress drag still point at — are the newest, so
    /// they're never the ones removed.
    private static func trim() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ), urls.count > maxClips else { return }

        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        let oldestFirst = urls.sorted { modified($0) < modified($1) }
        for url in oldestFirst.dropLast(maxClips) {
            try? fm.removeItem(at: url)
        }
    }
}
