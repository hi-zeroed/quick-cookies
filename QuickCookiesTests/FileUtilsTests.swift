import XCTest
@testable import QuickCookies

final class FileUtilsTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testResolveSymlinkReturnsDestinationPath() throws {
        let target = tempDirURL.appendingPathComponent("target.txt")
        let link = tempDirURL.appendingPathComponent("link.txt")
        try "hello".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertEqual(FileUtils.resolveSymlink(at: link.path), target.path)
    }

    func testReadFileReturnsContentAndEncoding() throws {
        let fileURL = tempDirURL.appendingPathComponent("read.txt")
        try "sample".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success(let payload):
            XCTAssertEqual(payload.content, "sample")
            XCTAssertEqual(payload.encoding, .utf8)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testReadFileRejectsBinaryData() throws {
        let fileURL = tempDirURL.appendingPathComponent("binary.bin")
        try Data([0x41, 0x00, 0x42]).write(to: fileURL)

        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success:
            XCTFail("Expected binary-file failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.binaryFile(path: fileURL.path).errorDescription)
        }
    }

    func testReadFileReturnsFileNotFound() {
        let fileURL = tempDirURL.appendingPathComponent("missing.txt")
        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success:
            XCTFail("Expected file-not-found failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.fileNotFound(path: fileURL.path).errorDescription)
        }
    }

    func testReadLimitFileMarksLargeInputAsTruncated() throws {
        let fileURL = tempDirURL.appendingPathComponent("large.txt")
        let content = String(repeating: "1234567890", count: 100)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = FileUtils.readLimitFile(at: fileURL.path, limitBytes: 50)

        switch result {
        case .success(let payload):
            XCTAssertTrue(payload.isTruncated)
            XCTAssertEqual(payload.content.utf8.count, 50)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testWriteFilePersistsUTF8Content() throws {
        let fileURL = tempDirURL.appendingPathComponent("write.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let write = FileUtils.writeFile(at: fileURL.path, content: "saved")
        XCTAssertTrue({
            if case .success = write { return true }
            return false
        }())

        let stored = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(stored, "saved")
    }
}
