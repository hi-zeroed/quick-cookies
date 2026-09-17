import XCTest
@testable import QuickCookies

final class TelemetryExtractorTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TelemetryExtractorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testExtractTextTelemetry_swiftCode_computesLoCAndComments() {
        let code = """
        // Header comment
        import Foundation

        /* Multi-line
           comment block */
        func hello() {
            print("Hello, world!")
        }

        #if DEBUG
        // Debug helper
        #endif
        """
        let fileURL = tempDirectory.appendingPathComponent("Sample.swift")
        try! code.write(to: fileURL, atomically: true, encoding: .utf8)

        let items = TelemetryExtractor.extractTextTelemetry(
            url: fileURL,
            renderType: .code,
            existingContent: code
        )

        let linesItem = items.first { $0.id == "lines" }
        let locItem = items.first { $0.id == "loc" }
        let commentsItem = items.first { $0.id == "comments" }
        let blankItem = items.first { $0.id == "blank" }
        let formatItem = items.first { $0.id == "format" }
        let encodingItem = items.first { $0.id == "encoding" }

        XCTAssertNotNil(linesItem)
        XCTAssertEqual(linesItem?.value, "12")
        XCTAssertNotNil(locItem)
        XCTAssertNotNil(commentsItem)
        XCTAssertNotNil(blankItem)
        XCTAssertEqual(blankItem?.value, "2")
        XCTAssertEqual(formatItem?.value, "LF")
        XCTAssertEqual(encodingItem?.value, "UTF-8")
    }

    func testExtractTextTelemetry_crlfLineEndings_detectsCRLF() {
        let text = "line1\r\nline2\r\nline3"
        let fileURL = tempDirectory.appendingPathComponent("Windows.txt")
        try! text.write(to: fileURL, atomically: true, encoding: .utf8)

        let items = TelemetryExtractor.extractTextTelemetry(
            url: fileURL,
            renderType: .plainText,
            existingContent: text
        )

        let formatItem = items.first { $0.id == "format" }
        XCTAssertEqual(formatItem?.value, "CRLF")
    }

    func testExtractTextTelemetry_jsonFile_extractsKeysAndDepth() {
        let json = """
        {
            "name": "QuickCookies",
            "version": "1.8.0",
            "config": {
                "theme": "dark",
                "nested": {
                    "level": 3
                }
            },
            "tags": ["macOS", "Swift"]
        }
        """
        let fileURL = tempDirectory.appendingPathComponent("data.json")
        try! json.write(to: fileURL, atomically: true, encoding: .utf8)

        let items = TelemetryExtractor.extractTextTelemetry(
            url: fileURL,
            renderType: .code,
            existingContent: json
        )

        let keysItem = items.first { $0.id == "json_keys" }
        let depthItem = items.first { $0.id == "json_depth" }

        XCTAssertNotNil(keysItem)
        XCTAssertEqual(keysItem?.value, "4 keys")
        XCTAssertNotNil(depthItem)
        XCTAssertEqual(depthItem?.value, "L4")
    }

    func testExtractGenericTelemetry_computesFileSizeAndPermissions() {
        let fileURL = tempDirectory.appendingPathComponent("test.bin")
        let data = Data(repeating: 0xAB, count: 1024)
        try! data.write(to: fileURL)

        let items = TelemetryExtractor.extractGenericTelemetry(url: fileURL)
        let sizeItem = items.first { $0.id == "file_size" }
        let permItem = items.first { $0.id == "permissions" }

        XCTAssertNotNil(sizeItem)
        XCTAssertNotNil(permItem)
    }

    func testTelemetryReport_summaryText_formatsCorrectly() {
        let items = [
            TelemetryItem(id: "lines", label: "Lines", value: "100"),
            TelemetryItem(id: "loc", label: "LoC", value: "80"),
            TelemetryItem(id: "format", label: "Format", value: "LF")
        ]
        let report = TelemetryReport(items: items)
        XCTAssertEqual(report.summaryText, "Lines: 100 · LoC: 80 · Format: LF")
        XCTAssertFalse(report.isEmpty)
    }

    func testTelemetryReport_empty_returnsTrue() {
        let report = TelemetryReport(items: [])
        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(report.summaryText, "")
    }
}
