import XCTest
@testable import QuickCookies

final class PreviewDisplayStateResolverTests: XCTestCase {
    func test_resolver_readsDisplayStateFromSession() {
        let sessionTarget = PreviewTarget(
            originalPath: "/tmp/new.md",
            resolvedPath: "/tmp/new.md",
            renderType: .markdown,
            language: "Markdown",
            displayName: "new.md"
        )
        let sessionState = PreviewSessionState(
            target: sessionTarget,
            runtimeKind: .web,
            mode: .edit,
            readiness: .loading,
            isExpanded: true
        )

        let resolved = PreviewDisplayStateResolver.resolve(sessionState: sessionState)

        XCTAssertEqual(resolved.filePath, "/tmp/new.md")
        XCTAssertEqual(resolved.renderType, .markdown)
        XCTAssertEqual(resolved.language, "Markdown")
        XCTAssertEqual(resolved.mode, .edit)
        XCTAssertTrue(resolved.isLoadingPath)
        XCTAssertTrue(resolved.isExpanded)
        XCTAssertNil(resolved.errorMessage)
    }

    func test_resolver_usesSessionDisplayRenderTypeAndRuntimeError() {
        let sessionTarget = PreviewTarget(
            originalPath: "/tmp/demo.bin",
            resolvedPath: "/tmp/demo.bin",
            renderType: .plainText,
            language: nil,
            displayName: "demo.bin"
        )
        let sessionState = PreviewSessionState(
            target: sessionTarget,
            runtimeKind: .text,
            mode: .preview,
            readiness: .failed(.runtime(message: "Binary file")),
            isExpanded: false,
            renderTypeOverride: .unsupported
        )

        let resolved = PreviewDisplayStateResolver.resolve(sessionState: sessionState)

        XCTAssertEqual(resolved.filePath, "/tmp/demo.bin")
        XCTAssertEqual(resolved.renderType, .unsupported)
        XCTAssertEqual(resolved.errorMessage, "Binary file")
    }

    func test_resolver_surfacesFailedSessionWithoutLeakingPreviousValues() {
        let sessionState = PreviewSessionState(
            target: nil,
            runtimeKind: nil,
            mode: .preview,
            readiness: .failed(.noFinderSelection),
            isExpanded: false
        )

        let resolved = PreviewDisplayStateResolver.resolve(sessionState: sessionState)

        XCTAssertNil(resolved.filePath)
        XCTAssertEqual(resolved.renderType, .unsupported)
        XCTAssertEqual(resolved.errorMessage, PreviewTargetError.noFinderSelection.defaultMessage)
        XCTAssertEqual(resolved.mode, .preview)
        XCTAssertFalse(resolved.isExpanded)
    }
}
