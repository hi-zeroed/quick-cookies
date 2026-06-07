import XCTest
import WebKit
@testable import QuickCookies

@MainActor
final class MarkdownPreviewControllerTests: XCTestCase {
    private func repositoryRootURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func test_displayPolicy_defersMarkdownPreviewUntilInitialChunkArrives() {
        XCTAssertFalse(
            MarkdownPreviewDisplayPolicy.shouldMountPreview(
                renderType: .markdown,
                isLoading: true,
                hasLoadedInitialContent: false
            )
        )
    }

    func test_displayPolicy_allowsMarkdownPreviewAfterInitialChunkArrives() {
        XCTAssertTrue(
            MarkdownPreviewDisplayPolicy.shouldMountPreview(
                renderType: .markdown,
                isLoading: true,
                hasLoadedInitialContent: true
            )
        )
    }

    func test_displayPolicy_doesNotBlockNonMarkdownPreview() {
        XCTAssertTrue(
            MarkdownPreviewDisplayPolicy.shouldMountPreview(
                renderType: .code,
                isLoading: true,
                hasLoadedInitialContent: false
            )
        )
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
        XCTAssertEqual(blocks.first?.markdown, markdown)
    }

    func test_controller_marksSessionPreparedOnlyAfterAsyncPreparationCompletes() async throws {
        let loader = PendingSessionLoader()
        let timeline = RecordingTimeline()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                try await loader.load()
            }
        )
        let webView = PreviewWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        controller.bind(webView: webView)
        controller.previewTimeline = timeline

        controller.loadContent(
            filePath: "/tmp/demo.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        await fulfillment(of: [loader.started], timeout: 1.0)
        XCTAssertFalse(timeline.markedStages.contains(.sessionPrepared))

        loader.resume(returning: Self.makeSession())
        await fulfillment(of: [timeline.sessionPreparedMarked], timeout: 1.0)
        XCTAssertNotNil(timeline.prepareMetrics)
    }

    func test_controller_ignoresCallbacksFromSupersededLoad() {
        let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())
        let oldLoad = UUID()
        let newLoad = UUID()

        controller.debugSetCurrentLoadID(oldLoad)
        controller.debugSetCurrentLoadID(newLoad)

        XCTAssertFalse(controller.shouldAcceptCallback(for: oldLoad))
        XCTAssertTrue(controller.shouldAcceptCallback(for: newLoad))
    }

    func test_controller_reportsBootstrapReadyOnlyOncePerLoad() {
        let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())
        controller.debugPrepareForNewLoad()

        XCTAssertTrue(controller.markBootstrapReadyIfNeeded())
        XCTAssertFalse(controller.markBootstrapReadyIfNeeded())
    }

    func test_controller_newLoadResetsBootstrapGate() {
        let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())

        controller.debugPrepareForNewLoad()
        XCTAssertTrue(controller.markBootstrapReadyIfNeeded())

        controller.debugPrepareForNewLoad()
        XCTAssertTrue(controller.markBootstrapReadyIfNeeded())
    }

    func test_controller_attemptsSummaryLoggingWhenWebViewFinishes() {
        let timeline = RecordingTimeline()
        let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())
        let webView = PreviewWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        controller.bind(webView: webView)
        controller.previewTimeline = timeline

        controller.webView(webView, didFinish: nil)

        XCTAssertTrue(timeline.markedStages.contains(.webViewDidFinish))
        XCTAssertEqual(timeline.logSummaryCallCount, 1)
    }

    func test_controller_reusesLoadedShellWithoutReloadingHTML() async throws {
        let webView = SpyPreviewWebView()
        let timeline = RecordingTimeline()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession()
            }
        )
        controller.bindForTesting(webViewProxy: webView)
        controller.debugMarkShellLoaded()
        controller.previewTimeline = timeline

        controller.loadContent(
            filePath: "/tmp/docs/first.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(webView.loadHTMLCallCount, 0)
        XCTAssertEqual(webView.evaluateJavaScriptCalls.count, 2)
        XCTAssertTrue(timeline.markedStages.contains(.webViewDidFinish))
        XCTAssertEqual(timeline.logSummaryCallCount, 1)
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('reset-start')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('reset-clear')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('reset')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('base')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('bootstrap-render')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('bootstrap-attach')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('bootstrap-measure')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('bootstrap-post')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('bootstrap')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("markShellReusePhase('style')"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("window.__quickCookiesMarkdown.reset();"))
        XCTAssertTrue(webView.evaluateJavaScriptCalls[0].contains("bootstrapBatch"))
    }

    func test_controller_reusedShellPrefersBootstrapSnapshotOverBootstrapBatch() async throws {
        let webView = SpyPreviewWebView()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession(includeSnapshot: true)
            }
        )
        controller.bindForTesting(webViewProxy: webView)
        controller.debugMarkShellLoaded()

        controller.loadContent(
            filePath: "/tmp/docs/snapshot.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let script = try XCTUnwrap(webView.evaluateJavaScriptCalls.first)
        XCTAssertTrue(script.contains("window.__quickCookiesMarkdown.bootstrapSnapshot"))
        XCTAssertFalse(script.contains("bootstrapBatch"))
    }

    func test_controller_reusedShellUpdatesBaseHrefBeforeBootstrap() async throws {
        let webView = SpyPreviewWebView()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession()
            }
        )
        controller.bindForTesting(webViewProxy: webView)
        controller.debugMarkShellLoaded()

        controller.loadContent(
            filePath: "/tmp/other/path/demo.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let script = try XCTUnwrap(webView.evaluateJavaScriptCalls.first)
        XCTAssertTrue(script.contains("querySelector('base')"))
        XCTAssertTrue(script.contains("file:///tmp/other/path/"))
    }

    func test_controller_reusesExistingShellAcrossRebindWithoutReloadingHTML() async throws {
        let webView = SpyPreviewWebView()
        let firstController = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession()
            }
        )
        firstController.bindForTesting(webViewProxy: webView)
        firstController.debugMarkShellLoaded()
        firstController.unbind()

        let secondController = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession()
            }
        )
        secondController.bindForTesting(webViewProxy: webView)
        webView.loadHTMLCallCount = 0
        webView.evaluateJavaScriptCalls = []

        secondController.loadContent(
            filePath: "/tmp/docs/rebind.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(webView.loadHTMLCallCount, 0)
        XCTAssertTrue(webView.evaluateJavaScriptCalls.first?.contains("window.__quickCookiesMarkdown.reset();") == true)
    }

    func test_controller_doesNotReuseShellWhenAppearanceDoesNotMatch() async throws {
        let webView = SpyPreviewWebView()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession()
            }
        )
        controller.bindForTesting(webViewProxy: webView)
        controller.debugMarkShellLoaded(isDarkAppearance: false)

        controller.loadContent(
            filePath: "/tmp/docs/dark.md",
            markdownText: "# Demo",
            isDarkAppearance: true,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(webView.loadHTMLCallCount, 1)
        XCTAssertTrue(webView.evaluateJavaScriptCalls.isEmpty)
        let html = try XCTUnwrap(webView.loadedHTMLStrings.first)
        XCTAssertTrue(html.contains("bootstrapBatch"))
    }

    func test_controller_coldLoadEmbedsInitialSnapshotMarkupWhenSessionProvidesSnapshot() async throws {
        let webView = SpyPreviewWebView()
        let controller = MarkdownPreviewController(
            policy: MarkdownPreviewPolicy(),
            sessionLoader: { _, _, _, _, _, _, _, _ in
                Self.makeSession(includeSnapshot: true)
            }
        )
        controller.bindForTesting(webViewProxy: webView)

        controller.loadContent(
            filePath: "/tmp/docs/cold-snapshot.md",
            markdownText: "# Demo",
            isDarkAppearance: false,
            bodyFontName: "JetBrains Mono",
            bodyFontSize: 14,
            preferFileBackedRendering: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(webView.loadHTMLCallCount, 1)
        let html = try XCTUnwrap(webView.loadedHTMLStrings.first)
        XCTAssertTrue(html.contains(#"<section class="markdown-block-shell""#))
        XCTAssertTrue(html.contains("<p>Hello</p>"))
        XCTAssertTrue(html.contains("window.__quickCookiesMarkdown.bootstrapSnapshot"))
        XCTAssertFalse(html.contains("window.__quickCookiesMarkdown.bootstrapBatch(JSON.parse"))
    }

    func test_recordingTimeline_logsSummaryAtMostOnceAfterCompletion() {
        let timeline = RecordingTimeline()

        timeline.mark(.firstChunkReady)
        timeline.mark(.sessionPrepared)
        timeline.mark(.webViewDidFinish)
        timeline.mark(.bootstrapReady)

        timeline.logSummaryIfComplete()
        timeline.logSummaryIfComplete()

        XCTAssertEqual(timeline.logSummaryCallCount, 2)
        XCTAssertEqual(timeline.completedSummaryCount, 1)
    }

    private static func makeSession(includeSnapshot: Bool = false) -> MarkdownPreviewSession {
        let snapshot = includeSnapshot
            ? MarkdownRenderSnapshot(
                renderedBlocks: [
                    MarkdownRenderedBlockSnapshot(
                        id: "markdown-block-empty",
                        kind: .paragraph,
                        html: "<p>Hello</p>",
                        height: 24
                    )
                ],
                blockOrder: ["markdown-block-empty"],
                blockHeights: ["markdown-block-empty": 24],
                shouldVirtualize: false,
                overscanScreens: 4
            )
            : nil

        return MarkdownPreviewSession(
            bootstrapContent: MarkdownPreviewPreparedContent(
                batches: [
                    MarkdownPreviewBatch(
                        appendMode: .initial,
                        blocks: [MarkdownPreviewBridge.emptyPlaceholderBlock()]
                    )
                ],
                shouldVirtualize: false,
                overscanScreens: 4
            ),
            continuationContent: nil,
            bootstrapSnapshot: snapshot,
            prepareMetrics: MarkdownPreviewPrepareMetrics(
                sourceMs: 1,
                bootstrapPlanMs: 2,
                bootstrapContentMs: 3,
                bootstrapSnapshotMs: 4,
                continuationMs: 5,
                snapshotRenderMetrics: nil
            )
        )
    }
}

@MainActor
private final class PendingSessionLoader {
    let started = XCTestExpectation(description: "session loader started")

    private var continuation: CheckedContinuation<MarkdownPreviewSession, Error>?

    func load() async throws -> MarkdownPreviewSession {
        started.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(returning session: MarkdownPreviewSession) {
        continuation?.resume(returning: session)
        continuation = nil
    }
}

private final class RecordingTimeline: MarkdownPreviewTimelineRecording {
    let sessionPreparedMarked = XCTestExpectation(description: "session prepared marked")

    private(set) var markedStages: [MarkdownPreviewTimeline.Stage] = []
    private(set) var prepareMetrics: MarkdownPreviewPrepareMetrics?
    private(set) var logSummaryCallCount = 0
    private(set) var completedSummaryCount = 0

    func mark(_ stage: MarkdownPreviewTimeline.Stage, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        markedStages.append(stage)
        if stage == .sessionPrepared {
            sessionPreparedMarked.fulfill()
        }
    }

    func annotatePrepareMetrics(_ metrics: MarkdownPreviewPrepareMetrics?) {
        prepareMetrics = metrics
    }

    func logSummaryIfComplete() {
        logSummaryCallCount += 1
        guard markedStages.contains(.firstChunkReady),
              markedStages.contains(.sessionPrepared),
              markedStages.contains(.webViewDidFinish),
              markedStages.contains(.bootstrapReady) else {
            return
        }

        if completedSummaryCount == 0 {
            completedSummaryCount = 1
        }
    }
}

@MainActor
private final class SpyPreviewWebView: PreviewWebViewing {
    let configuration = WKWebViewConfiguration()
    var navigationDelegate: WKNavigationDelegate?
    var shouldShowContextMenu: () -> Bool = { false }
    var hasLoadedPreviewShell = false
    var loadedPreviewShellAppearanceIsDark: Bool?

    var loadHTMLCallCount = 0
    var evaluateJavaScriptCalls: [String] = []
    var loadedHTMLStrings: [String] = []

    @discardableResult
    func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        loadHTMLCallCount += 1
        loadedHTMLStrings.append(string)
        return nil
    }

    func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: ((Any?, Error?) -> Void)?
    ) {
        evaluateJavaScriptCalls.append(javaScriptString)
        completionHandler?(nil, nil)
    }
}
