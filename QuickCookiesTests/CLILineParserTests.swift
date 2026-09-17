import XCTest
@testable import QuickCookies

final class CLILineParserTests: XCTestCase {

    func test_parseTarget_plainPath_returnsNilLine() {
        let result = CLILineParser.parseTarget("App.swift")
        XCTAssertEqual(result.filePath, "App.swift")
        XCTAssertNil(result.line)
        XCTAssertNil(result.column)
    }

    func test_parseTarget_withLine_returnsCorrectLine() {
        let result = CLILineParser.parseTarget("App.swift:142")
        XCTAssertEqual(result.filePath, "App.swift")
        XCTAssertEqual(result.line, 142)
        XCTAssertNil(result.column)
    }

    func test_parseTarget_withLineAndColumn_returnsCorrectLineAndColumn() {
        let result = CLILineParser.parseTarget("App.swift:142:25")
        XCTAssertEqual(result.filePath, "App.swift")
        XCTAssertEqual(result.line, 142)
        XCTAssertEqual(result.column, 25)
    }

    func test_parseTarget_pathWithColonInDirectory_parsesTrailingNumbersOnly() {
        let result = CLILineParser.parseTarget("/workspace/my:project/App.swift:88")
        XCTAssertEqual(result.filePath, "/workspace/my:project/App.swift")
        XCTAssertEqual(result.line, 88)
        XCTAssertNil(result.column)
    }

    func test_parseTarget_emptyString_returnsEmptyTarget() {
        let result = CLILineParser.parseTarget("   ")
        XCTAssertEqual(result.filePath, "")
        XCTAssertNil(result.line)
    }

    func test_parseArguments_withFlagL_returnsCorrectTarget() {
        let result = CLILineParser.parseArguments(["-l", "142", "src/App.swift"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, "src/App.swift")
        XCTAssertEqual(result?.line, 142)
    }

    func test_parseArguments_withDoubleDashLine_returnsCorrectTarget() {
        let result = CLILineParser.parseArguments(["--line", "88", "src/App.swift"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, "src/App.swift")
        XCTAssertEqual(result?.line, 88)
    }

    func test_parseArguments_withFlagAtEnd_returnsCorrectTarget() {
        let result = CLILineParser.parseArguments(["src/App.swift", "-l", "200"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, "src/App.swift")
        XCTAssertEqual(result?.line, 200)
    }

    func test_parseArguments_embeddedLineInPath_returnsParsedLine() {
        let result = CLILineParser.parseArguments(["src/App.swift:42"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, "src/App.swift")
        XCTAssertEqual(result?.line, 42)
    }

    func test_parseArguments_overrideEmbeddedLineWithExplicitFlag() {
        let result = CLILineParser.parseArguments(["src/App.swift:42", "-l", "99"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, "src/App.swift")
        XCTAssertEqual(result?.line, 99)
    }
}
