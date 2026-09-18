import XCTest
@testable import QuickCookies

final class ArchiveReaderTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("QuickCookiesArchiveTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL = tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testMissingFileThrowsFileNotFound() async {
        let missingPath = tempDirectoryURL.appendingPathComponent("nonexistent.zip").path
        do {
            _ = try await ArchiveReader.readArchive(at: missingPath)
            XCTFail("Expected fileNotFound error")
        } catch let error as ArchiveError {
            XCTAssertEqual(error, .fileNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnsupportedExtensionThrowsUnsupportedFormat() async throws {
        let dummyPath = tempDirectoryURL.appendingPathComponent("test.txt").path
        try "Hello".write(toFile: dummyPath, atomically: true, encoding: .utf8)

        do {
            _ = try await ArchiveReader.readArchive(at: dummyPath)
            XCTFail("Expected unsupportedFormat error")
        } catch let error as ArchiveError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadRealZipArchiveAndExtractSubfile() async throws {
        // 1. 在临时目录创建子文件并用系统 zip 打包
        let sourceDir = tempDirectoryURL.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let file1 = sourceDir.appendingPathComponent("hello.txt")
        try "Hello World QuickCookies".write(to: file1, atomically: true, encoding: .utf8)

        let subDir = sourceDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file2 = subDir.appendingPathComponent("sub.md")
        try "# Markdown in Zip".write(to: file2, atomically: true, encoding: .utf8)

        let zipPath = tempDirectoryURL.appendingPathComponent("test.zip").path

        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "hello.txt", "nested"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        // 2. 读取并验证目录树
        let (summary, entries, tree) = try await ArchiveReader.readArchive(at: zipPath)
        XCTAssertGreaterThanOrEqual(summary.totalEntries, 2)
        XCTAssertEqual(summary.formatName, "ZIP Archive")
        XCTAssertFalse(entries.isEmpty)
        XCTAssertFalse(tree.isEmpty)

        // 3. 验证内存管道流式提取单个子文件
        let data = try await ArchiveReader.readSubfileData(archivePath: zipPath, entryPath: "hello.txt")
        let text = String(data: data, encoding: .utf8)
        XCTAssertEqual(text, "Hello World QuickCookies")

        let subData = try await ArchiveReader.readSubfileData(archivePath: zipPath, entryPath: "nested/sub.md")
        let subText = String(data: subData, encoding: .utf8)
        XCTAssertEqual(subText, "# Markdown in Zip")
    }

    func testReadArchiveWithChineseAndFilterSystemJunk() async throws {
        // 1. 创建包含中文文件名和系统隐藏垃圾文件的 zip
        let sourceDir = tempDirectoryURL.appendingPathComponent("chinese_source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let zhDir = sourceDir.appendingPathComponent("模块设计")
        try FileManager.default.createDirectory(at: zhDir, withIntermediateDirectories: true)
        let zhFile = zhDir.appendingPathComponent("01-核心架构说明.md")
        try "# 架构设计方案内容".write(to: zhFile, atomically: true, encoding: .utf8)

        let macosXDir = sourceDir.appendingPathComponent("__MACOSX")
        try FileManager.default.createDirectory(at: macosXDir, withIntermediateDirectories: true)
        let junkFork = macosXDir.appendingPathComponent("._test")
        try "resource-fork".write(to: junkFork, atomically: true, encoding: .utf8)

        let dsStore = sourceDir.appendingPathComponent(".DS_Store")
        try "ds".write(to: dsStore, atomically: true, encoding: .utf8)

        let zipPath = tempDirectoryURL.appendingPathComponent("chinese_test.zip").path

        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "模块设计", "__MACOSX", ".DS_Store"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        // 2. 解析并验证：中文无乱码且垃圾文件被成功过滤
        let (summary, entries, tree) = try await ArchiveReader.readArchive(at: zipPath)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertFalse(tree.isEmpty)

        // 验证过滤：不包含 __MACOSX 与 .DS_Store
        let allPaths = entries.map { $0.path }
        XCTAssertFalse(allPaths.contains(where: { $0.contains("__MACOSX") }))
        XCTAssertFalse(allPaths.contains(where: { $0.contains(".DS_Store") }))

        // 验证中文正确解析（绝无 ???? 乱码）
        let hasChineseDoc = allPaths.contains(where: { $0.contains("01-核心架构说明.md") })
        XCTAssertTrue(hasChineseDoc, "Expected Chinese filename to be correctly preserved")

        // 3. 验证提取中文子文件内容
        let data = try await ArchiveReader.readSubfileData(archivePath: zipPath, entryPath: "模块设计/01-核心架构说明.md")
        let content = String(data: data, encoding: .utf8)
        XCTAssertEqual(content, "# 架构设计方案内容")
    }

    func testIsSystemJunkEntryLogic() {
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "__MACOSX/._file"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "folder/__MACOSX/._sub"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "__MACOSX"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "path/to/.DS_Store"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: ".DS_Store"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "folder/._hidden_fork.swift"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "Thumbs.db"))
        XCTAssertTrue(ArchiveReader.isSystemJunkEntry(path: "desktop.ini"))

        XCTAssertFalse(ArchiveReader.isSystemJunkEntry(path: "src/index.ts"))
        XCTAssertFalse(ArchiveReader.isSystemJunkEntry(path: "中文目录/文档.md"))
        XCTAssertFalse(ArchiveReader.isSystemJunkEntry(path: ".gitignore"))
        XCTAssertFalse(ArchiveReader.isSystemJunkEntry(path: "package.json"))
    }

    func testCategoryClassificationAndBreakdownCalculation() async throws {
        // 1. 验证扩展名归类
        XCTAssertEqual(ArchiveCategory.category(for: "swift"), .code)
        XCTAssertEqual(ArchiveCategory.category(for: "ts"), .code)
        XCTAssertEqual(ArchiveCategory.category(for: "md"), .document)
        XCTAssertEqual(ArchiveCategory.category(for: "png"), .image)
        XCTAssertEqual(ArchiveCategory.category(for: "json"), .config)
        XCTAssertEqual(ArchiveCategory.category(for: "bin"), .other)

        // 2. 构造多种类别的压缩包测试聚合 breakdown
        let sourceDir = tempDirectoryURL.appendingPathComponent("breakdown_source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        try "let a = 1".write(to: sourceDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try "# Doc".write(to: sourceDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "{\"k\": 1}".write(to: sourceDir.appendingPathComponent("app.json"), atomically: true, encoding: .utf8)

        let zipPath = tempDirectoryURL.appendingPathComponent("breakdown_test.zip").path

        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "main.swift", "README.md", "app.json"]
        try process.run()
        process.waitUntilExit()

        let (summary, _, _) = try await ArchiveReader.readArchive(at: zipPath)
        XCTAssertEqual(summary.fileCount, 3)
        XCTAssertFalse(summary.categoryBreakdowns.isEmpty)

        let categories = summary.categoryBreakdowns.map { $0.category }
        XCTAssertTrue(categories.contains(.code))
        XCTAssertTrue(categories.contains(.document))
        XCTAssertTrue(categories.contains(.config))
    }

    func testReadEmptyZipArchiveReturnsEmptyTreeAndZeroFiles() async throws {
        // 创建一个空的 zip 文件（标准 22 字节 EOCD 记录）
        let emptyZipPath = tempDirectoryURL.appendingPathComponent("empty.zip").path
        let emptyZipBytes: [UInt8] = [
            0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        try Data(emptyZipBytes).write(to: URL(fileURLWithPath: emptyZipPath))

        let (summary, entries, tree) = try await ArchiveReader.readArchive(at: emptyZipPath)
        XCTAssertEqual(summary.fileCount, 0)
        XCTAssertTrue(entries.isEmpty || entries.allSatisfy { $0.isDirectory })
    }

    func testReadTarGzArchiveWithSpacesInFilenames() async throws {
        // 创建包含空格文件名的 tar.gz
        let sourceDir = tempDirectoryURL.appendingPathComponent("spaces_source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let fileWithSpace = sourceDir.appendingPathComponent("Annual Report 2026 Final.pdf")
        try "PDF Data".write(to: fileWithSpace, atomically: true, encoding: .utf8)

        let tgzPath = tempDirectoryURL.appendingPathComponent("spaces_test.tar.gz").path

        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", tgzPath, "Annual Report 2026 Final.pdf"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let (summary, entries, tree) = try await ArchiveReader.readArchive(at: tgzPath)
        XCTAssertEqual(summary.fileCount, 1)
        XCTAssertEqual(summary.formatName, "TAR.GZ Archive")
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries[0].fileName, "Annual Report 2026 Final.pdf")
        XCTAssertEqual(tree[0].name, "Annual Report 2026 Final.pdf")
    }
}
