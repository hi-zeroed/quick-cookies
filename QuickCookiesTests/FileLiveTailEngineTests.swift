import XCTest
@testable import QuickCookies

final class FileLiveTailEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testIsLogFileDetection() {
        XCTAssertTrue(FileLiveTailEngine.isLogFile(path: "/var/log/system.log"))
        XCTAssertTrue(FileLiveTailEngine.isLogFile(path: "/tmp/APP.LOG"))
        XCTAssertTrue(FileLiveTailEngine.isLogFile(path: "debug.Log"))
        XCTAssertFalse(FileLiveTailEngine.isLogFile(path: "/src/main.swift"))
        XCTAssertFalse(FileLiveTailEngine.isLogFile(path: "/docs/readme.txt"))
    }

    func testReadAppendedTextIncremental() throws {
        let logURL = tempDirectory.appendingPathComponent("test.log")
        let initialText = "2026-09-17 12:00:00 [INFO] System started\n"
        try initialText.write(to: logURL, atomically: true, encoding: .utf8)

        let initialSize = UInt64(initialText.utf8.count)
        let engine = FileLiveTailEngine(initialOffset: initialSize)
        XCTAssertEqual(engine.currentOffset, initialSize)

        // 第一次读取（无变化）
        let noChangeResult = engine.readAppendedText(at: logURL.path)
        XCTAssertEqual(noChangeResult, .noChange)

        // 追加一行
        let appendLine1 = "2026-09-17 12:00:01 [DEBUG] Connecting to socket...\n"
        let handle = try FileHandle(forWritingTo: logURL)
        handle.seekToEndOfFile()
        handle.write(Data(appendLine1.utf8))
        try handle.close()

        // 增量读取
        let result1 = engine.readAppendedText(at: logURL.path)
        if case .appended(let text, let newOffset) = result1 {
            XCTAssertEqual(text, appendLine1)
            XCTAssertEqual(newOffset, initialSize + UInt64(appendLine1.utf8.count))
        } else {
            XCTFail("Expected .appended, got \(result1)")
        }

        // 再次追加中文日志
        let appendLine2 = "2026-09-17 12:00:02 [SUCCESS] 连接已建立 🚀\n"
        let handle2 = try FileHandle(forWritingTo: logURL)
        handle2.seekToEndOfFile()
        handle2.write(Data(appendLine2.utf8))
        try handle2.close()

        let result2 = engine.readAppendedText(at: logURL.path)
        if case .appended(let text, _) = result2 {
            XCTAssertEqual(text, appendLine2)
        } else {
            XCTFail("Expected .appended, got \(result2)")
        }
    }

    func testLogTruncationDetection() throws {
        let logURL = tempDirectory.appendingPathComponent("truncate.log")
        let text = "Line 1\nLine 2\nLine 3\n"
        try text.write(to: logURL, atomically: true, encoding: .utf8)

        let engine = FileLiveTailEngine(initialOffset: UInt64(text.utf8.count))

        // 清空截断文件
        let truncatedText = "Restart\n"
        try truncatedText.write(to: logURL, atomically: true, encoding: .utf8)

        let result = engine.readAppendedText(at: logURL.path)
        if case .truncated(let newSize) = result {
            XCTAssertEqual(newSize, UInt64(truncatedText.utf8.count))
            XCTAssertEqual(engine.currentOffset, UInt64(truncatedText.utf8.count))
        } else {
            XCTFail("Expected .truncated, got \(result)")
        }
    }

    func testReadAppendedTextFileNotFound() {
        let engine = FileLiveTailEngine(initialOffset: 0)
        let result = engine.readAppendedText(at: "/nonexistent/path/never.log")
        if case .failure = result {
            // Success
        } else {
            XCTFail("Expected .failure, got \(result)")
        }
    }
}
