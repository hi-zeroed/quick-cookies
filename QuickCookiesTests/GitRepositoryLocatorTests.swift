import XCTest
@testable import QuickCookies

final class GitRepositoryLocatorTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuickCookies_GitRepoTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirURL = tempDirURL {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        try super.tearDownWithError()
    }

    func testFindGitDirectoryInGitRepo() throws {
        // 创建模拟 git 仓库
        let gitDir = tempDirURL.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let fileURL = tempDirURL.appendingPathComponent("test.swift")
        try "print(1)".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = GitRepositoryLocator.findGitDirectory(for: fileURL.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.standardizedFileURL.path, gitDir.standardizedFileURL.path)
    }

    func testFindGitDirectoryInDeepSubdirectory() throws {
        let gitDir = tempDirURL.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let deepDir = tempDirURL.appendingPathComponent("Sources/App/Core")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)

        let fileURL = deepDir.appendingPathComponent("Main.swift")
        try "// code".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = GitRepositoryLocator.findGitDirectory(for: fileURL.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.standardizedFileURL.path, gitDir.standardizedFileURL.path)
    }

    func testFindGitDirectoryWhenNotInRepo() throws {
        let nonRepoDir = tempDirURL.appendingPathComponent("NonRepo")
        try FileManager.default.createDirectory(at: nonRepoDir, withIntermediateDirectories: true)

        let fileURL = nonRepoDir.appendingPathComponent("document.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = GitRepositoryLocator.findGitDirectory(for: fileURL.path)
        XCTAssertNil(result)
    }

    func testResolveRepositoryContext() throws {
        let gitDir = tempDirURL.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let subDir = tempDirURL.appendingPathComponent("Sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let fileURL = subDir.appendingPathComponent("file.txt")
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)

        let context = GitRepositoryLocator.resolveContext(for: fileURL.path)
        XCTAssertNotNil(context)
        XCTAssertEqual(context?.repoRootURL.standardizedFileURL.path, tempDirURL.standardizedFileURL.path)
        XCTAssertEqual(context?.relativePath, "Sub/file.txt")
    }
}
