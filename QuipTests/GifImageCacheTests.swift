import XCTest
import SDWebImage
@testable import Quip

final class GifImageCacheTests: XCTestCase {
    /// SDWebImage ships both ceilings at 0, which means *no limit*. Leaving the
    /// memory one alone is what let a long-running Quip reach a 503 MB footprint,
    /// so `configure()` has to set both — a regression here is invisible until
    /// the app has been up for days.
    func testConfigureCapsBothCaches() {
        let config = SDImageCache.shared.config
        config.maxDiskSize = 0
        config.maxMemoryCost = 0

        GifImageCache.configure()

        XCTAssertEqual(config.maxDiskSize, GifImageCache.maxDiskBytes)
        XCTAssertEqual(config.maxMemoryCost, GifImageCache.maxMemoryBytes)
    }

    /// Both ceilings must be real limits, and the memory one no larger than the
    /// disk one — a memory cache bigger than its backing store is nonsense.
    func testCeilingsAreSane() {
        XCTAssertGreaterThan(GifImageCache.maxMemoryBytes, 0)
        XCTAssertGreaterThan(GifImageCache.maxDiskBytes, 0)
        XCTAssertLessThanOrEqual(GifImageCache.maxMemoryBytes, GifImageCache.maxDiskBytes)
    }
}
