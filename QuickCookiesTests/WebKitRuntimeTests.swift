import XCTest
import WebKit
@testable import QuickCookies

@MainActor
final class WebKitRuntimeTests: XCTestCase {
    func test_previewRuntimeRegistry_returnsSharedWebKitRuntimeForWebKind() {
        let runtimeA = PreviewRuntimeRegistry.shared.runtime(for: .web)
        let runtimeB = PreviewRuntimeRegistry.shared.runtime(for: .web)

        XCTAssertTrue(runtimeA === runtimeB)
    }

    func test_webKitRuntime_exposesWebRuntimeKindThroughContract() {
        let runtime = WebKitRuntime()

        XCTAssertEqual(runtime.kind, .web)
    }

    func test_previewRuntimeRegistry_defaultScheduledPrewarmStartsPromptly() async throws {
        let runtime = WebKitRuntime()
        let registry = PreviewRuntimeRegistry(webKitRuntime: runtime)

        registry.scheduleWebKitPrewarmIfNeeded()

        try await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            runtime.debugPrewarmCount == 1
        }

        XCTAssertEqual(runtime.debugPrewarmCount, 1)
    }

    func test_previewRuntimeRegistry_scheduledPrewarmRunsOnlyOnce() async throws {
        let runtime = WebKitRuntime()
        let registry = PreviewRuntimeRegistry(webKitRuntime: runtime)

        registry.scheduleWebKitPrewarmIfNeeded(after: 0)
        registry.scheduleWebKitPrewarmIfNeeded(after: 0)

        try await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            runtime.debugPrewarmCount == 1
        }

        XCTAssertEqual(runtime.debugPrewarmCount, 1)
    }

    func test_previewRuntimeRegistry_secondScheduleDoesNotPostponeExistingPrewarm() async throws {
        let runtime = WebKitRuntime()
        let registry = PreviewRuntimeRegistry(webKitRuntime: runtime)

        registry.scheduleWebKitPrewarmIfNeeded(after: 0)
        registry.scheduleWebKitPrewarmIfNeeded(after: 5)

        try await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            runtime.debugPrewarmCount == 1
        }

        XCTAssertEqual(runtime.debugPrewarmCount, 1)
    }

    func test_webKitRuntime_reusesSameWebViewAcrossCheckouts() async throws {
        let runtime = WebKitRuntime()

        let first = try await runtime.checkoutWebView()
        runtime.detachCurrentWebView()
        let second = try await runtime.checkoutWebView()

        XCTAssertTrue(first === second)
    }

    func test_webKitRuntime_resetClearsActiveSessionMetadata() async throws {
        let runtime = WebKitRuntime()

        _ = try await runtime.checkoutWebView()
        runtime.installSessionDebugState(loadID: UUID(), filePath: "/tmp/a.md")
        runtime.detachCurrentWebView()

        XCTAssertNil(runtime.debugCurrentFilePath)
        XCTAssertNil(runtime.debugCurrentLoadID)
    }

    func test_webKitRuntime_prewarmOnlyRunsOnce() async throws {
        let runtime = WebKitRuntime()

        try await runtime.prewarmIfNeeded()
        let firstCount = runtime.debugPrewarmCount
        try await runtime.prewarmIfNeeded()
        let secondCount = runtime.debugPrewarmCount

        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 1)
    }

    func test_webKitRuntime_defaultDetachDoesNotResetLoadedContent() async throws {
        let runtime = WebKitRuntime()

        _ = try await runtime.checkoutWebView()
        runtime.detachCurrentWebView()

        XCTAssertEqual(runtime.debugPrepareForFreshContentCount, 0)
    }

    func test_webKitRuntime_doesNotPrewarmAfterCheckout() async throws {
        let runtime = WebKitRuntime()

        _ = try await runtime.checkoutWebView()
        try await runtime.prewarmIfNeeded()

        XCTAssertEqual(runtime.debugPrewarmCount, 0)
    }

    func test_webKitRuntime_firstLoadAfterColdCheckoutReportsColdHints() async throws {
        let runtime = WebKitRuntime()

        _ = try await runtime.checkoutWebView()
        let hints = runtime.consumeLoadRuntimeHints()

        XCTAssertFalse(hints.reused)
        XCTAssertFalse(hints.prewarmed)
    }

    func test_webKitRuntime_secondLoadOnSameCheckoutReportsReusedHints() async throws {
        let runtime = WebKitRuntime()

        _ = try await runtime.checkoutWebView()
        _ = runtime.consumeLoadRuntimeHints()
        let hints = runtime.consumeLoadRuntimeHints()

        XCTAssertTrue(hints.reused)
        XCTAssertFalse(hints.prewarmed)
    }

    func test_webKitRuntime_firstLoadAfterPrewarmReportsPrewarmedHints() async throws {
        let runtime = WebKitRuntime()

        try await runtime.prewarmIfNeeded()
        _ = try await runtime.checkoutWebView()
        let hints = runtime.consumeLoadRuntimeHints()

        XCTAssertTrue(hints.reused)
        XCTAssertTrue(hints.prewarmed)
    }

    func test_markdownPreviewShellWarmer_marksReusableShellAsLoaded() async throws {
        let runtime = WebKitRuntime()

        try await MarkdownPreviewShellWarmer.warmIfNeeded(
            runtime: runtime,
            isDarkAppearance: true,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14
        )

        let webView = try await runtime.checkoutWebView()
        let hints = runtime.consumeLoadRuntimeHints()

        XCTAssertTrue(webView.hasLoadedPreviewShell)
        XCTAssertEqual(webView.loadedPreviewShellAppearanceIsDark, true)
        XCTAssertTrue(hints.reused)
        XCTAssertTrue(hints.prewarmed)
    }

    func test_markdownPreviewShellWarmer_alsoWarmsSnapshotRenderer() async throws {
        let runtime = WebKitRuntime()
        var didWarmSnapshotRenderer = false

        try await MarkdownPreviewShellWarmer.warmIfNeeded(
            runtime: runtime,
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            warmSnapshotRenderer: {
                didWarmSnapshotRenderer = true
            }
        )

        XCTAssertTrue(didWarmSnapshotRenderer)
    }

    func test_markdownPreviewShellWarmer_primesSnapshotRendererFirstRender() async throws {
        let runtime = WebKitRuntime()

        MarkdownPreviewSnapshotRendererWarmer.debugResetWarmStateForTesting()

        try await MarkdownPreviewShellWarmer.warmIfNeeded(
            runtime: runtime,
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14
        )

        XCTAssertTrue(MarkdownPreviewSnapshotRendererWarmer.debugHasPrimedFirstRender)
        XCTAssertEqual(MarkdownPreviewSnapshotRendererWarmer.debugWarmInvocationCount, 1)
    }

    func test_wkWebView_loadHTMLStringWithFileBaseURL_canRenderRelativeLocalImage() async throws {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let imageURL = tempDirectoryURL.appendingPathComponent("pixel.png")
        let pngData = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wn2nMsAAAAASUVORK5CYII=")
        )
        try pngData.write(to: imageURL)

        let delegate = TestNavigationDelegate()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        webView.navigationDelegate = delegate

        let html = """
        <!DOCTYPE html>
        <html>
        <body>
          <img id="target" src="pixel.png">
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: tempDirectoryURL)
        try await delegate.waitForFinish()
        try await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            let payload = try await self.evaluateJavaScript(
                """
                JSON.stringify({
                  complete: document.getElementById('target')?.complete ?? false,
                  naturalWidth: document.getElementById('target')?.naturalWidth ?? 0,
                  currentSrc: document.getElementById('target')?.currentSrc ?? ''
                })
                """,
                in: webView
            )
            let data = try XCTUnwrap(payload.data(using: .utf8))
            let result = try JSONDecoder().decode(LocalImageProbe.self, from: data)
            return result.complete && result.naturalWidth > 0 && result.currentSrc == imageURL.absoluteString
        }

        let payload = try await evaluateJavaScript(
            """
            JSON.stringify({
              complete: document.getElementById('target')?.complete ?? false,
              naturalWidth: document.getElementById('target')?.naturalWidth ?? 0,
              currentSrc: document.getElementById('target')?.currentSrc ?? ''
            })
            """,
            in: webView
        )

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let result = try JSONDecoder().decode(LocalImageProbe.self, from: data)

        XCTAssertEqual(result.currentSrc, imageURL.absoluteString)
        XCTAssertTrue(result.complete)
        XCTAssertGreaterThan(result.naturalWidth, 0)
    }

    func test_markdownShell_rendersREADMEWithRelativeLocalImage(
        filePath: String = #filePath
    ) async throws {
        let repositoryRootURL = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repositoryRootURL.appendingPathComponent("README-cn.md", isDirectory: false)
        let baseDirectoryURL = fileURL.deletingLastPathComponent()
        let markdown = try String(contentsOf: fileURL, encoding: .utf8)
        let prepared = MarkdownPreviewBridge.prepareContent(
            filePath: fileURL.path,
            fallbackMarkdown: markdown,
            preferFileBackedRendering: false,
            baseDirectoryURL: baseDirectoryURL,
            policy: MarkdownPreviewPolicy(),
            droppingLeadingBlocks: 0,
            knownFileSize: nil,
            allowsEmptyPlaceholder: false
        )
        let firstBatch = try XCTUnwrap(prepared.batches.first)
        let firstBatchMarkdownDump = firstBatch.blocks.map(\.markdown).joined(separator: "\n---\n")
        XCTAssertFalse(firstBatch.blocks.isEmpty)
        XCTAssertTrue(
            firstBatch.blocks.contains(where: { $0.markdown.contains("QuickCookies/Resources/AppIcon_transparent.png") }),
            "Expected bootstrap batch to retain the README image markdown, got: \(firstBatchMarkdownDump)"
        )

        let bootstrapScript = try XCTUnwrap(
            MarkdownPreviewBridge.javaScriptForBootstrap(preparedContent: prepared)
        )
        let html = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: baseDirectoryURL,
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            initialContentHTML: "",
            bootstrapJavaScript: bootstrapScript
        )

        let delegate = TestNavigationDelegate()
        let configuration = WKWebViewConfiguration()
        PreviewWebViewConfiguration.prepare(configuration)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 960, height: 1400), configuration: configuration)
        webView.navigationDelegate = delegate

        webView.loadHTMLString(html, baseURL: baseDirectoryURL)
        try await delegate.waitForFinish()
        try await waitUntil(timeoutNanoseconds: 3_000_000_000) {
            let payload = try await self.evaluateJavaScript(
                """
                JSON.stringify({
                  imageCount: document.querySelectorAll('img').length,
                  currentSrc: document.querySelector('img')?.currentSrc ?? '',
                  complete: document.querySelector('img')?.complete ?? false,
                  naturalWidth: document.querySelector('img')?.naturalWidth ?? 0,
                  contentTextLength: document.getElementById('content')?.innerText?.length ?? 0
                })
                """,
                in: webView
            )
            let data = try XCTUnwrap(payload.data(using: .utf8))
            let result = try JSONDecoder().decode(MarkdownImageReadinessProbe.self, from: data)
            return result.imageCount > 0
                && result.complete
                && result.naturalWidth > 0
                && result.contentTextLength > 0
                && !result.currentSrc.isEmpty
        }

        let payload = try await evaluateJavaScript(
            """
            JSON.stringify({
              imageCount: document.querySelectorAll('img').length,
              currentSrc: document.querySelector('img')?.currentSrc ?? '',
              widthAttribute: document.querySelector('img')?.getAttribute('width') ?? '',
              heightAttribute: document.querySelector('img')?.getAttribute('height') ?? '',
              complete: document.querySelector('img')?.complete ?? false,
              naturalWidth: document.querySelector('img')?.naturalWidth ?? 0,
              contentTextLength: document.getElementById('content')?.innerText?.length ?? 0,
              contentHTMLLength: document.getElementById('content')?.innerHTML?.length ?? 0,
              contentHTMLPrefix: (document.getElementById('content')?.innerHTML ?? '').slice(0, 400),
              hasMarked: typeof marked === 'function' || typeof marked === 'object',
              hasBridge: !!window.__quickCookiesMarkdown,
              hasBootstrapBatch: typeof window.__quickCookiesMarkdown?.bootstrapBatch === 'function'
            })
            """,
            in: webView
        )

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let result = try JSONDecoder().decode(FirstImageProbe.self, from: data)
        let expectedURL = try XCTUnwrap(
            PreviewLocalResourceSchemeMapper.webViewURLString(
                for: URL(
                    fileURLWithPath: "QuickCookies/Resources/AppIcon_transparent.png",
                    relativeTo: baseDirectoryURL
                ).standardizedFileURL
            )
        )

        XCTAssertGreaterThan(
            result.imageCount,
            0,
            """
            Expected rendered DOM to contain at least one image.
            hasMarked=\(result.hasMarked)
            hasBridge=\(result.hasBridge)
            hasBootstrapBatch=\(result.hasBootstrapBatch)
            contentTextLength=\(result.contentTextLength)
            contentHTMLLength=\(result.contentHTMLLength)
            contentHTMLPrefix=\(result.contentHTMLPrefix)
            """
        )
        XCTAssertEqual(result.currentSrc, expectedURL)
        XCTAssertEqual(result.widthAttribute, "128")
        XCTAssertEqual(result.heightAttribute, "128")
        XCTAssertTrue(result.complete)
        XCTAssertGreaterThan(result.naturalWidth, 0)
        XCTAssertGreaterThan(result.contentTextLength, 0)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Condition not met before timeout")
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64,
        condition: @escaping @MainActor () async throws -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if try await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Condition not met before timeout")
    }

    private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let string = result as? String else {
                    continuation.resume(throwing: TestError.invalidJavaScriptResult)
                    return
                }

                continuation.resume(returning: string)
            }
        }
    }
}

private struct LocalImageProbe: Decodable {
    let complete: Bool
    let naturalWidth: Int
    let currentSrc: String
}

private struct FirstImageProbe: Decodable {
    let imageCount: Int
    let currentSrc: String
    let widthAttribute: String
    let heightAttribute: String
    let complete: Bool
    let naturalWidth: Int
    let contentTextLength: Int
    let contentHTMLLength: Int
    let contentHTMLPrefix: String
    let hasMarked: Bool
    let hasBridge: Bool
    let hasBootstrapBatch: Bool
}

private struct MarkdownImageReadinessProbe: Decodable {
    let imageCount: Int
    let currentSrc: String
    let complete: Bool
    let naturalWidth: Int
    let contentTextLength: Int
}

private enum TestError: Error {
    case invalidJavaScriptResult
}

@MainActor
private final class TestNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForFinish() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
