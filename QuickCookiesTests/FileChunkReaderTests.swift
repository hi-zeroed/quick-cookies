import XCTest
@testable import QuickCookies

final class FileChunkReaderTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testReadSmallFileInSingleChunk() throws {
        let fileURL = tempDirURL.appendingPathComponent("small.txt")
        try "hello world".write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        let result = reader.readNextChunk(limitBytes: 1024)

        switch result {
        case .success(let payload):
            XCTAssertEqual(payload.content, "hello world")
            XCTAssertEqual(payload.bytesRead, "hello world".lengthOfBytes(using: .utf8))
            XCTAssertFalse(payload.hasMore)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testReadLargeFileAcrossMultipleChunks() throws {
        let content = String(repeating: "abcdefghij", count: 40)
        let fileURL = tempDirURL.appendingPathComponent("large.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        let first = reader.readNextChunk(limitBytes: 50)
        let second = reader.readNextChunk(limitBytes: 500)

        switch first {
        case .success(let payload):
            XCTAssertEqual(payload.bytesRead, 50)
            XCTAssertTrue(payload.hasMore)
        case .failure(let error):
            XCTFail("Unexpected failure in first chunk: \(error)")
        }

        switch second {
        case .success(let payload):
            XCTAssertFalse(payload.content.isEmpty)
        case .failure(let error):
            XCTFail("Unexpected failure in second chunk: \(error)")
        }
    }

    func testReadRemainingReturnsUnreadTailAndClosesHandle() throws {
        let content = "0123456789ABCDEFGHIJ"
        let fileURL = tempDirURL.appendingPathComponent("tail.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        _ = reader.readNextChunk(limitBytes: 10)
        let remaining = reader.readRemaining()

        switch remaining {
        case .success(let tail):
            XCTAssertEqual(tail, "ABCDEFGHIJ")
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }

        let afterClose = reader.readNextChunk(limitBytes: 10)
        switch afterClose {
        case .success:
            XCTFail("Expected closed-handle failure")
        case .failure(let error):
            XCTAssertEqual(
                error.errorDescription,
                FileUtils.FileError.readFailed(path: fileURL.path, reason: "文件句柄已关闭").errorDescription
            )
        }
    }

    func testBinaryFirstChunkFailsImmediately() throws {
        let fileURL = tempDirURL.appendingPathComponent("binary.bin")
        try Data([0x41, 0x00, 0x42, 0x43]).write(to: fileURL)

        let reader = try FileChunkReader(path: fileURL.path)
        let result = reader.readNextChunk(limitBytes: 16)

        switch result {
        case .success:
            XCTFail("Expected binary-file failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.binaryFile(path: fileURL.path).errorDescription)
        }
    }

    func testMissingFileThrowsFileNotFound() {
        let path = tempDirURL.appendingPathComponent("missing.txt").path

        XCTAssertThrowsError(try FileChunkReader(path: path)) { error in
            guard case FileUtils.FileError.fileNotFound(let actualPath) = error else {
                return XCTFail("Expected fileNotFound, got \(error)")
            }
            XCTAssertEqual(actualPath, path)
        }
    }
}
