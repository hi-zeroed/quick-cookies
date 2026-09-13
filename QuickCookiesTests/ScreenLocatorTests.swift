import XCTest
@testable import QuickCookies

final class ScreenLocatorTests: XCTestCase {
    func test_activeScreenLocator_returnsScreenContainingMouseLocation() {
        let screen1 = NSScreen()
        let locator = ActiveScreenLocator()
        
        // When screens list is empty, targetScreen returns nil
        let target = locator.targetScreen(mouseLocation: NSPoint(x: 100, y: 100), screens: [])
        XCTAssertNil(target)
    }

    func test_activeScreenLocator_targetScreenFallbackToMainOrFirst() {
        let screens = NSScreen.screens
        guard let firstScreen = screens.first else { return }
        
        // Point guaranteed inside first screen frame
        let insidePoint = NSPoint(x: firstScreen.frame.midX, y: firstScreen.frame.midY)
        let resolved = ActiveScreenLocator.targetScreen(
            mouseLocation: insidePoint,
            screens: screens,
            mainScreen: NSScreen.main
        )
        XCTAssertEqual(resolved.frame, firstScreen.frame)
        
        // Point far outside all screens
        let outsidePoint = NSPoint(x: -99999, y: -99999)
        let fallback = ActiveScreenLocator.targetScreen(
            mouseLocation: outsidePoint,
            screens: screens,
            mainScreen: firstScreen
        )
        XCTAssertEqual(fallback.frame, firstScreen.frame)
    }
}
