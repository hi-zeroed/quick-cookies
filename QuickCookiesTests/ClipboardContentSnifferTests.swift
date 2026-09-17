import XCTest
import AppKit
@testable import QuickCookies

final class ClipboardContentSnifferTests: XCTestCase {
    
    private var testPasteboard: NSPasteboard!
    private var tempFilesToClean: [String] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let pbName = NSPasteboard.Name("QuickCookiesTestPB_\(UUID().uuidString)")
        testPasteboard = NSPasteboard(name: pbName)
        testPasteboard.clearContents()
    }
    
    override func tearDownWithError() throws {
        testPasteboard.clearContents()
        for filePath in tempFilesToClean {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        try? FileManager.default.removeItem(at: ClipboardContentSniffer.cacheDirectory)
        try super.tearDownWithError()
    }
    
    func testSniff_whenPasteboardEmpty_returnsEmpty() {
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        XCTAssertEqual(result, .empty)
    }
    
    func testSniff_validJSONString_returnsFormattedJSON() {
        let rawJSON = "{\"name\":\"QuickCookies\",\"version\":1.6,\"enabled\":true}"
        testPasteboard.clearContents()
        testPasteboard.setString(rawJSON, forType: .string)
        
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        switch result {
        case .json(let formattedContent):
            XCTAssertTrue(formattedContent.contains("\"name\" : \"QuickCookies\"") || formattedContent.contains("\"name\": \"QuickCookies\""))
            XCTAssertTrue(formattedContent.contains("\n"))
        default:
            XCTFail("预期识别为 JSON，实际得到: \(result)")
        }
    }
    
    func testSniff_swiftCode_returnsSwiftCodeResult() {
        let swiftCode = """
        import SwiftUI
        struct MyTestView: View {
            @State private var count: Int = 0
            var body: some View {
                Text("\\(count)")
            }
        }
        """
        testPasteboard.clearContents()
        testPasteboard.setString(swiftCode, forType: .string)
        
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        switch result {
        case .code(let content, let language, let ext):
            XCTAssertEqual(content, swiftCode)
            XCTAssertEqual(language, "Swift")
            XCTAssertEqual(ext, "swift")
        default:
            XCTFail("预期识别为 Swift 代码，实际得到: \(result)")
        }
    }
    
    func testSniff_pythonCode_returnsPythonCodeResult() {
        let pythonCode = """
        import os
        import sys
        
        def calculate_total(items):
            print(items)
            return len(items)
        """
        testPasteboard.clearContents()
        testPasteboard.setString(pythonCode, forType: .string)
        
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        switch result {
        case .code(let content, let language, let ext):
            XCTAssertEqual(content, pythonCode)
            XCTAssertEqual(language, "Python")
            XCTAssertEqual(ext, "py")
        default:
            XCTFail("预期识别为 Python 代码，实际得到: \(result)")
        }
    }
    
    func testSniff_markdown_returnsMarkdownResult() {
        let md = """
        # QuickCookies 2.0
        
        - [x] 代码卡片分享导出
        - [x] 剪贴板内容透视
        
        查看 [官方主页](https://example.com)
        """
        testPasteboard.clearContents()
        testPasteboard.setString(md, forType: .string)
        
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        switch result {
        case .markdown(let content):
            XCTAssertEqual(content, md)
        default:
            XCTFail("预期识别为 Markdown，实际得到: \(result)")
        }
    }
    
    func testSniff_plainText_returnsPlainTextResult() {
        let plainText = "这是一段普通的无格式备忘录笔记，没有任何代码符号。"
        testPasteboard.clearContents()
        testPasteboard.setString(plainText, forType: .string)
        
        let result = ClipboardContentSniffer.sniff(pasteboard: testPasteboard)
        XCTAssertEqual(result, .plainText(content: plainText))
    }
    
    func testMaterialize_empty_returnsNil() throws {
        let pair = try ClipboardContentSniffer.materialize(result: .empty)
        XCTAssertNil(pair)
    }
    
    func testMaterialize_code_createsFileWithMatchingExtension() throws {
        let snippet = "console.log('Hello');"
        let result = ClipboardSniffResult.code(content: snippet, language: "JavaScript", fileExtension: "js")
        
        guard let (filePath, displayName) = try ClipboardContentSniffer.materialize(result: result) else {
            XCTFail("materialize 返回空")
            return
        }
        tempFilesToClean.append(filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        XCTAssertTrue(filePath.hasSuffix("clipboard.js"))
        XCTAssertEqual(displayName, "Clipboard (JavaScript)")
        
        let savedContent = try String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(savedContent, snippet)
    }
    
    func testMaterialize_json_createsJsonFile() throws {
        let jsonStr = "{\n  \"status\": \"ok\"\n}"
        let result = ClipboardSniffResult.json(formattedContent: jsonStr)
        
        guard let (filePath, _) = try ClipboardContentSniffer.materialize(result: result) else {
            XCTFail("materialize 返回空")
            return
        }
        tempFilesToClean.append(filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        XCTAssertTrue(filePath.hasSuffix("clipboard.json"))
        let savedContent = try String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(savedContent, jsonStr)
    }
    
    func testMaterialize_image_createsPngFile() throws {
        // 创建一个简单的 10x10 位图图像
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 10,
            pixelsHigh: 10,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 40,
            bitsPerPixel: 32
        )!
        let pngData = rep.representation(using: .png, properties: [:])!
        let result = ClipboardSniffResult.image(data: pngData)
        
        guard let (filePath, _) = try ClipboardContentSniffer.materialize(result: result) else {
            XCTFail("materialize 返回空")
            return
        }
        tempFilesToClean.append(filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        XCTAssertTrue(filePath.hasSuffix("clipboard.png"))
        let readData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        XCTAssertEqual(readData, pngData)
    }
}
