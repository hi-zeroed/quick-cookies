import XCTest
@testable import QuickCookies

final class FindBarStateTests: XCTestCase {
    func test_findBarState_initialState() {
        let state = FindBarState()
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.currentMatchIndex, 0)
        XCTAssertEqual(state.totalMatches, 0)
        XCTAssertEqual(state.matchCountText, "")
    }

    func test_findBarState_presentationAndDismissal() {
        let state = FindBarState()
        state.present()
        XCTAssertTrue(state.isPresented)

        state.query = "func"
        state.totalMatches = 5
        state.currentMatchIndex = 2
        XCTAssertEqual(state.matchCountText, "2 / 5")

        state.dismiss()
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.currentMatchIndex, 0)
        XCTAssertEqual(state.totalMatches, 0)
    }

    func test_findBarState_zeroMatchesText() {
        let state = FindBarState()
        state.present()
        state.query = "missing"
        state.totalMatches = 0
        XCTAssertEqual(state.matchCountText, "0 / 0")
    }
}
