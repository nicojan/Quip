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

    /// Caps the disk cache so it can't grow without bound during heavy browsing.
    /// Call once at launch. The default 1-week age limit stays in place.
    static func configure() {
        SDImageCache.shared.config.maxDiskSize = maxDiskBytes
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
