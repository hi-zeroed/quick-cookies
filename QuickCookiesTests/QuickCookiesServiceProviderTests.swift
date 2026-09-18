import XCTest
import AppKit
@testable import QuickCookies

@MainActor
final class QuickCookiesServiceProviderTests: XCTestCase {

    private var temporaryFileURL: URL!
    private var testPasteboard: NSPasteboard!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ServiceProviderTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let sampleFile = tempDir.appendingPathComponent("Sample.swift")
        try "import Foundation".write(to: sampleFile, atomically: true, encoding: .utf8)
        self.temporaryFileURL = sampleFile

        let pbName = NSPasteboard.Name("QuickCookiesServicePB_\(UUID().uuidString)")
        self.testPasteboard = NSPasteboard(name: pbName)
        self.testPasteboard.clearContents()
    }

    override func tearDownWithError() throws {
        testPasteboard.clearContents()
        if let dir = temporaryFileURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }

    func testService_withSelectedTextPathAndLine_opensFileWithTargetLine() async {
        let requestController = PreviewRequestController()
        var openedPath: String?
        var openedSource: PreviewLaunchSource?
        var openedTargetLine: Int?

        requestController.onRequest = { request in
            if case .direct(let path) = request.pathIntent {
                openedPath = path
                openedSource = request.source
                openedTargetLine = request.targetLine
            }
        }

        let provider = QuickCookiesServiceProvider(requestController: requestController)

        // 模拟划选的文本包含行号
        testPasteboard.clearContents()
        testPasteboard.setString("\"\(temporaryFileURL.path):99\"", forType: .string)

        provider.handleServicePasteboard(testPasteboard)

        // 等待 Task @MainActor 调度
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(openedPath, temporaryFileURL.path)
        XCTAssertEqual(openedSource, .service)
        XCTAssertEqual(openedTargetLine, 99)
    }

    func testService_withInvalidText_showsToastAndDoesNotOpen() async {
        let requestController = PreviewRequestController()
        var didOpen = false
        var toastMessage: String?
        var toastIcon: String?

        requestController.onRequest = { _ in
            didOpen = true
        }

        let provider = QuickCookiesServiceProvider(
            requestController: requestController,
            showToastHandler: { msg, icon in
                toastMessage = msg
                toastIcon = icon
            }
        )

        testPasteboard.clearContents()
        testPasteboard.setString("This is just normal text with no path", forType: .string)

        provider.handleServicePasteboard(testPasteboard)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(didOpen)
        XCTAssertEqual(toastMessage, "No valid file path found".localized())
        XCTAssertEqual(toastIcon, "questionmark.folder")
    }

    func testService_withFileURL_opensFileDirectly() async {
        let requestController = PreviewRequestController()
        var openedPath: String?
        var openedSource: PreviewLaunchSource?

        requestController.onRequest = { request in
            if case .direct(let path) = request.pathIntent {
                openedPath = path
                openedSource = request.source
            }
        }

        let provider = QuickCookiesServiceProvider(requestController: requestController)

        testPasteboard.clearContents()
        testPasteboard.writeObjects([temporaryFileURL as NSURL])

        provider.handleServicePasteboard(testPasteboard)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(openedPath, temporaryFileURL.path)
        XCTAssertEqual(openedSource, .service)
    }

    func testService_withFilenamesPropertyList_opensFileDirectly() async {
        let requestController = PreviewRequestController()
        var openedPath: String?
        var openedSource: PreviewLaunchSource?

        requestController.onRequest = { request in
            if case .direct(let path) = request.pathIntent {
                openedPath = path
                openedSource = request.source
            }
        }

        let provider = QuickCookiesServiceProvider(requestController: requestController)

        testPasteboard.clearContents()
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        testPasteboard.setPropertyList([temporaryFileURL.path], forType: filenamesType)

        provider.handleServicePasteboard(testPasteboard)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(openedPath, temporaryFileURL.path)
        XCTAssertEqual(openedSource, .service)
    }
}
