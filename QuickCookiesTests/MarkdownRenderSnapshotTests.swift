import XCTest
@testable import QuickCookies

final class MarkdownRenderSnapshotTests: XCTestCase {
    private var tempDirectoryURL: URL!

    private func repositoryRootURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func test_bootstrapPayload_containsRenderedHTMLAndBlockMetadata() throws {
        let snapshot = MarkdownRenderSnapshot(
            renderedBlocks: [
                MarkdownRenderedBlockSnapshot(id: "p0", kind: .paragraph, html: "<p>Hello</p>", height: 44)
            ],
            blockOrder: ["p0"],
            blockHeights: ["p0": 44],
            shouldVirtualize: false,
            overscanScreens: 4
        )

        let payload = try XCTUnwrap(MarkdownPreviewBridge.javaScriptForBootstrapSnapshot(snapshot))

        XCTAssertTrue(payload.contains("window.__quickCookiesMarkdown.bootstrapSnapshot"))
        XCTAssertTrue(payload.contains("<p>Hello</p>"))
        XCTAssertTrue(payload.contains("\"p0\""))
    }

    func test_initialContentHTML_usesBlockHeightsWhenRenderedBlockHeightIsMissing() {
        let snapshot = MarkdownRenderSnapshot(
            renderedBlocks: [
                MarkdownRenderedBlockSnapshot(id: "p0", kind: .paragraph, html: "<p>Hello</p>", height: nil)
            ],
            blockOrder: ["p0"],
            blockHeights: ["p0": 88],
            shouldVirtualize: false,
            overscanScreens: 4
        )

        let html = MarkdownPreviewBridge.initialContentHTML(for: snapshot)

        XCTAssertTrue(html.contains("min-height: 88px"))
    }

    func test_renderHTML_embedsBootstrapMarkup() {
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            initialContentHTML: "<section data-block-id='p0'><div class='markdown-block-body'><p>Hello</p></div></section>",
            bootstrapJavaScript: "window.__quickCookiesMarkdown.bootstrapSnapshot({ blockOrder: ['p0'] });"
        )

        XCTAssertTrue(html.contains("data-block-id='p0'"))
        XCTAssertTrue(html.contains("window.__quickCookiesMarkdown.bootstrapSnapshot"))
    }

    func test_visibleRuntimeScript_exposesContinuationRequestHook() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()

        XCTAssertTrue(script.contains("markdownContinuationRequested"))
        XCTAssertTrue(script.contains("maybeRequestMore"))
    }

    func test_visibleRuntimeScript_exposesContinuationKickoffHook() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()

        XCTAssertTrue(script.contains("requestMoreIfNeeded"))
    }

    func test_visibleRuntimeScript_emitsBootstrapReadySignal() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()

        XCTAssertTrue(script.contains("markdownBootstrapReady"))
        XCTAssertTrue(script.contains("notifyBootstrapReady"))
    }

    func test_visibleRuntimeScript_doesNotDelayBootstrapReadyBehindNestedAnimationFrames() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        let notifyReadySection = script
            .components(separatedBy: "if (settings.notifyReady) {")
            .dropFirst()
            .first?
            .components(separatedBy: "if (settings.requestMore !== false) {")
            .first

        XCTAssertNotNil(notifyReadySection)
        XCTAssertTrue(notifyReadySection?.contains("notifyBootstrapReady();") == true)
        XCTAssertTrue(script.contains("scheduleVirtualization();"))
        XCTAssertFalse(notifyReadySection?.contains("requestAnimationFrame(function ()") == true)
        XCTAssertFalse(script.contains("requestAnimationFrame(notifyBootstrapReady);"))
    }

    func test_visibleRuntimeScript_bootstrapSnapshotDoesNotSynchronouslyMeasureInitialBlocks() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        let snapshotSection = script
            .components(separatedBy: "const registerBootstrapSnapshot = function (snapshot) {")
            .dropFirst()
            .first?
            .components(separatedBy: "const restoreBlock = function")
            .first

        XCTAssertNotNil(snapshotSection)
        XCTAssertFalse(snapshotSection?.contains("measureWrapper(wrapper);") == true)
        XCTAssertTrue(snapshotSection?.contains("notifyShellReusePhase('bootstrap-measure');") == true)
    }

    func test_visibleRuntimeScript_bootstrapSnapshotOnlyRescansWhenRebindingExistingDOM() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        let snapshotSection = script
            .components(separatedBy: "const registerBootstrapSnapshot = function (snapshot) {")
            .dropFirst()
            .first?
            .components(separatedBy: "const restoreBlock = function")
            .first

        XCTAssertNotNil(snapshotSection)
        XCTAssertTrue(snapshotSection?.contains("if (!renderedIntoEmptyContent) {") == true)
        XCTAssertTrue(snapshotSection?.contains("content.querySelectorAll('.markdown-block-shell').forEach") == true)
    }

    func test_visibleRuntimeScript_bootstrapSnapshotSignalsReadyWithoutAnimationFrameDelay() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        let snapshotSection = script
            .components(separatedBy: "const registerBootstrapSnapshot = function (snapshot) {")
            .dropFirst()
            .first?
            .components(separatedBy: "const restoreBlock = function")
            .first

        XCTAssertNotNil(snapshotSection)
        XCTAssertTrue(snapshotSection?.contains("scheduleVirtualization();") == true)
        XCTAssertTrue(snapshotSection?.contains("notifyBootstrapReady();") == true)
        XCTAssertFalse(snapshotSection?.contains("requestAnimationFrame(notifyBootstrapReady);") == true)
        XCTAssertFalse(snapshotSection?.contains("requestAnimationFrame(function ()") == true)
    }

    func test_visibleRuntimeScript_bootstrapBatchSignalsReadyWithoutAnimationFrameDelay() {
        let script = MarkdownRendererRuntime.visibleRuntimeScript()
        let batchSection = script
            .components(separatedBy: "bootstrapBatch: function (batch) {")
            .dropFirst()
            .first?
            .components(separatedBy: "configure: function")
            .first

        XCTAssertNotNil(batchSection)
        XCTAssertTrue(batchSection?.contains("scheduleVirtualization();") == true)
        XCTAssertTrue(batchSection?.contains("notifyBootstrapReady();") == true)
        XCTAssertFalse(batchSection?.contains("requestAnimationFrame(function ()") == true)
    }

    func test_updateBaseURLScript_updatesBaseHref() {
        let script = MarkdownPreviewBridge.javaScriptForUpdateBaseURL(
            URL(fileURLWithPath: "/tmp/docs").absoluteURL
        )

        XCTAssertTrue(script.contains("querySelector('base')"))
        XCTAssertTrue(script.contains("setAttribute('href'"))
        XCTAssertTrue(script.contains("file:///tmp/docs"))
    }

    func test_preprocess_convertsObsidianImageEmbedToMarkdownImage() {
        let result = MarkdownPreprocessor.preprocess("![[Pasted image 20250316114626.png]]")

        XCTAssertEqual(result, "![](<Pasted image 20250316114626.png>)")
    }

    func test_preprocess_preservesHTMLAttributesForSupportedTags() {
        let source = """
        <p align="center">
          <a href="#demo" title="Jump"><strong>Demo</strong></a>
          <kbd>⌘ Command</kbd>
        </p>
        """

        let result = MarkdownPreprocessor.preprocess(source)

        XCTAssertEqual(result, source)
    }

    func test_preprocess_doesNotRewriteHTMLInsideCodeFence() {
        let source = """
        ```html
        <p align="center">
          <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
        </p>
        ```
        """

        let result = MarkdownPreprocessor.preprocess(source)

        XCTAssertEqual(result, source)
    }

    func test_probeImages_supportsAngleBracketRelativePathWithSpaces() throws {
        let imageURL = tempDirectoryURL.appendingPathComponent("Pasted image 20250316114626.png")
        try Data().write(to: imageURL)

        let metas = MarkdownImageProbe.probeImages(
            in: "![](<Pasted image 20250316114626.png>)",
            baseDirectoryURL: tempDirectoryURL
        )

        XCTAssertEqual(metas.map(\.source), ["Pasted image 20250316114626.png"])
    }

    func test_parser_keepsMultilineHTMLImageContainerInSingleBlock() {
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
        XCTAssertTrue(blocks.first?.markdown.contains(#"<img src="QuickCookies/Resources/AppIcon_transparent.png""#) == true)
    }
}
