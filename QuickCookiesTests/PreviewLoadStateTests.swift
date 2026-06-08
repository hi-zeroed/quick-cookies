import XCTest
@testable import QuickCookies

final class PreviewLoadStateTests: XCTestCase {
    func test_reset_clearsIncrementalFlags() {
        let state = PreviewLoadState()
        state.hasMoreChunks = true
        state.isIncrementalLoading = true

        state.reset()

        XCTAssertFalse(state.hasMoreChunks)
        XCTAssertFalse(state.isIncrementalLoading)
    }
}
