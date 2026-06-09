import XCTest
@testable import QuickCookies

private struct StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    let result: Result<String, FileDetector.DetectError>

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        result
    }
}

@MainActor
final class PreviewCoordinatorTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func test_coordinator_resolvesTargetAndOpensSession() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("demo.md")
        try "# Demo".write(to: fileURL, atomically: true, encoding: .utf8)

        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .success(fileURL.path)
                )
            )
        )

        try coordinator.handle(.openPath(fileURL.path, source: .service))

        XCTAssertEqual(session.state.target?.displayName, "demo.md")
        XCTAssertEqual(session.state.runtimeKind, .web)
        XCTAssertEqual(session.state.readiness, .loading)
    }

    func test_coordinator_marksSessionFailedWhenResolutionFails() {
        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .failure(.noFileSelected)
                )
            )
        )

        XCTAssertThrowsError(
            try coordinator.handle(.toggleFromFinderHotkey())
        ) { error in
            XCTAssertEqual(error as? PreviewTargetError, .noFinderSelection)
        }

        XCTAssertEqual(session.state.readiness, .failed(.noFinderSelection))
        XCTAssertNil(session.state.target)
    }

    func test_coordinator_scriptFailureStillCollapsesToNoFinderSelection() {
        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .failure(.scriptingBridgeError("boom"))
                )
            )
        )

        XCTAssertThrowsError(
            try coordinator.handle(.toggleFromFinderHotkey())
        ) { error in
            XCTAssertEqual(error as? PreviewTargetError, .noFinderSelection)
        }

        XCTAssertEqual(session.state.readiness, .failed(.noFinderSelection))
        XCTAssertNil(session.state.target)
    }

    func test_coordinator_failureAfterPreviousSuccess_clearsPreviousTarget() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("demo.md")
        try "# Demo".write(to: fileURL, atomically: true, encoding: .utf8)

        let session = PreviewSession()
        let successCoordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .success(fileURL.path)
                )
            )
        )
        let failureCoordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .failure(.noFileSelected)
                )
            )
        )

        try successCoordinator.handle(.openPath(fileURL.path, source: .service))
        XCTAssertEqual(session.state.target?.resolvedPath, fileURL.path)

        XCTAssertThrowsError(
            try failureCoordinator.handle(.toggleFromFinderHotkey())
        ) { error in
            XCTAssertEqual(error as? PreviewTargetError, .noFinderSelection)
        }

        XCTAssertNil(session.state.target)
        XCTAssertNil(session.state.runtimeKind)
        XCTAssertEqual(session.state.readiness, .failed(.noFinderSelection))
    }

    func test_coordinator_openUnsupportedFile_keepsResolvedTargetForPresentation() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("executable.bin")
        try Data([0x41, 0x42, 0x00, 0x43]).write(to: fileURL)

        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .success(fileURL.path)
                )
            )
        )

        try coordinator.handle(.openPath(fileURL.path, source: .service))

        XCTAssertEqual(session.state.target?.resolvedPath, fileURL.path)
        XCTAssertEqual(session.state.target?.displayName, "executable.bin")
        XCTAssertEqual(session.state.runtimeKind, .text)
        XCTAssertEqual(session.state.readiness, .loading)
        XCTAssertEqual(session.state.target?.renderType, .unsupported)
    }

    func test_coordinator_openDirectory_keepsUnsupportedPresentationTarget() throws {
        let directoryURL = temporaryDirectoryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .success(directoryURL.path)
                )
            )
        )

        try coordinator.handle(.openPath(directoryURL.path, source: .service))

        XCTAssertEqual(session.state.target?.resolvedPath, directoryURL.path)
        XCTAssertEqual(session.state.target?.displayName, "Folder")
        XCTAssertEqual(session.state.target?.renderType, .unsupported)
        XCTAssertEqual(session.state.runtimeKind, .text)
        XCTAssertEqual(session.state.readiness, .loading)
    }

    func test_coordinator_refreshSameFinderSelection_keepsExistingSessionState() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("demo.swift")
        try "print(1)".write(to: fileURL, atomically: true, encoding: .utf8)

        let session = PreviewSession()
        let coordinator = PreviewCoordinator(
            session: session,
            resolver: PreviewTargetResolver(
                finderSelectionPathProvider: StubFinderSelectionPathProvider(
                    result: .success(fileURL.path)
                )
            )
        )

        try coordinator.handle(.openPath(fileURL.path, source: .service))
        session.markReady()

        try coordinator.handle(.refreshFinderSelection())

        XCTAssertEqual(session.state.target?.resolvedPath, fileURL.path)
        XCTAssertEqual(session.state.readiness, .ready)
    }
}
