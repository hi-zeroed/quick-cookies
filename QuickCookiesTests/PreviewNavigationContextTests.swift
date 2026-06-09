import XCTest
@testable import QuickCookies

final class PreviewNavigationContextTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("QuickCookiesNavigationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testBuildProvidesPreviousAndNextFilesInCurrentDirectory() throws {
        let alpha = try createFile(named: "alpha.md")
        let beta = try createFile(named: "beta.md")
        let gamma = try createFile(named: "gamma.md")

        let context = PreviewNavigationContextBuilder.build(currentPath: beta.path)

        XCTAssertEqual(context?.currentPath, beta.path)
        XCTAssertEqual(context?.orderedPaths, [alpha.path, beta.path, gamma.path])
        XCTAssertEqual(context?.currentIndex, 1)
        XCTAssertEqual(context?.previousPath, alpha.path)
        XCTAssertEqual(context?.nextPath, gamma.path)
    }

    func testBuildReturnsNilPreviousForFirstFile() throws {
        let alpha = try createFile(named: "alpha.md")
        let beta = try createFile(named: "beta.md")

        let context = PreviewNavigationContextBuilder.build(currentPath: alpha.path)

        XCTAssertEqual(context?.orderedPaths, [alpha.path, beta.path])
        XCTAssertNil(context?.previousPath)
        XCTAssertEqual(context?.nextPath, beta.path)
    }

    func testBuildReturnsNilNextForLastFile() throws {
        let alpha = try createFile(named: "alpha.md")
        let beta = try createFile(named: "beta.md")

        let context = PreviewNavigationContextBuilder.build(currentPath: beta.path)

        XCTAssertEqual(context?.orderedPaths, [alpha.path, beta.path])
        XCTAssertEqual(context?.previousPath, alpha.path)
        XCTAssertNil(context?.nextPath)
    }

    func testBuildExcludesDirectoriesFromNavigationOrder() throws {
        let alpha = try createFile(named: "alpha.md")
        let beta = try createFile(named: "beta.md")
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL.appendingPathComponent("folder.md", isDirectory: true),
            withIntermediateDirectories: true
        )

        let context = PreviewNavigationContextBuilder.build(currentPath: alpha.path)

        XCTAssertEqual(context?.orderedPaths, [alpha.path, beta.path])
        XCTAssertEqual(context?.nextPath, beta.path)
    }

    func testBuildUsesLocalizedStandardFilenameSort() throws {
        let file2 = try createFile(named: "file2.md")
        let file10 = try createFile(named: "file10.md")
        let file1 = try createFile(named: "file1.md")

        let context = PreviewNavigationContextBuilder.build(currentPath: file2.path)

        XCTAssertEqual(context?.orderedPaths, [file1.path, file2.path, file10.path])
        XCTAssertEqual(context?.previousPath, file1.path)
        XCTAssertEqual(context?.nextPath, file10.path)
    }

    func testBuildReturnsNilWhenCurrentPathDoesNotExist() {
        let missingPath = temporaryDirectoryURL
            .appendingPathComponent("missing.md")
            .path

        let context = PreviewNavigationContextBuilder.build(currentPath: missingPath)

        XCTAssertNil(context)
    }

    private func createFile(named name: String) throws -> URL {
        let url = temporaryDirectoryURL.appendingPathComponent(name)
        try Data("demo".utf8).write(to: url)
        return url
    }
}
