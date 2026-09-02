import XCTest
@testable import QuickCookies

final class FolderReaderTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("QuickCookiesFolderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL = tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testMissingFolderThrowsFolderNotFound() async {
        let missingPath = tempDirectoryURL.appendingPathComponent("nonexistent_dir").path
        do {
            _ = try await FolderReader.readFolder(at: missingPath)
            XCTFail("Expected folderNotFound error")
        } catch let error as FolderError {
            XCTAssertEqual(error, .folderNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFileAsFolderThrowsFolderNotFound() async throws {
        let filePath = tempDirectoryURL.appendingPathComponent("file.txt").path
        try "hello".write(toFile: filePath, atomically: true, encoding: .utf8)

        do {
            _ = try await FolderReader.readFolder(at: filePath)
            XCTFail("Expected folderNotFound error")
        } catch let error as FolderError {
            XCTAssertEqual(error, .folderNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadRealLocalFolderHierarchyAndFilterSystemJunk() async throws {
        // 1. 构造多层级本地目录结构与垃圾文件
        let projectDir = tempDirectoryURL.appendingPathComponent("MyProject")
        let srcDir = projectDir.appendingPathComponent("src")
        let docsDir = projectDir.appendingPathComponent("docs")
        let junkDir = projectDir.appendingPathComponent("__MACOSX")

        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: junkDir, withIntermediateDirectories: true)

        try "const a = 1;".write(to: srcDir.appendingPathComponent("index.ts"), atomically: true, encoding: .utf8)
        try "export const b = 2;".write(to: srcDir.appendingPathComponent("utils.ts"), atomically: true, encoding: .utf8)
        try "# Project Guide".write(to: docsDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "ds".write(to: projectDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try "junk".write(to: junkDir.appendingPathComponent("._test"), atomically: true, encoding: .utf8)

        // 2. 异步扫描并验证
        let (summary, entries, tree) = try await FolderReader.readFolder(at: projectDir.path)

        // 验证文件数：3 个有效文件（index.ts, utils.ts, README.md），垃圾文件被过滤
        XCTAssertEqual(summary.fileCount, 3)
        XCTAssertGreaterThanOrEqual(summary.directoryCount, 2) // src, docs
        XCTAssertFalse(tree.isEmpty)

        // 验证不包含垃圾文件
        let allPaths = entries.map { $0.path }
        XCTAssertFalse(allPaths.contains(where: { $0.contains(".DS_Store") }))
        XCTAssertFalse(allPaths.contains(where: { $0.contains("__MACOSX") }))

        // 验证目录树结构
        let srcNode = tree.first(where: { $0.name == "src" })
        XCTAssertNotNil(srcNode)
        XCTAssertTrue(srcNode?.isDirectory == true)
        XCTAssertEqual(srcNode?.children.count, 2)
        XCTAssertGreaterThan(srcNode?.uncompressedSize ?? 0, 0)
    }

    func testReadEmptyFolderReturnsEmptySummary() async throws {
        let emptyDir = tempDirectoryURL.appendingPathComponent("EmptyDir")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let (summary, entries, tree) = try await FolderReader.readFolder(at: emptyDir.path)
        XCTAssertEqual(summary.fileCount, 0)
        XCTAssertEqual(summary.directoryCount, 0)
        XCTAssertEqual(summary.totalUncompressedSize, 0)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(tree.isEmpty)
    }

    func testHeavyDirectoryNamesFiltering() {
        // 验证前端、Python、Rust、Go、Java、Apple 等重型目录均被标记
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: "node_modules"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: ".pnpm"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: ".git"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: ".venv"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: "__pycache__"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: "target"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: "DerivedData"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: "Pods"))
        XCTAssertTrue(FolderReader.isHeavyDirectory(name: ".gradle"))

        // 普通业务目录不应被标记
        XCTAssertFalse(FolderReader.isHeavyDirectory(name: "src"))
        XCTAssertFalse(FolderReader.isHeavyDirectory(name: "components"))
        XCTAssertFalse(FolderReader.isHeavyDirectory(name: "docs"))
    }
}
