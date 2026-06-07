import XCTest
@testable import QuickCookies

final class MarkdownViewportPlannerTests: XCTestCase {
    func test_initialViewportSlice_keepsAppendingUntilViewportIsFilled() {
        let planner = MarkdownViewportPlanner()
        let blocks = [
            MarkdownRenderBlock(id: "p0", kind: .paragraph, markdown: "Intro", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c0", kind: .code, markdown: "```swift\nprint(1)\nprint(2)\n```", preferredHeight: 220, imageMetas: [], codeLanguage: "swift"),
            MarkdownRenderBlock(id: "p1", kind: .paragraph, markdown: "After code", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c1", kind: .code, markdown: "```swift\nprint(3)\nprint(4)\n```", preferredHeight: 220, imageMetas: [], codeLanguage: "swift")
        ]

        let slice = planner.initialViewportSlice(
            from: blocks,
            viewportHeight: 320,
            overscanRatio: 0.25,
            minimumBlockCount: 2,
            maximumBlockCount: 10
        )

        XCTAssertEqual(slice.map(\.id), ["p0", "c0", "p1", "c1"])
    }

    func test_initialViewportSlice_keepsWholeCodeBlock_whenBudgetBoundaryFallsInsideIt() {
        let planner = MarkdownViewportPlanner()
        let blocks = [
            MarkdownRenderBlock(id: "p0", kind: .paragraph, markdown: "Intro", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c0", kind: .code, markdown: "```swift\nprint(1)\n```", preferredHeight: 360, imageMetas: [], codeLanguage: "swift")
        ]

        let slice = planner.initialViewportSlice(
            from: blocks,
            viewportHeight: 180,
            overscanRatio: 0.15,
            minimumBlockCount: 1,
            maximumBlockCount: 10
        )

        XCTAssertEqual(slice.map(\.id), ["p0", "c0"])
    }
}
