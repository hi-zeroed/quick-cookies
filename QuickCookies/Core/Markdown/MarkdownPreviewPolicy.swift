import Foundation

struct MarkdownPreviewPolicy {
    let fileBackedThresholdBytes: UInt64 = 256 * 1024
    let virtualizationThresholdBytes: UInt64 = 2 * 1024 * 1024
    let aggressiveVirtualizationThresholdBytes: UInt64 = 8 * 1024 * 1024
    let virtualizationBlockThreshold: Int = 180
    let initialBatchBlockCount: Int = 10
    let incrementalBatchBlockCount: Int = 6
    let overscanScreens: Int = 4
    let initialViewportOverscanRatio: Double = 0.25
    let minimumInitialViewportBlockCount: Int = 2
    let maximumInitialViewportBlockCount: Int = 48
    let maximumInitialHeavyBlockCount: Int = 48
    let fallbackViewportHeight: Double = 900
    let continuationAppendDelay: TimeInterval = 0.012

    func prefersFileBackedRendering(fileSize: UInt64, fallbackLength: Int, requestedByView: Bool) -> Bool {
        requestedByView || fileSize >= fileBackedThresholdBytes || fallbackLength == 0
    }

    func shouldVirtualize(fileSize: UInt64, blockCount: Int) -> Bool {
        fileSize >= virtualizationThresholdBytes || blockCount >= virtualizationBlockThreshold
    }

    func usesAggressiveVirtualization(fileSize: UInt64) -> Bool {
        fileSize >= aggressiveVirtualizationThresholdBytes
    }
}
