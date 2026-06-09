import Foundation
import WebKit
import AppKit

/// A narrow WebView-facing protocol used by the Markdown preview controller.
///
/// This is not a generic preview abstraction and it does not imply a second
/// preview runtime. It exists so the controller can:
/// - talk to the shared preview WebView shell without hard-coding `WKWebView`
/// - use a spy in tests to verify shell reuse vs. full HTML reloads
///
/// Architectural boundary:
/// - the app still owns one shared WebKit runtime
/// - Markdown currently owns one reusable document shell inside that runtime
/// - adding a new WebView-backed file type should not create another always-on
///   runtime just because it needs different HTML/CSS/JS bootstrapping
/// - any background preparation should stay in pure Swift unless a future
///   requirement proves the shared in-window runtime cannot satisfy it
@MainActor
protocol PreviewWebViewing: AnyObject {
    var configuration: WKWebViewConfiguration { get }
    var navigationDelegate: WKNavigationDelegate? { get set }
    var shouldShowContextMenu: () -> Bool { get set }
    var hasLoadedPreviewShell: Bool { get set }
    var loadedPreviewShellAppearanceIsDark: Bool? { get set }

    @discardableResult
    func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation?
    func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: ((Any?, (any Error)?) -> Void)?
    )
}

typealias MarkdownPreviewSessionLoader = (
    _ filePath: String,
    _ fallbackMarkdown: String,
    _ preferFileBackedRendering: Bool,
    _ baseDirectoryURL: URL?,
    _ isDarkAppearance: Bool,
    _ bodyFontName: String,
    _ bodyFontSize: CGFloat,
    _ policy: MarkdownPreviewPolicy
) async throws -> MarkdownPreviewSession

@MainActor
final class MarkdownPreviewController: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    static let selectionStateMessageName = "markdownSelectionStateChanged"
    static let continuationRequestMessageName = "markdownContinuationRequested"
    static let bootstrapReadyMessageName = "markdownBootstrapReady"
    static let shellReusePhaseMessageName = "markdownShellReusePhaseChanged"

    private let policy: MarkdownPreviewPolicy
    private let sessionLoader: MarkdownPreviewSessionLoader

    weak var webView: (any PreviewWebViewing)?

    var onBootstrapReady: (() -> Void)?
    var previewTimeline: MarkdownPreviewTimelineRecording?
    var hasTextSelection = false

    private var currentLoadID = UUID()
    private var isShellReady = false
    private var pendingContinuationContent: MarkdownPreviewPreparedContent?
    private var pendingStyleScript: String?
    private var queuedContinuationBatches: [MarkdownPreviewBatch] = []
    private var continuationBatchInFlight = false
    private var hasReportedBootstrapReady = false
    private var pendingShellAppearanceIsDark: Bool?

    init(
        policy: MarkdownPreviewPolicy,
        sessionLoader: @escaping MarkdownPreviewSessionLoader = MarkdownPreviewSessionBuilder.prepare
    ) {
        self.policy = policy
        self.sessionLoader = sessionLoader
    }

    func bind(webView: PreviewWebView) {
        bindForTesting(webViewProxy: webView)
    }

    func bindForTesting(webViewProxy: any PreviewWebViewing) {
        self.webView = webViewProxy
        isShellReady = webViewProxy.hasLoadedPreviewShell
        webViewProxy.navigationDelegate = self
        webViewProxy.shouldShowContextMenu = { [weak self] in
            self?.hasTextSelection == true
        }

        let controller = webViewProxy.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Self.selectionStateMessageName)
        controller.removeScriptMessageHandler(forName: Self.continuationRequestMessageName)
        controller.removeScriptMessageHandler(forName: Self.bootstrapReadyMessageName)
        controller.removeScriptMessageHandler(forName: Self.shellReusePhaseMessageName)
        controller.add(self, name: Self.selectionStateMessageName)
        controller.add(self, name: Self.continuationRequestMessageName)
        controller.add(self, name: Self.bootstrapReadyMessageName)
        controller.add(self, name: Self.shellReusePhaseMessageName)
    }

    func debugMarkShellLoaded(isDarkAppearance: Bool = false) {
        webView?.hasLoadedPreviewShell = true
        webView?.loadedPreviewShellAppearanceIsDark = isDarkAppearance
        isShellReady = true
    }

    func unbind() {
        guard let webView else { return }
        webView.navigationDelegate = nil
        webView.shouldShowContextMenu = { false }
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Self.selectionStateMessageName)
        controller.removeScriptMessageHandler(forName: Self.continuationRequestMessageName)
        controller.removeScriptMessageHandler(forName: Self.bootstrapReadyMessageName)
        controller.removeScriptMessageHandler(forName: Self.shellReusePhaseMessageName)
        self.webView = nil
        isShellReady = false
        pendingShellAppearanceIsDark = nil
    }

    func loadContent(
        filePath: String,
        markdownText: String,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        preferFileBackedRendering: Bool
    ) {
        guard let webView else { return }
        let canReuseLoadedShell = isShellReady
            && webView.hasLoadedPreviewShell
            && webView.loadedPreviewShellAppearanceIsDark == isDarkAppearance

        currentLoadID = UUID()
        isShellReady = canReuseLoadedShell
        pendingShellAppearanceIsDark = isDarkAppearance
        pendingContinuationContent = nil
        hasReportedBootstrapReady = false
        hasTextSelection = false
        pendingStyleScript = MarkdownPreviewBridge.javaScriptForApplyStyle(
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize
        )
        queuedContinuationBatches = []
        continuationBatchInFlight = false

        let baseDirectoryURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let loadID = currentLoadID
        let runtime = PreviewRuntimeRegistry.shared.webKitRuntime()
        runtime.installSessionDebugState(loadID: loadID, filePath: filePath)
        let runtimeHints = runtime.consumeLoadRuntimeHints()
        previewTimeline?.annotateRuntimeHints(
            reused: runtimeHints.reused,
            prewarmed: runtimeHints.prewarmed
        )
        previewTimeline?.mark(.sessionLoadRequested)

        Task {
            self.previewTimeline?.mark(.sessionPreparationStarted)
            let session: MarkdownPreviewSession
            do {
                session = try await sessionLoader(
                    filePath,
                    markdownText,
                    preferFileBackedRendering,
                    baseDirectoryURL,
                    isDarkAppearance,
                    bodyFontName,
                    bodyFontSize,
                    policy
                )
            } catch {
                guard shouldAcceptCallback(for: loadID) else { return }

                let fallbackContent = MarkdownPreviewBridge.prepareContent(
                    filePath: filePath,
                    fallbackMarkdown: markdownText,
                    preferFileBackedRendering: preferFileBackedRendering,
                    baseDirectoryURL: baseDirectoryURL,
                    policy: policy,
                    droppingLeadingBlocks: 0,
                    knownFileSize: nil,
                    allowsEmptyPlaceholder: true
                )

                let bootstrapContent = bootstrapContent(from: fallbackContent)
                let bootstrapScript = bootstrapScript(
                    preparedContent: bootstrapContent,
                    snapshot: nil
                )
                previewTimeline?.mark(.bootstrapScriptPrepared)

                pendingContinuationContent = continuationContent(afterBootstrapping: fallbackContent)
                presentBootstrap(
                    initialContentHTML: "",
                    bootstrapScript: bootstrapScript,
                    baseDirectoryURL: baseDirectoryURL,
                    isDarkAppearance: isDarkAppearance,
                    bodyFontName: bodyFontName,
                    bodyFontSize: bodyFontSize,
                    using: webView,
                    loadID: loadID,
                    canReuseLoadedShell: canReuseLoadedShell
                )
                return
            }

            guard shouldAcceptCallback(for: loadID) else { return }

            previewTimeline?.mark(.sessionPrepared)
            previewTimeline?.annotatePrepareMetrics(session.prepareMetrics)
            pendingContinuationContent = session.continuationContent
            let bootstrapScript = bootstrapScript(
                preparedContent: session.bootstrapContent,
                snapshot: session.bootstrapSnapshot
            )
            previewTimeline?.mark(.bootstrapScriptPrepared)
            presentBootstrap(
                initialContentHTML: session.bootstrapSnapshot.map(MarkdownPreviewBridge.initialContentHTML(for:)) ?? "",
                bootstrapScript: bootstrapScript,
                baseDirectoryURL: baseDirectoryURL,
                isDarkAppearance: isDarkAppearance,
                bodyFontName: bodyFontName,
                bodyFontSize: bodyFontSize,
                using: webView,
                loadID: loadID,
                canReuseLoadedShell: canReuseLoadedShell
            )
        }
    }

    func applyStyle(bodyFontName: String, bodyFontSize: CGFloat) {
        let styleScript = MarkdownPreviewBridge.javaScriptForApplyStyle(
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize
        )
        pendingStyleScript = styleScript

        guard isShellReady, let webView else { return }
        webView.evaluateJavaScript(styleScript, completionHandler: nil)
    }

    func debugSetCurrentLoadID(_ loadID: UUID) {
        currentLoadID = loadID
    }

    func debugPrepareForNewLoad() {
        currentLoadID = UUID()
        hasReportedBootstrapReady = false
    }

    func shouldAcceptCallback(for loadID: UUID) -> Bool {
        currentLoadID == loadID
    }

    func markBootstrapReadyIfNeeded() -> Bool {
        guard !hasReportedBootstrapReady else { return false }
        hasReportedBootstrapReady = true
        return true
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case Self.selectionStateMessageName:
            if let hasSelection = message.body as? Bool {
                hasTextSelection = hasSelection
            } else if let hasSelectionNumber = message.body as? NSNumber {
                hasTextSelection = hasSelectionNumber.boolValue
            }
        case Self.continuationRequestMessageName:
            drainNextContinuationBatchIfNeeded()
        case Self.shellReusePhaseMessageName:
            handleShellReusePhaseMessage(message.body)
        case Self.bootstrapReadyMessageName:
            guard markBootstrapReadyIfNeeded() else { return }
            previewTimeline?.mark(.bootstrapReady)
            previewTimeline?.logSummaryIfComplete()
            onBootstrapReady?()
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isShellReady = true
        self.webView?.hasLoadedPreviewShell = true
        self.webView?.loadedPreviewShellAppearanceIsDark = pendingShellAppearanceIsDark
        previewTimeline?.mark(.webViewDidFinish)
        previewTimeline?.logSummaryIfComplete()

        if let pendingStyleScript {
            webView.evaluateJavaScript(pendingStyleScript, completionHandler: nil)
        }

        if let continuation = pendingContinuationContent {
            pendingContinuationContent = nil
            if let boundWebView = self.webView {
                enqueuePreparedContent(continuation, for: boundWebView)
            } else if let previewWebView = webView as? PreviewWebView {
                enqueuePreparedContent(continuation, for: previewWebView)
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        previewTimeline?.mark(.navigationStarted)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        previewTimeline?.mark(.navigationCommitted)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func enqueuePreparedContent(
        _ preparedContent: MarkdownPreviewPreparedContent,
        for webView: any PreviewWebViewing
    ) {
        guard !preparedContent.batches.isEmpty else {
            webView.evaluateJavaScript(
                "window.__quickCookiesMarkdown.markContinuationComplete();",
                completionHandler: nil
            )
            return
        }

        if preparedContent.shouldVirtualize {
            webView.evaluateJavaScript(
                MarkdownPreviewBridge.javaScriptForConfigure(
                    shouldVirtualize: true,
                    overscanScreens: preparedContent.overscanScreens
                ),
                completionHandler: nil
            )
        }

        queuedContinuationBatches = preparedContent.batches
        webView.evaluateJavaScript(
            "window.__quickCookiesMarkdown.requestMoreIfNeeded();",
            completionHandler: nil
        )
    }

    private func drainNextContinuationBatchIfNeeded() {
        guard isShellReady,
              !continuationBatchInFlight,
              !queuedContinuationBatches.isEmpty,
              let webView else {
            return
        }

        let batch = queuedContinuationBatches.removeFirst()
        guard let script = MarkdownPreviewBridge.javaScriptForAppend(batch: batch) else {
            drainNextContinuationBatchIfNeeded()
            return
        }

        let dispatchID = currentLoadID
        continuationBatchInFlight = true
        webView.evaluateJavaScript(script) { [weak self] _, _ in
            guard let self else { return }
            guard self.shouldAcceptCallback(for: dispatchID) else { return }

            self.continuationBatchInFlight = false
            if self.queuedContinuationBatches.isEmpty {
                self.webView?.evaluateJavaScript(
                    "window.__quickCookiesMarkdown.markContinuationComplete();",
                    completionHandler: nil
                )
            }
        }
    }

    private func bootstrapContent(from preparedContent: MarkdownPreviewPreparedContent) -> MarkdownPreviewPreparedContent {
        MarkdownPreviewPreparedContent(
            batches: Array(preparedContent.batches.prefix(1)),
            shouldVirtualize: preparedContent.shouldVirtualize,
            overscanScreens: preparedContent.overscanScreens
        )
    }

    private func continuationContent(afterBootstrapping preparedContent: MarkdownPreviewPreparedContent) -> MarkdownPreviewPreparedContent? {
        let remaining = Array(preparedContent.batches.dropFirst())
        guard !remaining.isEmpty else { return nil }

        return MarkdownPreviewPreparedContent(
            batches: remaining,
            shouldVirtualize: preparedContent.shouldVirtualize,
            overscanScreens: preparedContent.overscanScreens
        )
    }

    private func presentBootstrap(
        initialContentHTML: String,
        bootstrapScript: String?,
        baseDirectoryURL: URL?,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        using webView: any PreviewWebViewing,
        loadID: UUID,
        canReuseLoadedShell: Bool
    ) {
        if canReuseLoadedShell {
            // Reuse the existing preview shell in-place. This preserves the
            // single shared WebKit runtime and avoids paying another full page
            // navigation cost for every Markdown open.
            let script = shellReuseBootstrapScript(
                from: bootstrapScript,
                baseDirectoryURL: baseDirectoryURL,
                loadID: loadID
            )
            previewTimeline?.mark(.shellLoadIssued)
            webView.evaluateJavaScript(script) { [weak self] _, _ in
                guard let self else { return }
                guard self.shouldAcceptCallback(for: loadID) else { return }
                self.previewTimeline?.mark(.webViewDidFinish)
                self.previewTimeline?.logSummaryIfComplete()

                if let continuation = self.pendingContinuationContent {
                    self.pendingContinuationContent = nil
                    self.enqueuePreparedContent(continuation, for: webView)
                } else {
                    webView.evaluateJavaScript(
                        "window.__quickCookiesMarkdown.markContinuationComplete();",
                        completionHandler: nil
                    )
                }
            }
            return
        }

        let shellHTML = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: baseDirectoryURL,
            isDarkAppearance: isDarkAppearance,
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize,
            initialContentHTML: initialContentHTML,
            bootstrapJavaScript: bootstrapScript
        )

        previewTimeline?.mark(.shellLoadIssued)
        webView.loadHTMLString(shellHTML, baseURL: baseDirectoryURL)
    }

    private func shellReuseBootstrapScript(
        from bootstrapScript: String?,
        baseDirectoryURL: URL?,
        loadID: UUID
    ) -> String {
        // Reused shell contract:
        // 1. reset shell state from the previous document
        // 2. update <base href> so relative images/links resolve for the new file
        // 3. bootstrap the first visible content batch
        // 4. re-apply typography/theme state
        let configureAndBootstrap = bootstrapScript ?? ""
        let resetScript = MarkdownPreviewBridge.javaScriptForReset()
        let updateBaseScript = MarkdownPreviewBridge.javaScriptForUpdateBaseURL(baseDirectoryURL)
        let styleScript = pendingStyleScript ?? ""
        let loadIDJS = MarkdownPreviewBridge.javaScriptSingleQuotedString(loadID.uuidString)

        return """
        (function() {
            var markShellReusePhase = function(phase) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(Self.shellReusePhaseMessageName)) {
                    window.webkit.messageHandlers.\(Self.shellReusePhaseMessageName).postMessage({
                        loadID: '\(loadIDJS)',
                        phase: phase
                    });
                }
            };
            var relayBootstrapPhase = function(phase) {
                switch (phase) {
                case 'bootstrap-render':
                    markShellReusePhase('bootstrap-render');
                    break;
                case 'bootstrap-attach':
                    markShellReusePhase('bootstrap-attach');
                    break;
                case 'bootstrap-measure':
                    markShellReusePhase('bootstrap-measure');
                    break;
                case 'bootstrap-post':
                    markShellReusePhase('bootstrap-post');
                    break;
                default:
                    markShellReusePhase(phase);
                    break;
                }
            };
            markShellReusePhase('reset-start');
            \(resetScript)
            markShellReusePhase('reset-clear');
            markShellReusePhase('reset');
            \(updateBaseScript)
            markShellReusePhase('base');
            window.__quickCookiesMarkdown.setShellReusePhaseHook(relayBootstrapPhase);
            \(configureAndBootstrap)
            window.__quickCookiesMarkdown.setShellReusePhaseHook(null);
            markShellReusePhase('bootstrap');
            \(styleScript)
            markShellReusePhase('style');
        })();
        """
    }

    private func bootstrapScript(
        preparedContent: MarkdownPreviewPreparedContent,
        snapshot: MarkdownRenderSnapshot?
    ) -> String? {
        if let snapshot,
           let snapshotScript = MarkdownPreviewBridge.javaScriptForBootstrapSnapshot(snapshot) {
            let configureScript = MarkdownPreviewBridge.javaScriptForConfigure(
                shouldVirtualize: preparedContent.shouldVirtualize,
                overscanScreens: preparedContent.overscanScreens
            )
            return """
            \(configureScript)
            \(snapshotScript)
            """
        }

        return MarkdownPreviewBridge.javaScriptForBootstrap(preparedContent: preparedContent)
            ?? MarkdownPreviewBridge.javaScriptForConfigure(
                shouldVirtualize: preparedContent.shouldVirtualize,
                overscanScreens: preparedContent.overscanScreens
            )
    }

    private func handleShellReusePhaseMessage(_ body: Any) {
        guard let payload = body as? [String: Any],
              let phase = payload["phase"] as? String,
              let loadIDValue = payload["loadID"] as? String,
              let loadID = UUID(uuidString: loadIDValue),
              shouldAcceptCallback(for: loadID),
              let stage = shellReuseStage(for: phase) else {
            return
        }

        previewTimeline?.mark(stage)
    }

    private func shellReuseStage(for phase: String) -> MarkdownPreviewTimeline.Stage? {
        switch phase {
        case "reset-start":
            return .shellReuseResetStarted
        case "reset-clear":
            return .shellReuseResetCleared
        case "reset":
            return .shellReuseResetApplied
        case "base":
            return .shellReuseBaseUpdated
        case "bootstrap-render":
            return .shellReuseBootstrapRendered
        case "bootstrap-attach":
            return .shellReuseBootstrapAttached
        case "bootstrap-measure":
            return .shellReuseBootstrapMeasured
        case "bootstrap-post", "bootstrap":
            return .shellReuseBootstrapApplied
        case "style":
            return .shellReuseStyleApplied
        default:
            return nil
        }
    }
}

extension PreviewWebView: PreviewWebViewing {}
