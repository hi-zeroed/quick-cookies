import XCTest
@testable import QuickCookies

final class MarkdownBlockStreamParserTests: XCTestCase {
    func test_parse_keepsMultilineHTMLImageContainerInSingleBlock() {
        let markdown = """
        <p align="center">
          <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
        </p>
        """

        let parser = MarkdownBlockStreamParser(
            baseDirectoryURL: URL(fileURLWithPath: "/Users/jiangwei/Git/QuickCookies", isDirectory: true)
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
