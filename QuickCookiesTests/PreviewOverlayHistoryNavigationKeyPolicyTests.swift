import XCTest
@testable import QuickCookies

final class PreviewOverlayHistoryNavigationKeyPolicyTests: XCTestCase {
    func testNotVisibleReturnsNil() {
        let result = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: false,
            keyCode: 33,
            modifierFlags: .command
        )
        XCTAssertNil(result)
    }

    func testCommandLeftBracketReturnsBack() {
        let result = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 33,
            modifierFlags: .command
        )
        XCTAssertEqual(result, .back)
    }

    func testCommandRightBracketReturnsForward() {
        let result = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 30,
            modifierFlags: .command
        )
        XCTAssertEqual(result, .forward)
    }

    func testShiftOrOptionOrControlBlocksNavigation() {
        let withOption = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 33,
            modifierFlags: [.command, .option]
        )
        XCTAssertNil(withOption)

        let withShift = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 33,
            modifierFlags: [.command, .shift]
        )
        XCTAssertNil(withShift)

        let withControl = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 30,
            modifierFlags: [.command, .control]
        )
        XCTAssertNil(withControl)
    }

    func testOtherKeyCodesReturnNil() {
        let result = PreviewOverlayHistoryNavigationKeyPolicy.direction(
            isVisible: true,
            keyCode: 15, // R
            modifierFlags: .command
        )
        XCTAssertNil(result)
    }
}
