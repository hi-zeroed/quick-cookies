import XCTest
@testable import QuickCookies

private struct StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    let result: Result<String, FileDetector.DetectError>

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        result
    }
}

final class FinderMenuIntegrationTests: XCTestCase {
    func test_resolveOpenSelectedFileRequest_returnsMenuBarOpenRequestWhenProviderSucceeds() {
        let integration = FinderMenuIntegration(
            openSelectedFile: {},
            showSettings: {},
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .success("/tmp/demo.md")
            )
        )

        XCTAssertEqual(
            integration.resolveOpenSelectedFileRequest(),
            .request(.openPath("/tmp/demo.md", source: .menuBar))
        )
    }

    func test_resolveOpenSelectedFileRequest_returnsLocalizedFailureWhenProviderFails() {
        let error = FileDetector.DetectError.finderNotRunning
        let integration = FinderMenuIntegration(
            openSelectedFile: {},
            showSettings: {},
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(error)
            )
        )

        guard case let .failure(message, icon) = integration.resolveOpenSelectedFileRequest() else {
            return XCTFail("Expected failure outcome")
        }

        XCTAssertEqual(message, (error.errorDescription ?? "未知错误").localized())
        XCTAssertEqual(icon, "xmark.circle")
    }
}
