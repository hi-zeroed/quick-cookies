import XCTest
import JavaScriptCore
@testable import QuickCookies

final class MarkdownDeepExtensionTests: XCTestCase {

    func testMarkdownHTMLShell_withMermaidContent_injectsMermaidScript() {
        let markdownHTML = "<pre><code class=\"language-mermaid\">graph TD\nA-->B</code></pre>"
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: true,
            bodyFontName: "System",
            bodyFontSize: 14,
            initialContentHTML: markdownHTML,
            bootstrapJavaScript: nil
        )

        XCTAssertTrue(html.contains("mermaid"), "HTML should contain mermaid script or reference")
        XCTAssertTrue(html.contains(".mermaid-wrapper"), "HTML should contain .mermaid-wrapper style")
        XCTAssertTrue(html.contains(".copy-code-btn"), "HTML should contain .copy-code-btn style")
    }

    func testMarkdownHTMLShell_withoutMermaidOrMath_doesNotInjectLargeVendorScripts() {
        let plainHTML = "<p>Hello world this is a simple readme.</p>"
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: false,
            bodyFontName: "System",
            bodyFontSize: 14,
            initialContentHTML: plainHTML,
            bootstrapJavaScript: nil
        )

        // 普通文档不应注入 mermaid 庞大脚本
        XCTAssertFalse(html.contains("JM.mermaid"), "HTML should not inject full mermaid library for plain text")
        // 但仍然支持代码块悬浮复制样式
        XCTAssertTrue(html.contains(".copy-code-btn"), "HTML should still contain copy code button styles")
    }

    func testMarkdownHTMLShell_withMathContent_injectsKaTeX() {
        let mathHTML = "<p>Euler formula is $$e^{i\\pi} + 1 = 0$$</p>"
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: true,
            bodyFontName: "System",
            bodyFontSize: 14,
            initialContentHTML: mathHTML,
            bootstrapJavaScript: nil
        )

        XCTAssertTrue(html.contains("katex"), "HTML should contain katex CSS or JS")
        XCTAssertTrue(html.contains("renderMathInElement"), "HTML should contain renderMathInElement")
    }

    func testMarkdownPreviewSession_mermaidCodeBlock_preservesRawSource() async throws {
        let markdown = """
        ```mermaid
        flowchart TD
            Start --> Stop
        ```
        """

        let session = try await MarkdownPreviewSessionBuilder.prepare(
            filePath: "/tmp/test.md",
            fallbackMarkdown: markdown,
            preferFileBackedRendering: false,
            baseDirectoryURL: nil,
            isDarkAppearance: true,
            bodyFontName: "System",
            bodyFontSize: 14,
            policy: MarkdownPreviewPolicy()
        )

        guard let snapshot = session.bootstrapSnapshot,
              let firstBlock = snapshot.renderedBlocks.first else {
            XCTFail("Failed to obtain bootstrap snapshot or rendered blocks")
            return
        }

        XCTAssertTrue(firstBlock.html.contains("mermaid-src"), "HTML should mark mermaid block with mermaid-src")
        XCTAssertTrue(firstBlock.html.contains("language-mermaid"), "HTML should have language-mermaid class")
        XCTAssertTrue(firstBlock.html.contains("Start --&gt; Stop") || firstBlock.html.contains("Start --> Stop"), "HTML should retain raw graph source")
    }

    func testMarkdownHTMLShell_withExplicitMermaidFlag_injectsMermaidRegardlessOfContent() {
        let plainHTML = "<p>Initial chunk without any keywords</p>"
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: true,
            bodyFontName: "System",
            bodyFontSize: 14,
            initialContentHTML: plainHTML,
            bootstrapJavaScript: nil,
            hasMermaid: true
        )

        XCTAssertTrue(html.contains("mermaid"), "HTML should inject mermaid when explicit flag is true even if content is empty")
    }

    func testMarkdownRendererRuntime_hasValidJavaScriptSyntax() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        guard let context = JSContext() else {
            XCTFail("Failed to create JSContext")
            return
        }
        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }
        context.evaluateScript("(function() {\n\(script)\n})")
        XCTAssertNil(exceptionMessage, "Runtime JS script should have no syntax errors, but got: \(exceptionMessage ?? "")")
    }
}
