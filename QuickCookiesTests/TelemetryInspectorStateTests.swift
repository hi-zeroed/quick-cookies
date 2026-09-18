import XCTest
@testable import QuickCookies

@MainActor
final class TelemetryInspectorStateTests: XCTestCase {
    func testInitialState_isNotPresented() {
        let state = TelemetryInspectorState()
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.report)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.showCopiedFeedback)
    }

    func testPresentAndDismiss_updatesState() {
        let state = TelemetryInspectorState()
        
        state.present(path: "/mock/file.swift", renderType: .code, content: "print(1)")
        XCTAssertTrue(state.isPresented)
        
        state.dismiss()
        XCTAssertFalse(state.isPresented)
    }

    func testToggle_flipsPresentationState() {
        let state = TelemetryInspectorState()
        
        state.toggle(path: "/mock/file.swift", renderType: .code, content: "print(1)")
        XCTAssertTrue(state.isPresented)
        
        state.toggle(path: "/mock/file.swift", renderType: .code, content: "print(1)")
        XCTAssertFalse(state.isPresented)
    }

    func testCopySummary_whenEmpty_doesNothing() {
        let state = TelemetryInspectorState()
        state.copySummary()
        XCTAssertFalse(state.showCopiedFeedback)
    }

    func testCopySummary_withValidReport_triggersFeedback() {
        let state = TelemetryInspectorState()
        state.report = TelemetryReport(items: [
            TelemetryItem(id: "lines", label: "Lines", value: "42")
        ])
        state.copySummary()
        XCTAssertTrue(state.showCopiedFeedback)
        
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardString, "Lines: 42")
    }

    func testTelemetryInspectorBarView_initializesWithDefaultAndCustomBottomPadding() {
        let state = TelemetryInspectorState()
        let defaultBar = TelemetryInspectorBarView(state: state)
        XCTAssertEqual(defaultBar.bottomPadding, 16)

        let customBar = TelemetryInspectorBarView(state: state, bottomPadding: 4)
        XCTAssertEqual(customBar.bottomPadding, 4)
    }
}
