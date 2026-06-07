import XCTest
@testable import QuickCookies

private final class DiagnosticCaptureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(String, String)] = []

    func append(_ value: (String, String)) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [(String, String)] {
        lock.lock()
        let copy = values
        lock.unlock()
        return copy
    }
}

private final class DiagnosticMessageBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let copy = values
        lock.unlock()
        return copy
    }
}

final class MarkdownPreviewSessionTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MarkdownPreviewTimelineTracker.summarySink = { _ in }
        AppDiagnostics.sink = { _, _ in }
        AppDiagnostics.resetForTesting()
    }

    func test_previewTimeline_formatsCumulativeAndSplitDurations() {
        var timeline = MarkdownPreviewTimeline(
            filePath: "/tmp/Notes/episode.md",
            startedAt: 10.0
        )

        timeline.shellMode = .fullNavigation
        timeline.mark(.firstChunkReady, at: 10.018)
        timeline.mark(.sessionPrepared, at: 10.041)
        timeline.mark(.bootstrapScriptPrepared, at: 10.044)
        timeline.mark(.shellLoadIssued, at: 10.052)
        timeline.mark(.navigationStarted, at: 10.062)
        timeline.mark(.navigationCommitted, at: 10.102)
        timeline.mark(.webViewDidFinish, at: 10.123)
        timeline.mark(.bootstrapReady, at: 10.166)

        XCTAssertEqual(
            timeline.summary,
            "[MarkdownPreview][episode.md] total=166ms chunk=18ms prepare=23ms webview=82ms bootstrap=43ms reused=false prewarmed=false prepareMount=0ms prepareMountView=0ms prepareMountCheckoutQueue=0ms prepareMountCheckout=0ms prepareMountBind=0ms prepareDispatch=0ms prepareWork=23ms shell=nav scriptPrep=3ms shellPrep=8ms provisional=10ms commit=40ms finish=21ms"
        )
    }

    func test_previewTimeline_summaryIncludesRuntimeReuseHints() {
        var timeline = MarkdownPreviewTimeline(
            filePath: "/tmp/demo.md",
            startedAt: 10.0
        )

        timeline.runtimeWasReused = true
        timeline.runtimeWasPrewarmed = true
        timeline.shellMode = .reusedShell
        timeline.mark(.firstChunkReady, at: 10.010)
        timeline.mark(.sessionPrepared, at: 10.030)
        timeline.mark(.bootstrapScriptPrepared, at: 10.034)
        timeline.mark(.shellLoadIssued, at: 10.039)
        timeline.mark(.shellReuseResetApplied, at: 10.047)
        timeline.mark(.shellReuseBaseUpdated, at: 10.052)
        timeline.mark(.shellReuseBootstrapRendered, at: 10.061)
        timeline.mark(.shellReuseBootstrapAttached, at: 10.064)
        timeline.mark(.shellReuseBootstrapMeasured, at: 10.069)
        timeline.mark(.shellReuseBootstrapApplied, at: 10.071)
        timeline.mark(.shellReuseStyleApplied, at: 10.083)
        timeline.mark(.webViewDidFinish, at: 10.090)
        timeline.mark(.bootstrapReady, at: 10.120)

        XCTAssertEqual(
            timeline.summary,
            "[MarkdownPreview][demo.md] total=120ms chunk=10ms prepare=20ms webview=60ms bootstrap=30ms reused=true prewarmed=true prepareMount=0ms prepareMountView=0ms prepareMountCheckoutQueue=0ms prepareMountCheckout=0ms prepareMountBind=0ms prepareDispatch=0ms prepareWork=20ms shell=reuse scriptPrep=4ms shellPrep=5ms script=51ms reset=8ms resetStart=0ms resetClear=8ms resetFinalize=0ms base=5ms bootstrapApply=19ms render=9ms attach=3ms measure=5ms post=2ms style=12ms finalize=7ms"
        )
    }

    func test_previewTimeline_summaryIncludesPrepareDetailMetrics() {
        var timeline = MarkdownPreviewTimeline(
            filePath: "/tmp/Notes/episode.md",
            startedAt: 10.0
        )

        timeline.prepareMetrics = MarkdownPreviewPrepareMetrics(
            sourceMs: 6,
            bootstrapPlanMs: 4,
            bootstrapContentMs: 3,
            bootstrapSnapshotMs: 8,
            continuationMs: 2,
            snapshotRenderMetrics: MarkdownSnapshotRenderMetrics(
                markdownRenderMs: 5,
                imageMetadataMs: 1,
                tableWrapMs: 1,
                highlightMs: 2
            )
        )
        timeline.shellMode = .reusedShell
        timeline.mark(.firstChunkReady, at: 10.018)
        timeline.mark(.sessionPrepared, at: 10.041)
        timeline.mark(.bootstrapScriptPrepared, at: 10.044)
        timeline.mark(.shellLoadIssued, at: 10.052)
        timeline.mark(.shellReuseResetApplied, at: 10.057)
        timeline.mark(.shellReuseBaseUpdated, at: 10.059)
        timeline.mark(.shellReuseBootstrapRendered, at: 10.062)
        timeline.mark(.shellReuseBootstrapAttached, at: 10.063)
        timeline.mark(.shellReuseBootstrapMeasured, at: 10.063)
        timeline.mark(.shellReuseBootstrapApplied, at: 10.064)
        timeline.mark(.shellReuseStyleApplied, at: 10.066)
        timeline.mark(.webViewDidFinish, at: 10.071)
        timeline.mark(.bootstrapReady, at: 10.090)

        XCTAssertEqual(
            timeline.summary,
            "[MarkdownPreview][episode.md] total=90ms chunk=18ms prepare=23ms webview=30ms bootstrap=19ms reused=false prewarmed=false prepareMount=0ms prepareMountView=0ms prepareMountCheckoutQueue=0ms prepareMountCheckout=0ms prepareMountBind=0ms prepareDispatch=0ms prepareWork=23ms prepareSource=6ms preparePlan=4ms prepareBootstrapContent=3ms prepareSnapshot=8ms prepareContinuation=2ms snapshotMarkdown=5ms snapshotImage=1ms snapshotTable=1ms snapshotHighlight=2ms snapshotLock=0ms snapshotPrime=0ms snapshotHeights=0ms snapshotFinalize=0ms shell=reuse scriptPrep=3ms shellPrep=8ms script=19ms reset=5ms resetStart=0ms resetClear=5ms resetFinalize=0ms base=2ms bootstrapApply=5ms render=3ms attach=1ms measure=0ms post=1ms style=2ms finalize=5ms"
        )
    }

    func test_previewTimeline_reusedShellSummaryDoesNotReportNegativeBootstrapWhenReadyArrivesBeforeCompletion() {
        var timeline = MarkdownPreviewTimeline(
            filePath: "/tmp/README-cn.md",
            startedAt: 10.0
        )

        timeline.runtimeWasReused = true
        timeline.runtimeWasPrewarmed = true
        timeline.shellMode = .reusedShell
        timeline.mark(.firstChunkReady, at: 10.002)
        timeline.mark(.sessionPrepared, at: 10.023)
        timeline.mark(.bootstrapScriptPrepared, at: 10.028)
        timeline.mark(.shellLoadIssued, at: 10.028)
        timeline.mark(.shellReuseResetApplied, at: 10.030)
        timeline.mark(.shellReuseBaseUpdated, at: 10.030)
        timeline.mark(.shellReuseBootstrapRendered, at: 10.031)
        timeline.mark(.shellReuseBootstrapAttached, at: 10.031)
        timeline.mark(.shellReuseBootstrapMeasured, at: 10.031)
        timeline.mark(.shellReuseBootstrapApplied, at: 10.031)
        timeline.mark(.shellReuseStyleApplied, at: 10.032)
        timeline.mark(.bootstrapReady, at: 10.032)
        timeline.mark(.webViewDidFinish, at: 10.035)

        XCTAssertEqual(
            timeline.summary,
            "[MarkdownPreview][README-cn.md] total=35ms chunk=2ms prepare=21ms webview=12ms bootstrap=0ms reused=true prewarmed=true prepareMount=0ms prepareMountView=0ms prepareMountCheckoutQueue=0ms prepareMountCheckout=0ms prepareMountBind=0ms prepareDispatch=0ms prepareWork=21ms shell=reuse scriptPrep=5ms shellPrep=0ms script=7ms reset=2ms resetStart=0ms resetClear=2ms resetFinalize=0ms base=0ms bootstrapApply=1ms render=1ms attach=0ms measure=0ms post=0ms style=1ms finalize=3ms"
        )
    }

    func test_previewTimeline_remainsIncompleteBeforeBootstrapReady() {
        var timeline = MarkdownPreviewTimeline(
            filePath: "/tmp/Notes/episode.md",
            startedAt: 25.0
        )

        timeline.mark(.firstChunkReady, at: 25.010)
        timeline.mark(.sessionPrepared, at: 25.030)
        timeline.mark(.webViewDidFinish, at: 25.090)

        XCTAssertNil(timeline.summary)
    }

    func test_previewTimelineTracker_emitsCompletedSummaryViaSummarySink() {
        let messages = DiagnosticMessageBox()
        MarkdownPreviewTimelineTracker.summarySink = { message in
            messages.append(message)
        }

        let tracker = MarkdownPreviewTimelineTracker(
            filePath: "/tmp/demo.md",
            startedAt: 10.0
        )

        tracker.mark(.firstChunkReady, at: 10.010)
        tracker.mark(.sessionPrepared, at: 10.030)
        tracker.mark(.bootstrapScriptPrepared, at: 10.034)
        tracker.mark(.shellLoadIssued, at: 10.039)
        tracker.mark(.shellReuseResetApplied, at: 10.047)
        tracker.mark(.shellReuseBaseUpdated, at: 10.052)
        tracker.mark(.shellReuseBootstrapRendered, at: 10.061)
        tracker.mark(.shellReuseBootstrapAttached, at: 10.064)
        tracker.mark(.shellReuseBootstrapMeasured, at: 10.069)
        tracker.mark(.shellReuseBootstrapApplied, at: 10.071)
        tracker.mark(.shellReuseStyleApplied, at: 10.083)
        tracker.mark(.webViewDidFinish, at: 10.090)
        tracker.mark(.bootstrapReady, at: 10.120)
        tracker.annotateRuntimeHints(reused: true, prewarmed: true)

        tracker.logSummaryIfComplete()

        XCTAssertEqual(
            messages.snapshot(),
            ["[MarkdownPreview][demo.md] total=120ms chunk=10ms prepare=20ms webview=60ms bootstrap=30ms reused=true prewarmed=true prepareMount=0ms prepareMountView=0ms prepareMountCheckoutQueue=0ms prepareMountCheckout=0ms prepareMountBind=0ms prepareDispatch=0ms prepareWork=20ms shell=reuse scriptPrep=4ms shellPrep=5ms script=51ms reset=8ms resetStart=0ms resetClear=8ms resetFinalize=0ms base=5ms bootstrapApply=19ms render=9ms attach=3ms measure=5ms post=2ms style=12ms finalize=7ms"]
        )
    }

    func test_appDiagnostics_routesCategoryAndMessageThroughSink() {
        let captured = DiagnosticCaptureBox()
        AppDiagnostics.sink = { category, message in
            captured.append((category, message))
        }

        AppDiagnostics.log("preview ready", category: "MarkdownPreview")

        let entries = captured.snapshot()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.0, "MarkdownPreview")
        XCTAssertEqual(entries.first?.1, "preview ready")
    }

    func test_appDiagnostics_formattedEntryIncludesProcessIdentity() {
        let entry = AppDiagnostics.formattedEntry(
            category: "MarkdownPreview",
            message: "preview ready",
            date: Date(timeIntervalSince1970: 1_717_171_717.123)
        )

        XCTAssertTrue(entry.contains("[MarkdownPreview]"))
        XCTAssertTrue(entry.contains("pid="))
        XCTAssertTrue(entry.contains("process="))
        XCTAssertTrue(entry.contains("exec="))
        XCTAssertTrue(entry.contains("preview ready"))
    }

    func test_appDiagnostics_defaultSinkAppendsToFile() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let logURL = temporaryDirectory.appendingPathComponent("quickcookies-diagnostics.log", isDirectory: false)

        AppDiagnostics.fileURLProvider = { logURL }

        AppDiagnostics.defaultSink(category: "MarkdownPreview", message: "file sink test")

        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: logURL.path) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("[MarkdownPreview]"))
        XCTAssertTrue(contents.contains("file sink test"))
    }

    func test_makeBootstrapPlan_keepsOpeningBlocksUntilViewportIsFilled() {
        let blocks = [
            MarkdownRenderBlock(id: "p0", kind: .paragraph, markdown: "Intro", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c0", kind: .code, markdown: "```swift\nprint(1)\nprint(2)\n```", preferredHeight: 220, imageMetas: [], codeLanguage: "swift"),
            MarkdownRenderBlock(id: "p1", kind: .paragraph, markdown: "After code", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c1", kind: .code, markdown: "```swift\nprint(3)\nprint(4)\n```", preferredHeight: 220, imageMetas: [], codeLanguage: "swift")
        ]

        let plan = MarkdownPreviewSessionBuilder.makeBootstrapPlan(
            blocks: blocks,
            effectiveFileSize: 1024,
            requiresDeferredLoad: false,
            viewportHeight: 320,
            policy: MarkdownPreviewPolicy()
        )

        XCTAssertEqual(plan.bootstrapBlocks.map(\.id), ["p0", "c0", "p1", "c1"])
        XCTAssertTrue(plan.deferredBlocks.isEmpty)
        XCTAssertFalse(plan.shouldVirtualize)
    }

    func test_makeBootstrapPlan_insertsPlaceholderForEmptyDocument() {
        let plan = MarkdownPreviewSessionBuilder.makeBootstrapPlan(
            blocks: [],
            effectiveFileSize: 0,
            requiresDeferredLoad: false,
            viewportHeight: 320,
            policy: MarkdownPreviewPolicy()
        )

        XCTAssertEqual(plan.bootstrapBlocks.map(\.id), ["markdown-block-empty"])
        XCTAssertTrue(plan.deferredBlocks.isEmpty)
    }

    func test_makeBootstrapPlan_keepsCodeDenseOpeningBlocksInBootstrap() {
        let blocks = [
            MarkdownRenderBlock(id: "p0", kind: .paragraph, markdown: "Intro", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c0", kind: .code, markdown: "```swift\nprint(1)\nprint(2)\nprint(3)\n```", preferredHeight: 180, imageMetas: [], codeLanguage: "swift"),
            MarkdownRenderBlock(id: "p1", kind: .paragraph, markdown: "Detail", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c1", kind: .code, markdown: "```swift\nprint(4)\nprint(5)\nprint(6)\n```", preferredHeight: 180, imageMetas: [], codeLanguage: "swift"),
            MarkdownRenderBlock(id: "p2", kind: .paragraph, markdown: "More", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c2", kind: .code, markdown: "```swift\nprint(7)\nprint(8)\nprint(9)\n```", preferredHeight: 180, imageMetas: [], codeLanguage: "swift")
        ]

        let plan = MarkdownPreviewSessionBuilder.makeBootstrapPlan(
            blocks: blocks,
            effectiveFileSize: 16 * 1024,
            requiresDeferredLoad: false,
            viewportHeight: 900,
            policy: MarkdownPreviewPolicy()
        )

        XCTAssertEqual(plan.bootstrapBlocks.map(\.id), ["p0", "c0", "p1", "c1", "p2", "c2"])
        XCTAssertTrue(plan.deferredBlocks.isEmpty)
    }

    func test_makeBootstrapPlan_keepsSmallGlossaryCodeNotesInBootstrap() {
        let blocks = [
            MarkdownRenderBlock(id: "p0", kind: .paragraph, markdown: "Line 1", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "p1", kind: .paragraph, markdown: "Line 2", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "p2", kind: .paragraph, markdown: "Line 3", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c0", kind: .code, markdown: "```\nshort note\n```", preferredHeight: 100, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "p3", kind: .paragraph, markdown: "Line 4", preferredHeight: 44, imageMetas: [], codeLanguage: nil),
            MarkdownRenderBlock(id: "c1", kind: .code, markdown: "```\nshort note 2\n```", preferredHeight: 100, imageMetas: [], codeLanguage: nil)
        ]

        let plan = MarkdownPreviewSessionBuilder.makeBootstrapPlan(
            blocks: blocks,
            effectiveFileSize: 40 * 1024,
            requiresDeferredLoad: false,
            viewportHeight: 900,
            policy: MarkdownPreviewPolicy()
        )

        XCTAssertEqual(plan.bootstrapBlocks.map(\.id), ["p0", "p1", "p2", "c0", "p3", "c1"])
        XCTAssertTrue(plan.deferredBlocks.isEmpty)
    }

    func test_makeBootstrapPlan_allowsManyShortParagraphsToFillViewport() {
        let blocks = (0..<18).map { index in
            MarkdownRenderBlock(
                id: "p\(index)",
                kind: .paragraph,
                markdown: "Line \(index)",
                preferredHeight: 44,
                imageMetas: [],
                codeLanguage: nil
            )
        }

        let plan = MarkdownPreviewSessionBuilder.makeBootstrapPlan(
            blocks: blocks,
            effectiveFileSize: 24 * 1024,
            requiresDeferredLoad: false,
            viewportHeight: 900,
            policy: MarkdownPreviewPolicy()
        )

        XCTAssertEqual(plan.bootstrapBlocks.count, 18)
        XCTAssertTrue(plan.deferredBlocks.isEmpty)
    }
}
