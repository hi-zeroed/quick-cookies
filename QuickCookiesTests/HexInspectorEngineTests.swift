import XCTest
@testable import QuickCookies

final class HexInspectorEngineTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let url = tempDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }

    func testFormatData_emptyData_returnsEmptyRows() {
        let rows = HexInspectorEngine.formatData(Data())
        XCTAssertTrue(rows.isEmpty)
    }

    func testFormatData_exact16Bytes_formatsSingleRow() {
        // "Hello, World! 12" -> 16 bytes
        let testString = "Hello, World! 12"
        let data = Data(testString.utf8)
        XCTAssertEqual(data.count, 16)

        let rows = HexInspectorEngine.formatData(data)
        XCTAssertEqual(rows.count, 1)

        let row = rows[0]
        XCTAssertEqual(row.offset, 0)
        XCTAssertEqual(row.offsetString, "00000000")
        XCTAssertEqual(row.byteCount, 16)
        XCTAssertEqual(row.asciiDump, "Hello, World! 12")

        // First 8 bytes: "Hello, W" -> 48 65 6C 6C 6F 2C 20 57
        XCTAssertEqual(row.hexPart1, "48 65 6C 6C 6F 2C 20 57")
        // Next 8 bytes: "orld! 12" -> 6F 72 6C 64 21 20 31 32
        XCTAssertEqual(row.hexPart2, "6F 72 6C 64 21 20 31 32")
    }

    func testFormatData_lessThan16Bytes_formatsPartialRow() {
        // "Hello" -> 5 bytes
        let data = Data("Hello".utf8)
        let rows = HexInspectorEngine.formatData(data, baseOffset: 0x100)
        XCTAssertEqual(rows.count, 1)

        let row = rows[0]
        XCTAssertEqual(row.offset, 0x100)
        XCTAssertEqual(row.offsetString, "00000100")
        XCTAssertEqual(row.byteCount, 5)
        XCTAssertEqual(row.asciiDump, "Hello")
        XCTAssertEqual(row.hexPart1, "48 65 6C 6C 6F")
        XCTAssertEqual(row.hexPart2, "")
    }

    func testFormatData_unprintableCharacters_replacedWithDot() {
        // 0x00, 0x0A, 0x1F, 0x7F, 0x80, 'A' (0x41)
        let bytes: [UInt8] = [0x00, 0x0A, 0x1F, 0x7F, 0x80, 0x41]
        let data = Data(bytes)

        let rows = HexInspectorEngine.formatData(data)
        XCTAssertEqual(rows.count, 1)

        let row = rows[0]
        // 0x00, 0x0A, 0x1F are < 0x20 -> '.'
        // 0x7F is del -> '.'
        // 0x80 is > 0x7E -> '.'
        // 0x41 is 'A' -> 'A'
        XCTAssertEqual(row.asciiDump, ".....A")
        XCTAssertEqual(row.hexPart1, "00 0A 1F 7F 80 41")
    }

    func testFormatData_multiRows_calculatesOffsetCorrectly() {
        // 35 bytes -> 16 + 16 + 3 -> 3 rows
        var bytes = [UInt8](repeating: 0x41, count: 35)
        bytes[0] = 0x31 // '1'
        bytes[16] = 0x32 // '2'
        bytes[32] = 0x33 // '3'
        let data = Data(bytes)

        let rows = HexInspectorEngine.formatData(data, baseOffset: 0x20)
        XCTAssertEqual(rows.count, 3)

        XCTAssertEqual(rows[0].offset, 0x20)
        XCTAssertEqual(rows[0].offsetString, "00000020")
        XCTAssertEqual(rows[0].byteCount, 16)
        XCTAssertTrue(rows[0].asciiDump.hasPrefix("1"))

        XCTAssertEqual(rows[1].offset, 0x30)
        XCTAssertEqual(rows[1].offsetString, "00000030")
        XCTAssertEqual(rows[1].byteCount, 16)
        XCTAssertTrue(rows[1].asciiDump.hasPrefix("2"))

        XCTAssertEqual(rows[2].offset, 0x40)
        XCTAssertEqual(rows[2].offsetString, "00000040")
        XCTAssertEqual(rows[2].byteCount, 3)
        XCTAssertEqual(rows[2].asciiDump, "3AA")
    }

    func testInspectFile_nonExistentFile_returnsNil() {
        let result = HexInspectorEngine.inspectFile(at: "/path/to/non/existent/file.bin")
        XCTAssertNil(result)
    }

    func testInspectFile_realBinaryFile_readsCorrectRowsAndMetadata() throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("sample.bin")
        let binaryBytes: [UInt8] = [
            0x7F, 0x45, 0x4C, 0x46, // \x7fELF
            0x02, 0x01, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x03, 0x00, 0x3E, 0x00
        ]
        try Data(binaryBytes).write(to: fileURL)

        guard let result = HexInspectorEngine.inspectFile(at: fileURL.path) else {
            XCTFail("Expected valid inspect result")
            return
        }

        XCTAssertEqual(result.totalFileSize, 20)
        XCTAssertEqual(result.loadedByteCount, 20)
        XCTAssertFalse(result.hasMore)
        XCTAssertEqual(result.rows.count, 2)

        XCTAssertEqual(result.rows[0].offsetString, "00000000")
        XCTAssertEqual(result.rows[0].hexPart1, "7F 45 4C 46 02 01 01 00")
        XCTAssertEqual(result.rows[0].hexPart2, "00 00 00 00 00 00 00 00")
        XCTAssertEqual(result.rows[0].asciiDump, ".ELF............")

        XCTAssertEqual(result.rows[1].offsetString, "00000010")
        XCTAssertEqual(result.rows[1].hexPart1, "03 00 3E 00")
        XCTAssertEqual(result.rows[1].hexPart2, "")
        XCTAssertEqual(result.rows[1].asciiDump, "..>.")
    }

    func testInspectFile_chunkLimit_respectsHasMore() throws {
        let fileURL = tempDirectoryURL.appendingPathComponent("large.bin")
        let testData = Data(repeating: 0x90, count: 100) // 100 bytes of NOP
        try testData.write(to: fileURL)

        guard let result = HexInspectorEngine.inspectFile(at: fileURL.path, offset: 0, limit: 32) else {
            XCTFail("Expected valid inspect result")
            return
        }

        XCTAssertEqual(result.totalFileSize, 100)
        XCTAssertEqual(result.loadedByteCount, 32)
        XCTAssertTrue(result.hasMore)
        XCTAssertEqual(result.rows.count, 2) // 32 / 16 = 2
    }
}
