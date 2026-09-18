import XCTest
@testable import QuickCookies

final class UniversalPathResolverTests: XCTestCase {

    private var temporaryDirectoryURL: URL!
    private var sampleFileURL: URL!
    private var sampleDirURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("UniversalPathResolverTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.temporaryDirectoryURL = tempDir

        self.sampleFileURL = tempDir.appendingPathComponent("demo.swift")
        try "print(\"hello world\")".write(to: sampleFileURL, atomically: true, encoding: .utf8)

        self.sampleDirURL = tempDir.appendingPathComponent("SubFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: sampleDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testResolve_emptyOrWhitespace_returnsNil() {
        XCTAssertNil(UniversalPathResolver.resolve(""))
        XCTAssertNil(UniversalPathResolver.resolve("   \n\t  "))
    }

    func testResolve_standardAbsolutePath_returnsValidTarget() {
        let result = UniversalPathResolver.resolve(sampleFileURL.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertFalse(result?.isDirectory ?? true)
        XCTAssertNil(result?.targetLine)
    }

    func testResolve_directoryPath_returnsValidDirectoryTarget() {
        let result = UniversalPathResolver.resolve(sampleDirURL.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleDirURL.standardized.path)
        XCTAssertTrue(result?.isDirectory ?? false)
    }

    func testResolve_pathWithLineNumber_extractsLineCorrectly() {
        let input = "\(sampleFileURL.path):142"
        let result = UniversalPathResolver.resolve(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(result?.targetLine, 142)
    }

    func testResolve_pathWithLineAndColumnNumber_extractsLineCorrectly() {
        let input = "\(sampleFileURL.path):88:15"
        let result = UniversalPathResolver.resolve(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(result?.targetLine, 88)
    }

    func testResolve_quotedPath_stripsQuotesCorrectly() {
        let doubleQuoted = "\"\(sampleFileURL.path)\""
        let singleQuoted = "'\(sampleFileURL.path):25'"
        let backticked = "`\(sampleFileURL.path):99`"

        let r1 = UniversalPathResolver.resolve(doubleQuoted)
        XCTAssertEqual(r1?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertNil(r1?.targetLine)

        let r2 = UniversalPathResolver.resolve(singleQuoted)
        XCTAssertEqual(r2?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(r2?.targetLine, 25)

        let r3 = UniversalPathResolver.resolve(backticked)
        XCTAssertEqual(r3?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(r3?.targetLine, 99)
    }

    func testResolve_parenthesesEnclosedPath_stripsParenthesesCorrectly() {
        let input = "(\(sampleFileURL.path):50)"
        let result = UniversalPathResolver.resolve(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(result?.targetLine, 50)
    }

    func testResolve_fileURLProtocol_resolvesCorrectly() {
        let input = sampleFileURL.absoluteString
        let result = UniversalPathResolver.resolve(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
    }

    func testResolve_tildePath_expandsHomeDirectory() {
        let homePath = ("~" as NSString).expandingTildeInPath
        let result = UniversalPathResolver.resolve("~")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, URL(fileURLWithPath: homePath).standardized.path)
        XCTAssertTrue(result?.isDirectory ?? false)
    }

    func testResolve_embeddedPathInErrorMessage_extractsSuccessfully() {
        let logLine = "Fatal error: unexpected nil at \(sampleFileURL.path):33 in test runner"
        let result = UniversalPathResolver.resolve(logLine)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(result?.targetLine, 33)
    }

    func testResolve_nonExistentPath_returnsNil() {
        let nonExistent = temporaryDirectoryURL.appendingPathComponent("ghost_file_404.txt").path
        XCTAssertNil(UniversalPathResolver.resolve(nonExistent))
        XCTAssertNil(UniversalPathResolver.resolve("Just some random text without any path."))
    }

    func testResolve_pathWithSpaces_resolvesCorrectly() throws {
        let spaceDir = temporaryDirectoryURL.appendingPathComponent("Folder With Spaces", isDirectory: true)
        try FileManager.default.createDirectory(at: spaceDir, withIntermediateDirectories: true)
        let spaceFile = spaceDir.appendingPathComponent("my file.swift")
        try "let a = 1".write(to: spaceFile, atomically: true, encoding: .utf8)

        let input = "\"\(spaceFile.path):15\""
        let result = UniversalPathResolver.resolve(input)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, spaceFile.standardized.path)
        XCTAssertEqual(result?.targetLine, 15)
    }

    func testResolve_embeddedQuotedPathWithSpacesInSentence_resolvesCorrectly() throws {
        let spaceDir = temporaryDirectoryURL.appendingPathComponent("Project Space", isDirectory: true)
        try FileManager.default.createDirectory(at: spaceDir, withIntermediateDirectories: true)
        let spaceFile = spaceDir.appendingPathComponent("script file.py")
        try "print(1)".write(to: spaceFile, atomically: true, encoding: .utf8)

        let sentence = "Check exception thrown at '\(spaceFile.path):88' in background thread"
        let result = UniversalPathResolver.resolve(sentence)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, spaceFile.standardized.path)
        XCTAssertEqual(result?.targetLine, 88)
    }

    func testResolve_nestedDelimiters_stripsCorrectly() {
        let nested = "([\"`\(sampleFileURL.path):45`\"])"
        let result = UniversalPathResolver.resolve(nested)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileURL.standardized.path, sampleFileURL.standardized.path)
        XCTAssertEqual(result?.targetLine, 45)
    }

    func testLocalization_universalPeekStrings_supportEnglishAndChinese() {
        let savedLang = Settings.currentLanguage
        defer { Settings.currentLanguage = savedLang }

        Settings.currentLanguage = .en
        XCTAssertEqual("No valid file path found".localized(), "No valid file path found")
        XCTAssertEqual("Preview with QuickCookies".localized(), "Preview with QuickCookies")
        XCTAssertEqual("Inspect Clipboard".localized(), "Preview Clipboard")
        XCTAssertEqual("File Info (⌘I)".localized(), "File Info (⌘I)")

        Settings.currentLanguage = .zhHans
        XCTAssertEqual("No valid file path found".localized(), "未检测到本地文件路径")
        XCTAssertEqual("Preview with QuickCookies".localized(), "使用 QuickCookies 预览")
        XCTAssertEqual("Inspect Clipboard".localized(), "预览剪贴板")
        XCTAssertEqual("File Info (⌘I)".localized(), "文件信息 (⌘I)")
        XCTAssertEqual("Inspect in Hex".localized(), "以十六进制查看")
    }
}
