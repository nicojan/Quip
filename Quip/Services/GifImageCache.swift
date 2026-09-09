import Foundation
import SDWebImage

/// Thin wrapper over SDWebImage's shared disk cache. SDWebImage already stores
/// GIF image data keyed by URL, so favorites and recently-copied GIFs load from
/// disk instead of re-fetching from Giphy's CDN. This exposes the on-disk size
/// and a clear, for the Settings controls.
enum GifImageCache {
    /// Ceiling for the on-disk image cache. GIF thumbnails are small, so 256 MB
    /// holds thousands; past this, SDWebImage evicts the oldest entries first.
    static let maxDiskBytes: UInt = 256 * 1024 * 1024

    /// Ceiling for the in-memory image cache. SDWebImage leaves this at 0, which
    /// means *no limit* — so a long-running Quip kept every decoded GIF it had
    /// ever shown. Two days of ordinary use reached a 503 MB footprint with a
    /// 938 MB peak. Half the disk ceiling keeps a comfortable working set while
    /// bounding the growth.
    static let maxMemoryBytes: UInt = 128 * 1024 * 1024

    /// Ceiling for one thumbnail's decoded animation frames. These buffers live
    /// in `SDImageFramePool`, not in `SDImageCache`, so `maxMemoryBytes` above
    /// never bounds them. Left at SDWebImage's default of 0, each playing view
    /// sizes its own buffer at 20% of the Mac's total RAM — 7.2 GB per cell on a
    /// 36 GB machine — and keeps every frame of every visible GIF decoded, which
    /// is why the footprint grew with the size of the machine. A dozen-odd frames
    /// of a fill-scaled cell, re-decoding the rest each loop.
    static let maxFrameBufferBytes: UInt = 2 * 1024 * 1024

    /// Caps both caches so they can't grow without bound during heavy browsing.
    /// Call once at launch. The default 1-week disk age limit stays in place.
    static func configure() {
        SDImageCache.shared.config.maxDiskSize = maxDiskBytes
        SDImageCache.shared.config.maxMemoryCost = maxMemoryBytes
    }

    /// Total bytes the image cache occupies on disk.
    static func diskSizeBytes() -> UInt64 {
        let url = URL(fileURLWithPath: SDImageCache.shared.diskCachePath)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            total += UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }

    /// Clears memory and disk caches. `completion` runs after the disk clear
    /// finishes (on the main queue), so a size refresh reads the real post-clear
    /// figure instead of racing the still-running clear.
    static func clear(completion: (() -> Void)? = nil) {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk { completion?() }
    }
}
