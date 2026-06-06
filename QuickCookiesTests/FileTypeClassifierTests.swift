import XCTest
@testable import QuickCookies

final class FileTypeClassifierTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testMarkdownFileClassifiesAsMarkdown() throws {
        let fileURL = tempDirURL.appendingPathComponent("note.md")
        try "# Title".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .markdown)
    }

    func testSwiftFileClassifiesAsCode() throws {
        let fileURL = tempDirURL.appendingPathComponent("App.swift")
        try "import SwiftUI".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .code)
    }

    func testPdfClassifiesAsPdf() throws {
        let fileURL = tempDirURL.appendingPathComponent("doc.pdf")
        try Data([0x25, 0x50, 0x44, 0x46]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .pdf)
    }

    func testPngClassifiesAsImage() throws {
        let fileURL = tempDirURL.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .image)
    }

    func testOfficeDocumentClassifiesAsOffice() throws {
        let fileURL = tempDirURL.appendingPathComponent("sheet.xlsx")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .office)
    }

    func testBinaryFileClassifiesAsUnsupported() throws {
        let fileURL = tempDirURL.appendingPathComponent("exec.bin")
        try Data([0x41, 0x42, 0x00, 0x43]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .unsupported)
    }

    func testMakefileClassifiesAsCode() throws {
        let fileURL = tempDirURL.appendingPathComponent("Makefile")
        try "all:\n\t@echo ok".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .code)
    }

    func testUnknownTextExtensionDefaultsToPlainText() throws {
        let fileURL = tempDirURL.appendingPathComponent("notes.custom")
        try "plain text".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .plainText)
    }

    func testMissingPathIsUnsupported() {
        let path = tempDirURL.appendingPathComponent("missing.md").path

        XCTAssertEqual(FileTypeClassifier.classify(path: path), .unsupported)
    }

    func testDirectoryPathIsUnsupported() {
        XCTAssertEqual(FileTypeClassifier.classify(path: tempDirURL.path), .unsupported)
    }
}
