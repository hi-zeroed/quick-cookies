import XCTest
@testable import QuickCookies

@MainActor
final class PreviewSessionTests: XCTestCase {
    func test_session_open_setsActiveTargetAndRuntimeKind() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)

        XCTAssertEqual(session.state.target, target)
        XCTAssertEqual(session.state.source, .service)
        XCTAssertEqual(session.state.runtimeKind, .web)
        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertEqual(session.state.readiness, .loading)
        XCTAssertFalse(session.state.isExpanded)
    }

    func test_session_reset_clearsTargetAndReturnsToIdlePreviewMode() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.swift",
            resolvedPath: "/tmp/demo.swift",
            renderType: .code,
            language: "swift",
            displayName: "demo.swift"
        )

        session.open(target: target, source: .service)
        session.enterEditMode()
        session.reset()

        XCTAssertNil(session.state.target)
        XCTAssertNil(session.state.runtimeKind)
        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertEqual(session.state.readiness, .idle)
        XCTAssertFalse(session.state.isExpanded)
    }

    func test_session_markReady_transitionsReadinessToReady() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.pdf",
            resolvedPath: "/tmp/demo.pdf",
            renderType: .pdf,
            language: nil,
            displayName: "demo.pdf"
        )

        session.open(target: target, source: .service)
        session.markReady()

        XCTAssertEqual(session.state.readiness, .ready)
    }

    func test_session_returnToPreviewMode_leavesSessionInPreview() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)
        session.enterEditMode()
        session.returnToPreviewMode()

        XCTAssertEqual(session.state.mode, .preview)
    }

    func test_session_toggleExpanded_updatesExpandedState() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)
        session.toggleExpanded()
        XCTAssertTrue(session.state.isExpanded)

        session.toggleExpanded()
        XCTAssertFalse(session.state.isExpanded)
    }

    func test_session_markFailed_preservesPreviousTargetAndRuntimeKind() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)
        session.markFailed(.fileNotFound)

        XCTAssertEqual(session.state.target, target)
        XCTAssertEqual(session.state.runtimeKind, .web)
        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertEqual(session.state.readiness, .failed(.fileNotFound))
    }

    func test_session_markFailed_withoutTarget_staysDetached() {
        let session = PreviewSession()

        session.markFailed(.noFinderSelection)

        XCTAssertNil(session.state.target)
        XCTAssertNil(session.state.runtimeKind)
        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertEqual(session.state.readiness, .failed(.noFinderSelection))
    }

    func test_session_replaceWithFailure_clearsPreviousTargetAndRuntimeKind() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)
        session.replaceWithFailure(.noFinderSelection)

        XCTAssertNil(session.state.target)
        XCTAssertNil(session.state.runtimeKind)
        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertFalse(session.state.isExpanded)
        XCTAssertEqual(session.state.readiness, .failed(.noFinderSelection))
    }

    func test_session_openUnsupportedTarget_keepsPresentationTarget() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/archive.zip",
            resolvedPath: "/tmp/archive.zip",
            renderType: .unsupported,
            language: nil,
            displayName: "archive.zip"
        )

        session.open(target: target, source: .service)

        XCTAssertEqual(session.state.target, target)
        XCTAssertEqual(session.state.runtimeKind, .text)
        XCTAssertEqual(session.state.readiness, .loading)
    }

    func test_session_applyRuntimeFailure_preservesResolvedTargetAndSurfacesOverrideError() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.bin",
            resolvedPath: "/tmp/demo.bin",
            renderType: .plainText,
            language: nil,
            displayName: "demo.bin"
        )

        session.open(target: target, source: .service)
        session.applyRuntimeFailure(message: "Binary file", renderTypeOverride: .unsupported)

        XCTAssertEqual(session.state.target, target)
        XCTAssertEqual(session.state.runtimeKind, .text)
        XCTAssertEqual(session.state.readiness, .failed(.runtime(message: "Binary file")))
        XCTAssertEqual(session.state.displayRenderType, .unsupported)
        XCTAssertEqual(session.state.errorMessage, "Binary file")
    }

    func test_session_applyRuntimeFailure_returnsToCollapsedPreviewMode() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )

        session.open(target: target, source: .service)
        session.enterEditMode()
        session.toggleExpanded()
        session.applyRuntimeFailure(message: "Load failed")

        XCTAssertEqual(session.state.mode, .preview)
        XCTAssertFalse(session.state.isExpanded)
        XCTAssertEqual(session.state.errorMessage, "Load failed")
    }

    func test_session_markReady_clearsRuntimeFailureOverrides() {
        let session = PreviewSession()
        let target = PreviewTarget(
            originalPath: "/tmp/demo.bin",
            resolvedPath: "/tmp/demo.bin",
            renderType: .plainText,
            language: nil,
            displayName: "demo.bin"
        )

        session.open(target: target, source: .service)
        session.applyRuntimeFailure(message: "Binary file", renderTypeOverride: .unsupported)
        session.markReady()

        XCTAssertEqual(session.state.readiness, .ready)
        XCTAssertEqual(session.state.displayRenderType, .plainText)
        XCTAssertNil(session.state.errorMessage)
    }
}
