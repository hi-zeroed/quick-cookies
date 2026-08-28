import XCTest
@testable import QuickCookies
import AppKit

final class ExternalAppRelayTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ExternalAppRelayTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }

    func testKnownShortNamesMapping() {
        // 验证各主流编辑器的短名称与友好展示
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.microsoft.VSCode", defaultName: "Visual Studio Code"), "VS Code")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.todesktop.230313mzl4w4u92", defaultName: "Cursor"), "Cursor")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.apple.dt.Xcode", defaultName: "Xcode"), "Xcode")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "abnerworks.Typora", defaultName: "Typora"), "Typora")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.sublimetext.4", defaultName: "Sublime Text"), "Sublime Text")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "dev.zed.Zed", defaultName: "Zed"), "Zed")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.apple.TextEdit", defaultName: "TextEdit"), "TextEdit")
        
        // 未知应用应保留原始名称（并去除 .app 后缀）
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: "com.custom.app", defaultName: "Custom App"), "Custom App")
        XCTAssertEqual(ExternalAppRelay.shortName(forBundleIdentifier: nil, defaultName: "MyTool.app"), "MyTool")
    }

    func testPriorityScoreAssignment() {
        let vscodeScore = ExternalAppRelay.priorityScore(forBundleIdentifier: "com.microsoft.VSCode")
        let cursorScore = ExternalAppRelay.priorityScore(forBundleIdentifier: "com.todesktop.230313mzl4w4u92")
        let xcodeScore = ExternalAppRelay.priorityScore(forBundleIdentifier: "com.apple.dt.Xcode")
        let texteditScore = ExternalAppRelay.priorityScore(forBundleIdentifier: "com.apple.TextEdit")
        let unknownScore = ExternalAppRelay.priorityScore(forBundleIdentifier: "com.unknown.tool")
        
        XCTAssertGreaterThan(vscodeScore, texteditScore)
        XCTAssertGreaterThan(cursorScore, texteditScore)
        XCTAssertGreaterThan(xcodeScore, texteditScore)
        XCTAssertGreaterThan(texteditScore, unknownScore)
        XCTAssertEqual(unknownScore, 0)
    }

    func testCopyPathToClipboard() {
        let relay = ExternalAppRelay.shared
        let testFile = tempDirectoryURL.appendingPathComponent("hello.swift")
        try? "print(\"hello\")".write(to: testFile, atomically: true, encoding: .utf8)
        
        relay.copyPathToClipboard(fileURL: testFile)
        
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardString, testFile.path)
    }

    func testRelayAppCandidatesForFile() {
        let relay = ExternalAppRelay.shared
        let testFile = tempDirectoryURL.appendingPathComponent("test.txt")
        try? "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = relay.getApps(for: testFile)
        // macOS 系统中针对 .txt 至少能解析出默认应用或候选应用
        let allApps = (result.defaultApp != nil ? [result.defaultApp!] : []) + result.candidates
        XCTAssertFalse(allApps.isEmpty)
        
        // 应用应当有合法的名称和有效 URL
        for app in allApps {
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertFalse(app.shortName.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: app.url.path))
        }
    }
}
