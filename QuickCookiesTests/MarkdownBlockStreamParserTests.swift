import XCTest
@testable import QuickCookies

final class MarkdownBlockStreamParserTests: XCTestCase {
    private func repositoryRootURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func test_parse_keepsMultilineHTMLImageContainerInSingleBlock() {
        let markdown = """
        <p align="center">
          <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
        </p>
        """

        let parser = MarkdownBlockStreamParser(
            baseDirectoryURL: repositoryRootURL()
        )

        let blocks = parser.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .html)
        XCTAssertEqual(
            blocks.first?.markdown,
            markdown
        )
    }
}
