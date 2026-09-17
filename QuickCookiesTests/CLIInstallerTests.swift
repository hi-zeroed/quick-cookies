import XCTest
@testable import QuickCookies

final class CLIInstallerTests: XCTestCase {
    
    private var tempDirURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CLITest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let dir = tempDirURL {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }
    
    func test_defaultScriptContent_containsVersionAndScheme() {
        let content = CLIInstallerPolicy.defaultScriptContent()
        XCTAssertTrue(content.contains("VERSION=\"\(CLIInstallerPolicy.currentVersion)\""))
        XCTAssertTrue(content.contains("quickcookies://preview?path="))
        XCTAssertTrue(content.contains("quickcookies://preview?source=clipboard"))
        XCTAssertTrue(content.contains("-c|--clipboard"))
        XCTAssertTrue(content.contains("-g"))
    }
    
    func test_extractVersion_fromValidScript() throws {
        let scriptPath = tempDirURL.appendingPathComponent("qc_mock").path
        let script = """
        #!/bin/bash
        VERSION="1.5.0"
        echo hello
        """
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        let version = CLIInstallerPolicy.extractVersion(from: scriptPath)
        XCTAssertEqual(version, "1.5.0")
    }
    
    func test_extractVersion_fromNonExistentFile_returnsNil() {
        let version = CLIInstallerPolicy.extractVersion(from: "/path/to/nothing/qc")
        XCTAssertNil(version)
    }
    
    func test_checkStatus_whenFileDoesNotExist_returnsNotInstalled() {
        let status = CLIInstallerPolicy.checkStatus(
            fileManager: .default,
            locations: []
        )
        XCTAssertFalse(status.isInstalled)
        XCTAssertNil(status.installedPath)
        XCTAssertNil(status.version)
    }
}
