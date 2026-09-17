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

    func testArchiveFileClassifiesAsArchive() throws {
        let fileURL = tempDirURL.appendingPathComponent("bundle.zip")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .archive)
    }

    func testTarGzipFileClassifiesAsArchive() throws {
        let fileURL = tempDirURL.appendingPathComponent("bundle.tar.gz")
        try Data([0x1F, 0x8B, 0x08, 0x00]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .archive)
    }

    func testSevenZipClassifiesAsArchive() throws {
        let fileURL = tempDirURL.appendingPathComponent("bundle.7z")
        try Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .archive)
    }

    func testStandaloneCompressedStreamClassifiesAsArchive() throws {
        let fileURL = tempDirURL.appendingPathComponent("log.gz")
        try Data([0x1F, 0x8B, 0x08, 0x00]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .archive)
    }

    func testSQLiteFileClassifiesAsUnsupported() throws {
        let fileURL = tempDirURL.appendingPathComponent("store.sqlite")
        try Data("SQLite format 3\u{00}".utf8).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .unsupported)
    }

    func testDatabaseAliasClassifiesAsUnsupported() throws {
        let fileURL = tempDirURL.appendingPathComponent("cache.db")
        try Data("SQLite format 3\u{00}".utf8).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .unsupported)
    }

    func testBinaryFileClassifiesAsHex() throws {
        let fileURL = tempDirURL.appendingPathComponent("exec.bin")
        try Data([0x41, 0x42, 0x00, 0x43]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .hex)
    }

    func testKnownHexExtensionsClassifyAsHex() throws {
        let wasmURL = tempDirURL.appendingPathComponent("module.wasm")
        try Data([0x00, 0x61, 0x73, 0x6D]).write(to: wasmURL)
        XCTAssertEqual(FileTypeClassifier.classify(path: wasmURL.path), .hex)

        let dylibURL = tempDirURL.appendingPathComponent("libcore.dylib")
        try Data([0xCF, 0xFA, 0xED, 0xFE]).write(to: dylibURL)
        XCTAssertEqual(FileTypeClassifier.classify(path: dylibURL.path), .hex)
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

    func testDeferredDataTextFormatsRemainPlainTextForThisStage() throws {
        let cases = [
            ("events.ndjson", "{\"ok\":true}\n"),
            ("records.jsonl", "{\"id\":1}\n"),
            ("schema.proto", "syntax = \"proto3\";")
        ]

        for (name, content) in cases {
            let fileURL = tempDirURL.appendingPathComponent(name)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .plainText, name)
        }
    }

    func testMissingPathIsUnsupported() {
        let path = tempDirURL.appendingPathComponent("missing.md").path

        XCTAssertEqual(FileTypeClassifier.classify(path: path), .unsupported)
    }

    func testDirectoryPathClassifiesAsFolder() {
        XCTAssertEqual(FileTypeClassifier.classify(path: tempDirURL.path), .folder)
    }

    func testAudioFileClassifiesAsAudio() throws {
        let fileURL = tempDirURL.appendingPathComponent("track.mp3")
        try Data([0xFF, 0xFB, 0x90, 0x64]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .audio)
        XCTAssertTrue(FileTypeClassifier.isSupported(path: fileURL.path))
    }

    func testVideoFileClassifiesAsVideo() throws {
        let fileURL = tempDirURL.appendingPathComponent("movie.mp4")
        try Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .video)
        XCTAssertTrue(FileTypeClassifier.isSupported(path: fileURL.path))
    }

    func testFontFileClassifiesAsFont() throws {
        let fileURL = tempDirURL.appendingPathComponent("custom.ttf")
        try Data([0x00, 0x01, 0x00, 0x00]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .font)
        XCTAssertTrue(FileTypeClassifier.isSupported(path: fileURL.path))
    }

    func testCsvAndTsvClassifyAsCode() throws {
        let csvURL = tempDirURL.appendingPathComponent("data.csv")
        try "name,age\nAlice,30".write(to: csvURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(FileTypeClassifier.classify(path: csvURL.path), .code)
        XCTAssertTrue(FileTypeClassifier.isSupported(path: csvURL.path))

        let tsvURL = tempDirURL.appendingPathComponent("data.tsv")
        try "name\tage\nBob\t25".write(to: tsvURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(FileTypeClassifier.classify(path: tsvURL.path), .code)
        XCTAssertTrue(FileTypeClassifier.isSupported(path: tsvURL.path))
    }
}
