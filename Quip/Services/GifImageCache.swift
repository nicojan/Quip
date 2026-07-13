import Foundation
import SDWebImage

/// Thin wrapper over SDWebImage's shared disk cache. SDWebImage already stores
/// GIF image data keyed by URL, so favorites and recently-copied GIFs load from
/// disk instead of re-fetching from Giphy's CDN. This exposes the on-disk size
/// and a clear, for the Settings controls.
enum GifImageCache {
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

    static func clear() {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk(onCompletion: nil)
    }
}
