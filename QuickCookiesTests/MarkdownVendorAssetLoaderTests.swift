import XCTest
@testable import QuickCookies

final class MarkdownVendorAssetLoaderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MarkdownVendorAssetLoader.clearCache()
    }

    override func tearDown() {
        MarkdownVendorAssetLoader.clearCache()
        super.tearDown()
    }

    func testLoadMermaidScript_returnsNonEmptyScript() {
        guard let script = MarkdownVendorAssetLoader.loadMermaidScript() else {
            XCTFail("Failed to load mermaid.min.js")
            return
        }

        XCTAssertFalse(script.isEmpty, "Mermaid script should not be empty")
        XCTAssertTrue(script.contains("mermaid"), "Mermaid script should contain 'mermaid' keyword")
    }

    func testLoadKaTeXScript_returnsNonEmptyScript() {
        guard let script = MarkdownVendorAssetLoader.loadKaTeXScript() else {
            XCTFail("Failed to load katex.min.js")
            return
        }

        XCTAssertFalse(script.isEmpty, "KaTeX script should not be empty")
        XCTAssertTrue(script.contains("katex"), "KaTeX script should contain 'katex' keyword")
    }

    func testLoadKaTeXAutoRenderScript_returnsNonEmptyScript() {
        guard let script = MarkdownVendorAssetLoader.loadKaTeXAutoRenderScript() else {
            XCTFail("Failed to load auto-render.min.js")
            return
        }

        XCTAssertFalse(script.isEmpty, "Auto-render script should not be empty")
        XCTAssertTrue(script.contains("renderMathInElement"), "Auto-render script should define renderMathInElement")
    }

    func testLoadKaTeXCSS_returnsNonEmptyStylesheet() {
        guard let css = MarkdownVendorAssetLoader.loadKaTeXCSS() else {
            XCTFail("Failed to load katex.min.css")
            return
        }

        XCTAssertFalse(css.isEmpty, "KaTeX stylesheet should not be empty")
        XCTAssertTrue(css.contains(".katex"), "KaTeX CSS should contain .katex selector")
    }

    func testCacheMechanism_reusesLoadedContent() {
        let first = MarkdownVendorAssetLoader.loadKaTeXScript()
        let second = MarkdownVendorAssetLoader.loadKaTeXScript()

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }
}
