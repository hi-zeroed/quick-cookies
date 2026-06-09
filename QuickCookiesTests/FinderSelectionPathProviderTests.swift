import XCTest
@testable import QuickCookies

final class FinderSelectionPathProviderTests: XCTestCase {
    func test_selectedPath_returnsFinderNotRunningWhenFinderIsUnavailable() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { false },
            selectionScriptFactory: {
                XCTFail("Finder 未运行时不应初始化脚本")
                return nil
            },
            executeScript: { _ in
                XCTFail("Finder 未运行时不应执行脚本")
                return .failure(.finderNotRunning)
            }
        )

        let result: Result<String, FileDetector.DetectError> = provider.selectedPath()

        XCTAssertEqual(result, .failure(.finderNotRunning))
    }

    func test_selectedPath_returnsScriptInitializationFailureWhenScriptFactoryReturnsNil() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { nil },
            executeScript: { _ in
                XCTFail("脚本初始化失败时不应执行脚本")
                return .failure(.finderNotRunning)
            }
        )

        let result: Result<String, FileDetector.DetectError> = provider.selectedPath()

        XCTAssertEqual(result, .failure(.scriptingBridgeError("无法初始化 AppleScript 脚本")))
    }

    func test_selectedPath_returnsExecutionFailureFromInjectedExecutor() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"ignored\"") },
            executeScript: { _ in
                .failure(.scriptingBridgeError("执行失败"))
            }
        )

        let result: Result<String, FileDetector.DetectError> = provider.selectedPath()

        XCTAssertEqual(result, .failure(.scriptingBridgeError("执行失败")))
    }

    func test_selectedPath_returnsNoSelectionWhenExecutorReportsEmptySelection() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"ignored\"") },
            executeScript: { _ in
                .failure(.noFileSelected)
            }
        )

        let result: Result<String, FileDetector.DetectError> = provider.selectedPath()

        XCTAssertEqual(result, .failure(.noFileSelected))
    }

    func test_selectedPath_returnsResolvedPathWhenExecutorSucceeds() {
        let expectedPath = "/tmp/example.txt"
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"ignored\"") },
            executeScript: { _ in
                .success(expectedPath)
            }
        )

        let result: Result<String, FileDetector.DetectError> = provider.selectedPath()

        XCTAssertEqual(result, .success(expectedPath))
    }
}
