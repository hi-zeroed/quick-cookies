import XCTest
@testable import QuickCookies

final class FileLiveWatcherTests: XCTestCase {
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

    func testStartReturnsFalseForNonexistentFile() {
        let watcher = FileLiveWatcher(filePath: "/nonexistent/\(UUID().uuidString).txt")
        XCTAssertFalse(watcher.start())
    }

    func testDetectFileModification() throws {
        let fileURL = tempDirectory.appendingPathComponent("watch_mod.txt")
        try "Initial text".write(to: fileURL, atomically: true, encoding: .utf8)

        let exp = expectation(description: "Expect modified event")
        let watcher = FileLiveWatcher(
            filePath: fileURL.path,
            targetQueue: .main,
            debounceInterval: 0.02,
            rearmDelay: 0.03
        )

        watcher.onEvent = { event in
            if event == .modified {
                exp.fulfill()
            }
        }

        XCTAssertTrue(watcher.start())

        // 写入新数据
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(Data(" Appended".utf8))
                try? handle.close()
            }
        }

        waitForExpectations(timeout: 2.0)
        watcher.stop()
    }

    func testAtomicSaveDetectionAndRearm() throws {
        let fileURL = tempDirectory.appendingPathComponent("atomic.txt")
        try "Original Version".write(to: fileURL, atomically: true, encoding: .utf8)

        let exp = expectation(description: "Expect modified event after atomic save")
        let watcher = FileLiveWatcher(
            filePath: fileURL.path,
            targetQueue: .main,
            debounceInterval: 0.02,
            rearmDelay: 0.03
        )

        watcher.onEvent = { event in
            if event == .modified {
                exp.fulfill()
            }
        }

        XCTAssertTrue(watcher.start())

        // 模拟编辑器原子保存：写入 temp 文件并 rename 覆盖原路径
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            let tmpURL = self.tempDirectory.appendingPathComponent("atomic.tmp")
            try? "Edited Version via Atomic Save".write(to: tmpURL, atomically: true, encoding: .utf8)
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
        }

        waitForExpectations(timeout: 2.0)
        watcher.stop()
    }

    func testStopWatcherPreventsFurtherEvents() throws {
        let fileURL = tempDirectory.appendingPathComponent("stopped.txt")
        try "Initial text".write(to: fileURL, atomically: true, encoding: .utf8)

        let exp = expectation(description: "Should not receive event")
        exp.isInverted = true

        let watcher = FileLiveWatcher(
            filePath: fileURL.path,
            targetQueue: .main,
            debounceInterval: 0.02,
            rearmDelay: 0.03
        )

        watcher.onEvent = { _ in
            exp.fulfill()
        }

        XCTAssertTrue(watcher.start())
        watcher.stop()

        // 停止后再写入
        try "Another text".write(to: fileURL, atomically: true, encoding: .utf8)

        waitForExpectations(timeout: 0.3)
    }
}
