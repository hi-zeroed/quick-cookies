import XCTest
@testable import QuickCookies

private struct StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    let result: Result<String, FileDetector.DetectError>

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        result
    }
}

final class PreviewTargetTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func test_resolver_directPath_resolvesSymlinkAndClassifiesType() throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("demo.swift")
        try "print(1)".write(to: fileURL, atomically: true, encoding: .utf8)

        let symlinkURL = tempDirectoryURL.appendingPathComponent("demo-link.swift")
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: fileURL
        )

        let resolver = PreviewTargetResolver(
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(.noFileSelected)
            )
        )

        let target = try resolver.resolve(
            request: .openPath(symlinkURL.path, source: .service)
        )

        XCTAssertEqual(target.originalPath, symlinkURL.path)
        XCTAssertEqual(target.resolvedPath, fileURL.path)
        XCTAssertEqual(target.renderType, .code)
        XCTAssertEqual(target.language, "swift")
        XCTAssertEqual(target.displayName, "demo.swift")
    }

    func test_resolver_finderSelectionWithoutSelection_throwsStructuredError() {
        let resolver = PreviewTargetResolver(
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(.noFileSelected)
            )
        )

        XCTAssertThrowsError(
            try resolver.resolve(request: .toggleFromFinderHotkey())
        ) { error in
            XCTAssertEqual(error as? PreviewTargetError, .noFinderSelection)
        }
    }

    func test_resolver_finderSelectionWhenFinderNotRunning_stillThrowsNoFinderSelection() {
        let resolver = PreviewTargetResolver(
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(.finderNotRunning)
            )
        )

        XCTAssertThrowsError(
            try resolver.resolve(request: .toggleFromFinderHotkey())
        ) { error in
            XCTAssertEqual(error as? PreviewTargetError, .noFinderSelection)
        }
    }

    func test_resolver_directoryPath_returnsUnsupportedPresentationTarget() throws {
        let directoryURL = tempDirectoryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let resolver = PreviewTargetResolver(
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(.noFileSelected)
            )
        )

        let target = try resolver.resolve(
            request: .openPath(directoryURL.path, source: .service)
        )

        XCTAssertEqual(target.originalPath, directoryURL.path)
        XCTAssertEqual(target.resolvedPath, directoryURL.path)
        XCTAssertEqual(target.renderType, .unsupported)
        XCTAssertNil(target.language)
        XCTAssertEqual(target.displayName, "Folder")
    }
}
