import Foundation
import AppKit
import JavaScriptCore
import OSLog

enum AppDiagnostics {
    static var fileURLProvider: @Sendable () -> URL = {
        URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("quickcookies-diagnostics.log", isDirectory: false)
    }

    // Runtime diagnostics are opt-in during local debugging. Production flows
    // keep the sink silent unless a test or a temporary investigation overrides
    // it explicitly.
    static var sink: @Sendable (_ category: String, _ message: String) -> Void = { _, _ in }

    static func defaultSink(category: String, message: String) {
        let logger = Logger(subsystem: "com.quickcookies.app", category: category)
        logger.log(level: .default, "\(message, privacy: .public)")
        let entry = formattedEntry(category: category, message: message)
        NSLog("%@", entry)
        appendToFile(entry)
    }

    static func log(_ message: String, category: String) {
        sink(category, message)
    }

    static func resetForTesting() {
        sink = defaultSink
        fileURLProvider = {
            URL(fileURLWithPath: "/tmp", isDirectory: true)
                .appendingPathComponent("quickcookies-diagnostics.log", isDirectory: false)
        }
    }

    static func formattedEntry(
        category: String,
        message: String,
        date: Date = Date(),
        processInfo: ProcessInfo = .processInfo,
        bundle: Bundle = .main
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let timestamp = formatter.string(from: date)
        let executablePath = bundle.executableURL?.path ?? bundle.bundleURL.path
        let processName = processInfo.processName
        let pid = processInfo.processIdentifier

        return "\(timestamp) [\(category)] pid=\(pid) process=\(processName) exec=\(executablePath) \(message)"
    }

    private static let fileWriteQueue = DispatchQueue(label: "com.quickcookies.app.diagnostics.file")

    private static func appendToFile(_ entry: String) {
        let fileURL = fileURLProvider()

        fileWriteQueue.async {
            let line = entry + "\n"
            let data = Data(line.utf8)
            let directoryURL = fileURL.deletingLastPathComponent()

            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer {
                        try? handle.close()
                    }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: fileURL, options: [.atomic])
                }
            } catch {
                NSLog("AppDiagnostics file write failed: %@", error.localizedDescription)
            }
        }
    }
}

protocol MarkdownPreviewTimelineRecording: AnyObject {
    func mark(_ stage: MarkdownPreviewTimeline.Stage, at timestamp: TimeInterval)
    func annotateRuntimeHints(reused: Bool, prewarmed: Bool)
    func annotatePrepareMetrics(_ metrics: MarkdownPreviewPrepareMetrics?)
    func logSummaryIfComplete()
}

extension MarkdownPreviewTimelineRecording {
    func mark(_ stage: MarkdownPreviewTimeline.Stage) {
        mark(stage, at: ProcessInfo.processInfo.systemUptime)
    }

    func annotateRuntimeHints(reused: Bool, prewarmed: Bool) {}
    func annotatePrepareMetrics(_ metrics: MarkdownPreviewPrepareMetrics?) {}
}

struct MarkdownSnapshotRenderMetrics {
    let markdownRenderMs: Int
    let imageMetadataMs: Int
    let tableWrapMs: Int
    let highlightMs: Int
    let lockWaitMs: Int
    let firstRenderPrimeMs: Int
    let blockHeightsMs: Int
    let snapshotFinalizeMs: Int

    init(
        markdownRenderMs: Int,
        imageMetadataMs: Int,
        tableWrapMs: Int,
        highlightMs: Int,
        lockWaitMs: Int = 0,
        firstRenderPrimeMs: Int = 0,
        blockHeightsMs: Int = 0,
        snapshotFinalizeMs: Int = 0
    ) {
        self.markdownRenderMs = markdownRenderMs
        self.imageMetadataMs = imageMetadataMs
        self.tableWrapMs = tableWrapMs
        self.highlightMs = highlightMs
        self.lockWaitMs = lockWaitMs
        self.firstRenderPrimeMs = firstRenderPrimeMs
        self.blockHeightsMs = blockHeightsMs
        self.snapshotFinalizeMs = snapshotFinalizeMs
    }
}

struct MarkdownPreviewPrepareMetrics {
    let sourceMs: Int
    let bootstrapPlanMs: Int
    let bootstrapContentMs: Int
    let bootstrapSnapshotMs: Int
    let continuationMs: Int
    let snapshotRenderMetrics: MarkdownSnapshotRenderMetrics?
}

struct MarkdownPreviewTimeline {
    enum ShellMode {
        case fullNavigation
        case reusedShell
    }

    enum Stage {
        case firstChunkReady
        case previewMountStarted
        case runtimeCheckoutStarted
        case runtimeCheckoutCompleted
        case sessionLoadRequested
        case sessionPreparationStarted
        case sessionPrepared
        case bootstrapScriptPrepared
        case shellLoadIssued
        case shellReuseResetStarted
        case shellReuseResetCleared
        case shellReuseResetApplied
        case shellReuseBaseUpdated
        case shellReuseBootstrapRendered
        case shellReuseBootstrapAttached
        case shellReuseBootstrapMeasured
        case shellReuseBootstrapApplied
        case shellReuseStyleApplied
        case navigationStarted
        case navigationCommitted
        case webViewDidFinish
        case bootstrapReady
    }

    let filePath: String
    let startedAt: TimeInterval

    var shellMode: ShellMode?
    var runtimeWasReused = false
    var runtimeWasPrewarmed = false
    var prepareMetrics: MarkdownPreviewPrepareMetrics?
    private(set) var firstChunkReadyAt: TimeInterval?
    private(set) var previewMountStartedAt: TimeInterval?
    private(set) var runtimeCheckoutStartedAt: TimeInterval?
    private(set) var runtimeCheckoutCompletedAt: TimeInterval?
    private(set) var sessionLoadRequestedAt: TimeInterval?
    private(set) var sessionPreparationStartedAt: TimeInterval?
    private(set) var sessionPreparedAt: TimeInterval?
    private(set) var bootstrapScriptPreparedAt: TimeInterval?
    private(set) var shellLoadIssuedAt: TimeInterval?
    private(set) var shellReuseResetStartedAt: TimeInterval?
    private(set) var shellReuseResetClearedAt: TimeInterval?
    private(set) var shellReuseResetAppliedAt: TimeInterval?
    private(set) var shellReuseBaseUpdatedAt: TimeInterval?
    private(set) var shellReuseBootstrapRenderedAt: TimeInterval?
    private(set) var shellReuseBootstrapAttachedAt: TimeInterval?
    private(set) var shellReuseBootstrapMeasuredAt: TimeInterval?
    private(set) var shellReuseBootstrapAppliedAt: TimeInterval?
    private(set) var shellReuseStyleAppliedAt: TimeInterval?
    private(set) var navigationStartedAt: TimeInterval?
    private(set) var navigationCommittedAt: TimeInterval?
    private(set) var webViewDidFinishAt: TimeInterval?
    private(set) var bootstrapReadyAt: TimeInterval?

    init(filePath: String, startedAt: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.filePath = filePath
        self.startedAt = startedAt
    }

    mutating func mark(_ stage: Stage, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        switch stage {
        case .firstChunkReady:
            if firstChunkReadyAt == nil {
                firstChunkReadyAt = timestamp
            }
        case .previewMountStarted:
            if previewMountStartedAt == nil {
                previewMountStartedAt = timestamp
            }
        case .runtimeCheckoutStarted:
            if runtimeCheckoutStartedAt == nil {
                runtimeCheckoutStartedAt = timestamp
            }
        case .runtimeCheckoutCompleted:
            if runtimeCheckoutCompletedAt == nil {
                runtimeCheckoutCompletedAt = timestamp
            }
        case .sessionLoadRequested:
            if sessionLoadRequestedAt == nil {
                sessionLoadRequestedAt = timestamp
            }
        case .sessionPreparationStarted:
            if sessionPreparationStartedAt == nil {
                sessionPreparationStartedAt = timestamp
            }
        case .sessionPrepared:
            if sessionPreparedAt == nil {
                sessionPreparedAt = timestamp
            }
        case .bootstrapScriptPrepared:
            if bootstrapScriptPreparedAt == nil {
                bootstrapScriptPreparedAt = timestamp
            }
        case .shellLoadIssued:
            if shellLoadIssuedAt == nil {
                shellLoadIssuedAt = timestamp
            }
        case .shellReuseResetStarted:
            if shellReuseResetStartedAt == nil {
                shellReuseResetStartedAt = timestamp
            }
        case .shellReuseResetCleared:
            if shellReuseResetClearedAt == nil {
                shellReuseResetClearedAt = timestamp
            }
        case .shellReuseResetApplied:
            if shellReuseResetAppliedAt == nil {
                shellReuseResetAppliedAt = timestamp
            }
        case .shellReuseBaseUpdated:
            if shellReuseBaseUpdatedAt == nil {
                shellReuseBaseUpdatedAt = timestamp
            }
        case .shellReuseBootstrapRendered:
            if shellReuseBootstrapRenderedAt == nil {
                shellReuseBootstrapRenderedAt = timestamp
            }
        case .shellReuseBootstrapAttached:
            if shellReuseBootstrapAttachedAt == nil {
                shellReuseBootstrapAttachedAt = timestamp
            }
        case .shellReuseBootstrapMeasured:
            if shellReuseBootstrapMeasuredAt == nil {
                shellReuseBootstrapMeasuredAt = timestamp
            }
        case .shellReuseBootstrapApplied:
            if shellReuseBootstrapAppliedAt == nil {
                shellReuseBootstrapAppliedAt = timestamp
            }
        case .shellReuseStyleApplied:
            if shellReuseStyleAppliedAt == nil {
                shellReuseStyleAppliedAt = timestamp
            }
        case .navigationStarted:
            if navigationStartedAt == nil {
                navigationStartedAt = timestamp
            }
        case .navigationCommitted:
            if navigationCommittedAt == nil {
                navigationCommittedAt = timestamp
            }
        case .webViewDidFinish:
            if webViewDidFinishAt == nil {
                webViewDidFinishAt = timestamp
            }
        case .bootstrapReady:
            if bootstrapReadyAt == nil {
                bootstrapReadyAt = timestamp
            }
        }
    }

    var summary: String? {
        guard let firstChunkReadyAt,
              let sessionPreparedAt,
              let webViewDidFinishAt,
              let bootstrapReadyAt else {
            return nil
        }

        let completedAt = max(webViewDidFinishAt, bootstrapReadyAt)
        let total = milliseconds(from: startedAt, to: completedAt)
        let chunk = milliseconds(from: startedAt, to: firstChunkReadyAt)
        let prepare = milliseconds(from: firstChunkReadyAt, to: sessionPreparedAt)
        let webView = milliseconds(from: sessionPreparedAt, to: webViewDidFinishAt)
        let bootstrap = milliseconds(from: webViewDidFinishAt, to: completedAt)
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let prepareDetails = prepareDetailSummary(
            firstChunkReadyAt: firstChunkReadyAt,
            sessionPreparedAt: sessionPreparedAt
        )
        let shellDetails = shellDetailSummary(sessionPreparedAt: sessionPreparedAt, webViewDidFinishAt: webViewDidFinishAt)

        return "[MarkdownPreview][\(fileName)] total=\(total)ms chunk=\(chunk)ms prepare=\(prepare)ms webview=\(webView)ms bootstrap=\(bootstrap)ms reused=\(runtimeWasReused) prewarmed=\(runtimeWasPrewarmed)\(prepareDetails)\(shellDetails)"
    }

    private func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        Int(((end - start) * 1000).rounded())
    }

    private func shellDetailSummary(
        sessionPreparedAt: TimeInterval,
        webViewDidFinishAt: TimeInterval
    ) -> String {
        guard let shellLoadIssuedAt else { return "" }

        let inferredShellMode = shellMode ?? {
            if navigationStartedAt != nil || navigationCommittedAt != nil {
                return .fullNavigation
            }
            return .reusedShell
        }()

        let bootstrapScriptPreparedAt = self.bootstrapScriptPreparedAt ?? shellLoadIssuedAt
        let scriptPrep = milliseconds(from: sessionPreparedAt, to: bootstrapScriptPreparedAt)
        let shellPrep = milliseconds(from: bootstrapScriptPreparedAt, to: shellLoadIssuedAt)

        switch inferredShellMode {
        case .fullNavigation:
            guard let navigationStartedAt,
                  let navigationCommittedAt else {
                return " shell=nav scriptPrep=\(scriptPrep)ms shellPrep=\(shellPrep)ms"
            }

            let provisional = milliseconds(from: shellLoadIssuedAt, to: navigationStartedAt)
            let commit = milliseconds(from: navigationStartedAt, to: navigationCommittedAt)
            let finish = milliseconds(from: navigationCommittedAt, to: webViewDidFinishAt)
            return " shell=nav scriptPrep=\(scriptPrep)ms shellPrep=\(shellPrep)ms provisional=\(provisional)ms commit=\(commit)ms finish=\(finish)ms"
        case .reusedShell:
            let script = milliseconds(from: shellLoadIssuedAt, to: webViewDidFinishAt)
            guard let shellReuseResetAppliedAt else {
                return " shell=reuse scriptPrep=\(scriptPrep)ms shellPrep=\(shellPrep)ms script=\(script)ms"
            }

            let shellReuseResetStartedAt = self.shellReuseResetStartedAt ?? shellLoadIssuedAt
            let shellReuseResetClearedAt = self.shellReuseResetClearedAt ?? shellReuseResetAppliedAt
            let shellReuseBaseUpdatedAt = self.shellReuseBaseUpdatedAt ?? shellReuseResetAppliedAt
            let shellReuseBootstrapRenderedAt = self.shellReuseBootstrapRenderedAt ?? shellReuseBaseUpdatedAt
            let shellReuseBootstrapAttachedAt = self.shellReuseBootstrapAttachedAt ?? shellReuseBootstrapRenderedAt
            let shellReuseBootstrapMeasuredAt = self.shellReuseBootstrapMeasuredAt ?? shellReuseBootstrapAttachedAt
            let shellReuseBootstrapAppliedAt = self.shellReuseBootstrapAppliedAt ?? shellReuseBaseUpdatedAt
            let shellReuseStyleAppliedAt = self.shellReuseStyleAppliedAt ?? shellReuseBootstrapAppliedAt
            let reset = milliseconds(from: shellLoadIssuedAt, to: shellReuseResetAppliedAt)
            let resetStart = milliseconds(from: shellLoadIssuedAt, to: shellReuseResetStartedAt)
            let resetClear = milliseconds(from: shellReuseResetStartedAt, to: shellReuseResetClearedAt)
            let resetFinalize = milliseconds(from: shellReuseResetClearedAt, to: shellReuseResetAppliedAt)
            let base = milliseconds(from: shellReuseResetAppliedAt, to: shellReuseBaseUpdatedAt)
            let bootstrapApply = milliseconds(from: shellReuseBaseUpdatedAt, to: shellReuseBootstrapAppliedAt)
            let render = milliseconds(from: shellReuseBaseUpdatedAt, to: shellReuseBootstrapRenderedAt)
            let attach = milliseconds(from: shellReuseBootstrapRenderedAt, to: shellReuseBootstrapAttachedAt)
            let measure = milliseconds(from: shellReuseBootstrapAttachedAt, to: shellReuseBootstrapMeasuredAt)
            let post = milliseconds(from: shellReuseBootstrapMeasuredAt, to: shellReuseBootstrapAppliedAt)
            let style = milliseconds(from: shellReuseBootstrapAppliedAt, to: shellReuseStyleAppliedAt)
            let finalize = milliseconds(from: shellReuseStyleAppliedAt, to: webViewDidFinishAt)
            return " shell=reuse scriptPrep=\(scriptPrep)ms shellPrep=\(shellPrep)ms script=\(script)ms reset=\(reset)ms resetStart=\(resetStart)ms resetClear=\(resetClear)ms resetFinalize=\(resetFinalize)ms base=\(base)ms bootstrapApply=\(bootstrapApply)ms render=\(render)ms attach=\(attach)ms measure=\(measure)ms post=\(post)ms style=\(style)ms finalize=\(finalize)ms"
        }
    }

    private func prepareDetailSummary(
        firstChunkReadyAt: TimeInterval,
        sessionPreparedAt: TimeInterval
    ) -> String {
        let sessionLoadRequestedAt = self.sessionLoadRequestedAt ?? firstChunkReadyAt
        let sessionPreparationStartedAt = self.sessionPreparationStartedAt ?? sessionLoadRequestedAt
        let previewMountStartedAt = self.previewMountStartedAt ?? firstChunkReadyAt
        let runtimeCheckoutStartedAt = self.runtimeCheckoutStartedAt ?? previewMountStartedAt
        let runtimeCheckoutCompletedAt = self.runtimeCheckoutCompletedAt ?? runtimeCheckoutStartedAt
        let prepareMount = milliseconds(from: firstChunkReadyAt, to: sessionLoadRequestedAt)
        let prepareMountView = milliseconds(from: firstChunkReadyAt, to: previewMountStartedAt)
        let prepareMountCheckoutQueue = milliseconds(from: previewMountStartedAt, to: runtimeCheckoutStartedAt)
        let prepareMountCheckout = milliseconds(from: runtimeCheckoutStartedAt, to: runtimeCheckoutCompletedAt)
        let prepareMountBind = milliseconds(from: runtimeCheckoutCompletedAt, to: sessionLoadRequestedAt)
        let prepareDispatch = milliseconds(from: sessionLoadRequestedAt, to: sessionPreparationStartedAt)
        let prepareWork = milliseconds(from: sessionPreparationStartedAt, to: sessionPreparedAt)

        var summary = " prepareMount=\(prepareMount)ms prepareMountView=\(prepareMountView)ms prepareMountCheckoutQueue=\(prepareMountCheckoutQueue)ms prepareMountCheckout=\(prepareMountCheckout)ms prepareMountBind=\(prepareMountBind)ms prepareDispatch=\(prepareDispatch)ms prepareWork=\(prepareWork)ms"

        guard let prepareMetrics else { return summary }

        summary += " prepareSource=\(prepareMetrics.sourceMs)ms preparePlan=\(prepareMetrics.bootstrapPlanMs)ms prepareBootstrapContent=\(prepareMetrics.bootstrapContentMs)ms prepareSnapshot=\(prepareMetrics.bootstrapSnapshotMs)ms prepareContinuation=\(prepareMetrics.continuationMs)ms"

        if let snapshotMetrics = prepareMetrics.snapshotRenderMetrics {
            summary += " snapshotMarkdown=\(snapshotMetrics.markdownRenderMs)ms snapshotImage=\(snapshotMetrics.imageMetadataMs)ms snapshotTable=\(snapshotMetrics.tableWrapMs)ms snapshotHighlight=\(snapshotMetrics.highlightMs)ms snapshotLock=\(snapshotMetrics.lockWaitMs)ms snapshotPrime=\(snapshotMetrics.firstRenderPrimeMs)ms snapshotHeights=\(snapshotMetrics.blockHeightsMs)ms snapshotFinalize=\(snapshotMetrics.snapshotFinalizeMs)ms"
        }

        return summary
    }
}

final class MarkdownPreviewTimelineTracker: MarkdownPreviewTimelineRecording {
    static var summarySink: @Sendable (String) -> Void = { _ in }

    private let lock = NSLock()
    private var timeline: MarkdownPreviewTimeline
    private var hasLoggedSummary = false

    init(filePath: String, startedAt: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        timeline = MarkdownPreviewTimeline(filePath: filePath, startedAt: startedAt)
    }

    func mark(_ stage: MarkdownPreviewTimeline.Stage, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.lock()
        timeline.mark(stage, at: timestamp)
        lock.unlock()
    }

    func annotateRuntimeHints(reused: Bool, prewarmed: Bool) {
        lock.lock()
        timeline.runtimeWasReused = reused
        timeline.runtimeWasPrewarmed = prewarmed
        lock.unlock()
    }

    func annotatePrepareMetrics(_ metrics: MarkdownPreviewPrepareMetrics?) {
        lock.lock()
        timeline.prepareMetrics = metrics
        lock.unlock()
    }

    func logSummaryIfComplete() {
        let summary: String?

        lock.lock()
        if hasLoggedSummary {
            summary = nil
        } else {
            summary = timeline.summary
            if summary != nil {
                hasLoggedSummary = true
            }
        }
        lock.unlock()

        if let summary {
            Self.summarySink(summary)
        }
    }
}

struct MarkdownBootstrapPlan {
    let bootstrapBlocks: [MarkdownRenderBlock]
    let deferredBlocks: [MarkdownRenderBlock]
    let shouldVirtualize: Bool
    let overscanScreens: Int
}

struct MarkdownPreviewSession {
    let bootstrapContent: MarkdownPreviewPreparedContent
    let continuationContent: MarkdownPreviewPreparedContent?
    let bootstrapSnapshot: MarkdownRenderSnapshot?
    let prepareMetrics: MarkdownPreviewPrepareMetrics?
}

enum MarkdownPreviewSessionBuilder {
    static func makeBootstrapPlan(
        blocks: [MarkdownRenderBlock],
        effectiveFileSize: UInt64,
        requiresDeferredLoad: Bool,
        viewportHeight: Double,
        policy: MarkdownPreviewPolicy
    ) -> MarkdownBootstrapPlan {
        let viewportBlocks = MarkdownViewportPlanner().initialViewportSlice(
            from: blocks,
            viewportHeight: viewportHeight,
            overscanRatio: policy.initialViewportOverscanRatio,
            minimumBlockCount: policy.minimumInitialViewportBlockCount,
            maximumBlockCount: policy.maximumInitialViewportBlockCount,
            maximumHeavyBlockCount: policy.maximumInitialHeavyBlockCount
        )

        let bootstrapBlocks = viewportBlocks.isEmpty
            ? [MarkdownPreviewBridge.emptyPlaceholderBlock()]
            : viewportBlocks
        let deferredBlocks = requiresDeferredLoad ? [] : Array(blocks.dropFirst(viewportBlocks.count))
        let effectiveBlockCount = max(blocks.count, bootstrapBlocks.count)
        let shouldVirtualize = policy.shouldVirtualize(
            fileSize: effectiveFileSize,
            blockCount: effectiveBlockCount
        )
        let overscanScreens = policy.usesAggressiveVirtualization(fileSize: effectiveFileSize)
            ? max(policy.overscanScreens - 1, 2)
            : policy.overscanScreens

        return MarkdownBootstrapPlan(
            bootstrapBlocks: bootstrapBlocks,
            deferredBlocks: deferredBlocks,
            shouldVirtualize: shouldVirtualize,
            overscanScreens: overscanScreens
        )
    }

    static func prepare(
        filePath: String,
        fallbackMarkdown: String,
        preferFileBackedRendering: Bool,
        baseDirectoryURL: URL?,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        policy: MarkdownPreviewPolicy
    ) async throws -> MarkdownPreviewSession {
        let prepareStartedAt = ProcessInfo.processInfo.systemUptime
        let initialSource = MarkdownPreviewBridge.makeInitialSource(
            filePath: filePath,
            fallbackMarkdown: fallbackMarkdown,
            baseDirectoryURL: baseDirectoryURL
        )
        let sourcePreparedAt = ProcessInfo.processInfo.systemUptime
        let bootstrapPlan = makeBootstrapPlan(
            blocks: initialSource.blocks,
            effectiveFileSize: initialSource.effectiveFileSize,
            requiresDeferredLoad: initialSource.requiresDeferredLoad,
            viewportHeight: policy.fallbackViewportHeight,
            policy: policy
        )
        let bootstrapPlanPreparedAt = ProcessInfo.processInfo.systemUptime

        let bootstrapContent = MarkdownPreviewBridge.makePreparedContent(
            from: bootstrapPlan.bootstrapBlocks,
            effectiveFileSize: initialSource.effectiveFileSize,
            policy: policy,
            forceSingleBatch: true
        )
        let bootstrapContentPreparedAt = ProcessInfo.processInfo.systemUptime
        let bootstrapSnapshotResult = MarkdownBootstrapSnapshotRenderer.renderSnapshot(
            for: bootstrapPlan.bootstrapBlocks,
            shouldVirtualize: bootstrapPlan.shouldVirtualize,
            overscanScreens: bootstrapPlan.overscanScreens
        )
        let bootstrapSnapshotPreparedAt = ProcessInfo.processInfo.systemUptime
        let bootstrapSnapshot = bootstrapSnapshotResult.snapshot

        let continuationContent: MarkdownPreviewPreparedContent?
        if initialSource.requiresDeferredLoad {
            continuationContent = MarkdownPreviewBridge.prepareContent(
                filePath: filePath,
                fallbackMarkdown: fallbackMarkdown,
                preferFileBackedRendering: preferFileBackedRendering,
                baseDirectoryURL: baseDirectoryURL,
                policy: policy,
                droppingLeadingBlocks: bootstrapPlan.bootstrapBlocks.count,
                knownFileSize: initialSource.fileSize,
                allowsEmptyPlaceholder: false
            )
        } else {
            let deferredBlocks = bootstrapPlan.deferredBlocks
            continuationContent = deferredBlocks.isEmpty
                ? nil
                : MarkdownPreviewBridge.makePreparedContent(
                    from: deferredBlocks,
                    effectiveFileSize: initialSource.effectiveFileSize,
                    policy: policy
                )
        }
        let continuationPreparedAt = ProcessInfo.processInfo.systemUptime
        let prepareMetrics = MarkdownPreviewPrepareMetrics(
            sourceMs: milliseconds(from: prepareStartedAt, to: sourcePreparedAt),
            bootstrapPlanMs: milliseconds(from: sourcePreparedAt, to: bootstrapPlanPreparedAt),
            bootstrapContentMs: milliseconds(from: bootstrapPlanPreparedAt, to: bootstrapContentPreparedAt),
            bootstrapSnapshotMs: milliseconds(from: bootstrapContentPreparedAt, to: bootstrapSnapshotPreparedAt),
            continuationMs: milliseconds(from: bootstrapSnapshotPreparedAt, to: continuationPreparedAt),
            snapshotRenderMetrics: bootstrapSnapshotResult.metrics
        )

        return MarkdownPreviewSession(
            bootstrapContent: bootstrapContent,
            continuationContent: continuationContent,
            bootstrapSnapshot: bootstrapSnapshot,
            prepareMetrics: prepareMetrics
        )
    }

    private static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        Int(((end - start) * 1000).rounded())
    }
}

enum MarkdownPreviewSnapshotRendererWarmer {
    static func warmIfNeeded() {
        MarkdownBootstrapSnapshotRenderer.warmIfNeeded()
    }

    static var debugHasPrimedFirstRender: Bool {
        MarkdownBootstrapSnapshotRenderer.debugHasPrimedFirstRender
    }

    static var debugWarmInvocationCount: Int {
        MarkdownBootstrapSnapshotRenderer.debugWarmInvocationCount
    }

    static func debugResetWarmStateForTesting() {
        MarkdownBootstrapSnapshotRenderer.debugResetWarmStateForTesting()
    }
}

private enum MarkdownBootstrapSnapshotRenderer {
    private static let lock = NSLock()
    private static var sharedRenderer = Renderer()
    private static var hasPrimedFirstRender = false
    private static var warmInvocationCount = 0

    static func warmIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        _ = sharedRenderer
        if !hasPrimedFirstRender {
            _ = sharedRenderer.primeFirstRenderIfNeeded()
            hasPrimedFirstRender = true
            warmInvocationCount += 1
        }
    }

    static var debugHasPrimedFirstRender: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hasPrimedFirstRender
    }

    static var debugWarmInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return warmInvocationCount
    }

    static func debugResetWarmStateForTesting() {
        lock.lock()
        defer { lock.unlock() }
        sharedRenderer = Renderer()
        hasPrimedFirstRender = false
        warmInvocationCount = 0
    }

    static func renderSnapshot(
        for blocks: [MarkdownRenderBlock],
        shouldVirtualize: Bool,
        overscanScreens: Int
    ) -> (snapshot: MarkdownRenderSnapshot?, metrics: MarkdownSnapshotRenderMetrics?) {
        guard !blocks.isEmpty else { return (nil, nil) }

        let lockRequestedAt = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        let lockAcquiredAt = ProcessInfo.processInfo.systemUptime

        let primeStartedAt = lockAcquiredAt
        if !hasPrimedFirstRender {
            _ = sharedRenderer.primeFirstRenderIfNeeded()
            hasPrimedFirstRender = true
            warmInvocationCount += 1
        }
        let primeFinishedAt = ProcessInfo.processInfo.systemUptime

        var accumulatedMetrics = SnapshotRenderMetricAccumulator()
        let renderedBlocks: [MarkdownRenderedBlockSnapshot] = blocks.compactMap { block in
            guard let rendered = sharedRenderer.renderedSnapshot(for: block) else {
                return nil
            }
            accumulatedMetrics.accumulate(rendered.metrics)
            return rendered.snapshot
        }
        let renderLoopFinishedAt = ProcessInfo.processInfo.systemUptime

        guard renderedBlocks.count == blocks.count else {
            return (nil, nil)
        }

        let blockHeightsStartedAt = renderLoopFinishedAt
        let blockHeights: [String: Double] = Dictionary(uniqueKeysWithValues: renderedBlocks.compactMap { block -> (String, Double)? in
            guard let height = block.height, height > 0 else { return nil }
            return (block.id, height)
        })
        let blockHeightsFinishedAt = ProcessInfo.processInfo.systemUptime

        let snapshotStartedAt = blockHeightsFinishedAt
        let snapshot = MarkdownRenderSnapshot(
            renderedBlocks: renderedBlocks,
            blockOrder: renderedBlocks.map { $0.id },
            blockHeights: blockHeights,
            shouldVirtualize: shouldVirtualize,
            overscanScreens: overscanScreens
        )
        let snapshotFinishedAt = ProcessInfo.processInfo.systemUptime

        accumulatedMetrics.lockWaitMs += Self.milliseconds(from: lockRequestedAt, to: lockAcquiredAt)
        accumulatedMetrics.firstRenderPrimeMs += Self.milliseconds(from: primeStartedAt, to: primeFinishedAt)
        accumulatedMetrics.blockHeightsMs += Self.milliseconds(from: blockHeightsStartedAt, to: blockHeightsFinishedAt)
        accumulatedMetrics.snapshotFinalizeMs += Self.milliseconds(from: snapshotStartedAt, to: snapshotFinishedAt)

        return (
            snapshot,
            accumulatedMetrics.finalize()
        )
    }

    private static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        Int(((end - start) * 1000).rounded())
    }

    private final class Renderer {
        private let markedContext: JSContext?
        private let highlightContext: JSContext?

        init() {
            markedContext = JSContext()
            markedContext?.evaluateScript(MarkedJS.source)

            highlightContext = JSContext()
            if let script = Self.loadHighlightScript() {
                highlightContext?.evaluateScript(script)
            }
        }

        func primeFirstRenderIfNeeded() -> Bool {
            let warmupBlock = MarkdownRenderBlock(
                id: "markdown-preview-warmup",
                kind: .code,
                markdown: """
                ![Warmup](warmup.png)

                | A | B |
                | - | - |
                | 1 | 2 |

                ```swift
                print("warmup")
                ```
                """,
                preferredHeight: 120,
                imageMetas: [
                    MarkdownImageMeta(
                        source: "warmup.png",
                        resolvedSourceURL: "warmup.png",
                        width: 16,
                        height: 16
                    )
                ],
                codeLanguage: "swift"
            )

            return renderedSnapshot(for: warmupBlock) != nil
        }

        func renderedSnapshot(for block: MarkdownRenderBlock) -> (snapshot: MarkdownRenderedBlockSnapshot, metrics: MarkdownSnapshotRenderMetrics)? {
            let markdownStartedAt = ProcessInfo.processInfo.systemUptime
            guard var html = renderMarkdownHTML(block.markdown) else {
                return nil
            }
            let markdownFinishedAt = ProcessInfo.processInfo.systemUptime

            let imageStartedAt = markdownFinishedAt
            html = applyImageMetadata(to: html, metas: block.imageMetas)
            let imageFinishedAt = ProcessInfo.processInfo.systemUptime

            let tableStartedAt = imageFinishedAt
            html = stabilizeTables(in: html)
            let tableFinishedAt = ProcessInfo.processInfo.systemUptime

            let highlightStartedAt = tableFinishedAt
            html = highlightCodeBlocks(in: html, preferredLanguage: block.codeLanguage)
            let highlightFinishedAt = ProcessInfo.processInfo.systemUptime

            let snapshot = MarkdownRenderedBlockSnapshot(
                id: block.id,
                kind: block.kind,
                html: html,
                height: block.preferredHeight
            )
            let metrics = MarkdownSnapshotRenderMetrics(
                markdownRenderMs: Self.milliseconds(from: markdownStartedAt, to: markdownFinishedAt),
                imageMetadataMs: Self.milliseconds(from: imageStartedAt, to: imageFinishedAt),
                tableWrapMs: Self.milliseconds(from: tableStartedAt, to: tableFinishedAt),
                highlightMs: Self.milliseconds(from: highlightStartedAt, to: highlightFinishedAt)
            )
            return (snapshot, metrics)
        }

        private func renderMarkdownHTML(_ markdown: String) -> String? {
            markedContext?.setObject(markdown, forKeyedSubscript: "__qcMarkdownSource" as NSString)
            let script = """
            (function () {
                if (typeof marked === 'function') {
                    return marked(__qcMarkdownSource);
                }
                if (typeof marked !== 'undefined' && typeof marked.parse === 'function') {
                    return marked.parse(__qcMarkdownSource);
                }
                return '';
            })();
            """
            return markedContext?.evaluateScript(script)?.toString()
        }

        private func highlightCodeBlocks(in html: String, preferredLanguage: String?) -> String {
            let pattern = #"<pre><code(?: class="([^"]*)")?>([\s\S]*?)</code></pre>"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return html
            }

            let range = NSRange(html.startIndex..., in: html)
            var result = ""
            var cursor = html.startIndex

            for match in regex.matches(in: html, options: [], range: range) {
                guard let wholeRange = Range(match.range(at: 0), in: html),
                      let codeRange = Range(match.range(at: 2), in: html) else {
                    continue
                }

                result += html[cursor..<wholeRange.lowerBound]

                let className = Range(match.range(at: 1), in: html).map { String(html[$0]) } ?? ""
                let hintedLanguage = preferredLanguage ?? Self.extractLanguage(fromClassName: className)
                let rawCode = Self.decodeHTMLEntities(String(html[codeRange]))
                let highlighted = highlight(code: rawCode, language: hintedLanguage)
                let resolvedLanguage = highlighted.language ?? hintedLanguage
                let languageClass = resolvedLanguage.map { " language-\($0)" } ?? ""

                result += """
                <pre><code class="hljs\(languageClass)">\(highlighted.html)</code></pre>
                """
                cursor = wholeRange.upperBound
            }

            result += html[cursor...]
            return result
        }

        private func highlight(code: String, language: String?) -> (html: String, language: String?) {
            highlightContext?.setObject(code, forKeyedSubscript: "__qcCodeSource" as NSString)
            if let language {
                highlightContext?.setObject(language, forKeyedSubscript: "__qcLanguageHint" as NSString)
            } else {
                highlightContext?.setObject(JSValue(undefinedIn: highlightContext), forKeyedSubscript: "__qcLanguageHint" as NSString)
            }

            let script = """
            (function () {
                if (typeof hljs === 'undefined') {
                    return JSON.stringify({ html: __qcCodeSource, language: null });
                }

                try {
                    if (__qcLanguageHint && hljs.getLanguage(__qcLanguageHint)) {
                        var highlighted = hljs.highlight(__qcCodeSource, {
                            language: __qcLanguageHint,
                            ignoreIllegals: true
                        });
                        return JSON.stringify({
                            html: highlighted.value || '',
                            language: __qcLanguageHint
                        });
                    }

                    var autoHighlighted = hljs.highlightAuto(__qcCodeSource);
                    return JSON.stringify({
                        html: autoHighlighted.value || '',
                        language: autoHighlighted.language || null
                    });
                } catch (error) {
                    return JSON.stringify({ html: __qcCodeSource, language: __qcLanguageHint || null });
                }
            })();
            """

            guard let payload = highlightContext?.evaluateScript(script)?.toString(),
                  let data = payload.data(using: .utf8),
                  let result = try? JSONDecoder().decode(HighlightedCodePayload.self, from: data) else {
                return (Self.escapeHTML(code), language)
            }

            return (result.html.isEmpty ? Self.escapeHTML(code) : result.html, result.language)
        }

        private func applyImageMetadata(to html: String, metas: [MarkdownImageMeta]) -> String {
            guard !metas.isEmpty,
                  let regex = try? NSRegularExpression(pattern: #"<img\b[^>]*>"#, options: [.caseInsensitive]) else {
                return html
            }

            var result = html
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html)).reversed()

            for match in matches {
                guard let range = Range(match.range, in: result) else { continue }
                let tag = String(result[range])
                guard let source = Self.attributeValue(named: "src", in: tag),
                      let meta = metas.first(where: { $0.source == source }) else {
                    continue
                }

                let explicitWidth = Self.attributeValue(named: "width", in: tag)
                let explicitHeight = Self.attributeValue(named: "height", in: tag)
                let resolvedSource = meta.resolvedSourceURL ?? source
                let eagerLoading = Self.isLikelyLocalImageSource(source)

                var rebuilt = tag
                rebuilt = Self.upsertAttribute(named: "src", value: resolvedSource, in: rebuilt)
                rebuilt = Self.upsertAttribute(named: "loading", value: eagerLoading ? "eager" : "lazy", in: rebuilt)
                rebuilt = Self.upsertAttribute(named: "decoding", value: eagerLoading ? "sync" : "async", in: rebuilt)

                if let width = meta.width,
                   let height = meta.height,
                   explicitWidth == nil,
                   explicitHeight == nil {
                    rebuilt = Self.upsertAttribute(named: "width", value: String(width), in: rebuilt)
                    rebuilt = Self.upsertAttribute(named: "height", value: String(height), in: rebuilt)
                    rebuilt = Self.upsertStyle("aspect-ratio: \(width) / \(height);", into: rebuilt)
                } else if let explicitWidth, let explicitHeight {
                    rebuilt = Self.upsertStyle("aspect-ratio: \(explicitWidth) / \(explicitHeight);", into: rebuilt)
                }

                result.replaceSubrange(range, with: rebuilt)
            }

            return result
        }

        private func stabilizeTables(in html: String) -> String {
            guard html.contains("<table"),
                  !html.contains("qc-table-wrap") else {
                return html
            }
            return #"<div class="qc-table-wrap">\#(html)</div>"#
        }

        private static func extractLanguage(fromClassName className: String) -> String? {
            className
                .split(separator: " ")
                .compactMap { token in
                    let value = String(token)
                    if value.hasPrefix("language-") {
                        return String(value.dropFirst("language-".count))
                    }
                    return nil
                }
                .first
        }

        private static func isLikelyLocalImageSource(_ source: String) -> Bool {
            !source.isEmpty && source.range(of: #"^(?:https?:|data:|blob:)"#, options: [.regularExpression, .caseInsensitive]) == nil
        }

        private static func attributeValue(named name: String, in tag: String) -> String? {
            let pattern = #"\b\#(name)=["']([^"']*)["']"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..., in: tag)),
                  let range = Range(match.range(at: 1), in: tag) else {
                return nil
            }
            return String(tag[range])
        }

        private static func upsertAttribute(named name: String, value: String, in tag: String) -> String {
            let escapedValue = value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let replacement = #"\#(name)="\#(escapedValue)""#
            let pattern = #"\b\#(name)=["'][^"']*["']"#

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return tag
            }

            let range = NSRange(tag.startIndex..., in: tag)
            if regex.firstMatch(in: tag, options: [], range: range) != nil {
                return regex.stringByReplacingMatches(in: tag, options: [], range: range, withTemplate: replacement)
            }

            guard let closeIndex = tag.lastIndex(of: ">") else {
                return tag
            }
            return tag[..<closeIndex] + " " + replacement + tag[closeIndex...]
        }

        private static func upsertStyle(_ declaration: String, into tag: String) -> String {
            let trimmedDeclaration = declaration.trimmingCharacters(in: .whitespacesAndNewlines)
            let pattern = #"\bstyle=["']([^"']*)["']"#

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return tag
            }

            let range = NSRange(tag.startIndex..., in: tag)
            if let match = regex.firstMatch(in: tag, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: tag) {
                var style = String(tag[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !style.hasSuffix(";"), !style.isEmpty {
                    style += ";"
                }
                if !style.contains(trimmedDeclaration) {
                    style += style.isEmpty ? trimmedDeclaration : " \(trimmedDeclaration)"
                }
                let replacement = #"style="\#(style.replacingOccurrences(of: "\"", with: "&quot;"))""#
                return regex.stringByReplacingMatches(in: tag, options: [], range: range, withTemplate: replacement)
            }

            return upsertAttribute(named: "style", value: trimmedDeclaration, in: tag)
        }

        private static func decodeHTMLEntities(_ text: String) -> String {
            text
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
        }

        private static func escapeHTML(_ text: String) -> String {
            text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        }

        private static func loadHighlightScript() -> String? {
            guard let bundle = highlightrResourceBundle(),
                  let url = bundle.url(forResource: "highlight", withExtension: "min.js"),
                  let content = try? String(contentsOf: url) else {
                return nil
            }
            return content
        }

        private static func highlightrResourceBundle() -> Bundle? {
            if let bundleURL = Bundle.main.url(forResource: "Highlightr_Highlightr", withExtension: "bundle"),
               let bundle = Bundle(url: bundleURL) {
                return bundle
            }

            for bundle in Bundle.allBundles where bundle.bundleURL.lastPathComponent == "Highlightr_Highlightr.bundle" {
                return bundle
            }

            for bundle in Bundle.allFrameworks {
                if let nestedBundleURL = bundle.url(forResource: "Highlightr_Highlightr", withExtension: "bundle"),
                   let nestedBundle = Bundle(url: nestedBundleURL) {
                    return nestedBundle
                }
            }

            return nil
        }

        private static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
            Int(((end - start) * 1000).rounded())
        }
    }

    private struct HighlightedCodePayload: Decodable {
        let html: String
        let language: String?
    }

    private struct SnapshotRenderMetricAccumulator {
        var markdownRenderMs = 0
        var imageMetadataMs = 0
        var tableWrapMs = 0
        var highlightMs = 0
        var lockWaitMs = 0
        var firstRenderPrimeMs = 0
        var blockHeightsMs = 0
        var snapshotFinalizeMs = 0

        mutating func accumulate(_ metrics: MarkdownSnapshotRenderMetrics) {
            markdownRenderMs += metrics.markdownRenderMs
            imageMetadataMs += metrics.imageMetadataMs
            tableWrapMs += metrics.tableWrapMs
            highlightMs += metrics.highlightMs
            lockWaitMs += metrics.lockWaitMs
            firstRenderPrimeMs += metrics.firstRenderPrimeMs
            blockHeightsMs += metrics.blockHeightsMs
            snapshotFinalizeMs += metrics.snapshotFinalizeMs
        }

        func finalize() -> MarkdownSnapshotRenderMetrics {
            MarkdownSnapshotRenderMetrics(
                markdownRenderMs: markdownRenderMs,
                imageMetadataMs: imageMetadataMs,
                tableWrapMs: tableWrapMs,
                highlightMs: highlightMs,
                lockWaitMs: lockWaitMs,
                firstRenderPrimeMs: firstRenderPrimeMs,
                blockHeightsMs: blockHeightsMs,
                snapshotFinalizeMs: snapshotFinalizeMs
            )
        }
    }
}
