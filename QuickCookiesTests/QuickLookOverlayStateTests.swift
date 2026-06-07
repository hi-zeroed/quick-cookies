import XCTest
@testable import QuickCookies

final class QuickLookOverlayStateTests: XCTestCase {
    func test_applyDetectedFileStateUpdatesPreviewStateAtomically() {
        let state = PreviewState()
        var changeCount = 0
        state.onStateChanged = {
            changeCount += 1
        }

        QuickLookOverlay.applyDetectedFileState(
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: "Markdown",
            previewState: state
        )

        XCTAssertEqual(state.filePath, "/tmp/demo.md")
        XCTAssertEqual(state.renderType, .markdown)
        XCTAssertEqual(state.language, "Markdown")
        XCTAssertFalse(state.isLoadingPath)
        XCTAssertEqual(changeCount, 1)
    }

    func test_previewReadinessGate_resetsHeavyPreviewToPendingWithFreshToken() {
        let state = PreviewReadinessGate.resetState(
            for: .office,
            tokenFactory: { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
        )

        XCTAssertFalse(state.isReady)
        XCTAssertEqual(
            state.token,
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )
    }

    func test_previewReadinessGate_keepsNonHeavyPreviewReadyImmediately() {
        let state = PreviewReadinessGate.resetState(
            for: .markdown,
            tokenFactory: { UUID(uuidString: "22222222-2222-2222-2222-222222222222")! }
        )

        XCTAssertTrue(state.isReady)
        XCTAssertEqual(
            state.token,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )
    }

    func test_previewReadinessGate_acceptsMatchingTokenOnlyOnce() {
        let initial = PreviewReadinessGate.resetState(
            for: .pdf,
            tokenFactory: { UUID(uuidString: "33333333-3333-3333-3333-333333333333")! }
        )

        let readyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            current: initial
        )
        let duplicateReadyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            current: readyState ?? initial
        )

        XCTAssertEqual(readyState?.token, initial.token)
        XCTAssertTrue(readyState?.isReady == true)
        XCTAssertNil(duplicateReadyState)
    }

    func test_previewReadinessGate_rejectsStaleToken() {
        let current = PreviewReadinessGate.resetState(
            for: .image,
            tokenFactory: { UUID(uuidString: "44444444-4444-4444-4444-444444444444")! }
        )

        let staleReadyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            current: current
        )

        XCTAssertNil(staleReadyState)
    }

    func test_finderSyncMonitoringPolicy_includesRootScopeByDefault() {
        let directories = FinderSyncMonitoringPolicy.monitoredDirectoryURLs(
            homeDirectoryURL: URL(fileURLWithPath: "/Users/demo", isDirectory: true)
        )

        XCTAssertEqual(directories, [URL(fileURLWithPath: "/", isDirectory: true)])
    }
}
