import Foundation
import WebKit
import AppKit

struct PreviewRuntimeLoadHints: Equatable {
    let reused: Bool
    let prewarmed: Bool
}

@MainActor
final class WebKitRuntime: PreviewRuntime {
    private let blankHTML = "<html><head><meta charset='utf-8'></head><body></body></html>"
    let kind: PreviewRuntimeKind = .web

    // One shared WKWebView instance backs WebView-based in-window previews.
    //
    // Important design rule:
    // - "needs a different shell" does not automatically mean "needs another
    //   runtime" or "needs another prewarmed WebView"
    // - prefer reusing this runtime and swapping shell/template content in place
    // - only introduce another runtime if a future file type proves it cannot
    //   safely coexist with the shared lifecycle, process pool, and reset model
    // - if first-open-after-launch is still too slow later, treat that as a
    //   prewarm timing / navigation activation problem first, not as a reason
    //   to fork more long-lived WKWebView instances
    private lazy var webView: PreviewWebView = {
        let configuration = WKWebViewConfiguration()
        // Keep shared WebView policy in one place so every WebView-backed
        // preview shell borrows the same runtime contract.
        PreviewWebViewConfiguration.prepare(configuration)

        let view = PreviewWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.allowsMagnification = true
        return view
    }()

    private var hasCheckedOut = false
    private var hasPrewarmed = false
    private var hasActivatedRuntime = false
    private var prewarmDelegate: PrewarmNavigationDelegate?

    private(set) var debugCurrentLoadID: UUID?
    private(set) var debugCurrentFilePath: String?
    private(set) var debugPrewarmCount = 0
    private(set) var debugPrepareForFreshContentCount = 0
    private(set) var lastCheckoutReusedExistingView = false
    private(set) var lastCheckoutUsedPrewarmedRuntime = false
    private var currentCheckoutUsedPrewarmedRuntime = false
    private var currentCheckoutLoadCount = 0

    func checkoutWebViewSync() -> PreviewWebView {
        let hadWarmRuntime = hasActivatedRuntime || hasPrewarmed
        let hitPrewarmedRuntime = hasPrewarmed && !hasCheckedOut
        _ = webView
        lastCheckoutReusedExistingView = hasCheckedOut || hadWarmRuntime
        lastCheckoutUsedPrewarmedRuntime = hitPrewarmedRuntime
        if !hasCheckedOut {
            currentCheckoutLoadCount = 0
            currentCheckoutUsedPrewarmedRuntime = hitPrewarmedRuntime
        }
        hasActivatedRuntime = true
        hasCheckedOut = true
        return webView
    }

    func checkoutWebView() async throws -> PreviewWebView {
        checkoutWebViewSync()
    }

    func consumeLoadRuntimeHints() -> PreviewRuntimeLoadHints {
        let hints = PreviewRuntimeLoadHints(
            reused: currentCheckoutLoadCount > 0 || lastCheckoutReusedExistingView,
            prewarmed: currentCheckoutLoadCount == 0 && currentCheckoutUsedPrewarmedRuntime
        )
        currentCheckoutLoadCount += 1
        return hints
    }

    func installSessionDebugState(loadID: UUID, filePath: String) {
        debugCurrentLoadID = loadID
        debugCurrentFilePath = filePath
    }

    func clearSessionDebugState() {
        debugCurrentLoadID = nil
        debugCurrentFilePath = nil
    }

    func prewarmIfNeeded() async throws {
        try await prepareInitialDocumentIfNeeded(
            html: blankHTML,
            marksReusableShellAsLoaded: false,
            reusableShellAppearanceIsDark: nil
        )
    }

    func prepareReusableShellIfNeeded(
        html: String,
        reusableShellAppearanceIsDark: Bool
    ) async throws {
        try await prepareInitialDocumentIfNeeded(
            html: html,
            marksReusableShellAsLoaded: true,
            reusableShellAppearanceIsDark: reusableShellAppearanceIsDark
        )
    }

    private func prepareInitialDocumentIfNeeded(
        html: String,
        marksReusableShellAsLoaded: Bool,
        reusableShellAppearanceIsDark: Bool?
    ) async throws {
        // This is the key cold-path activation point today. If we revisit
        // startup-first-open latency, profiling should start here and around
        // the caller scheduling policy before changing Markdown rendering
        // behavior or splitting the shared runtime model.
        guard !hasPrewarmed, !hasActivatedRuntime, !hasCheckedOut else { return }
        _ = webView
        webView.hasLoadedPreviewShell = false
        webView.loadedPreviewShellAppearanceIsDark = nil

        let delegate = PrewarmNavigationDelegate()
        prewarmDelegate = delegate
        webView.navigationDelegate = delegate

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delegate.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }

        debugPrewarmCount += 1
        hasPrewarmed = true
        hasActivatedRuntime = true
        webView.hasLoadedPreviewShell = marksReusableShellAsLoaded
        webView.loadedPreviewShellAppearanceIsDark = reusableShellAppearanceIsDark
        webView.navigationDelegate = nil
        prewarmDelegate = nil
    }

    func prepareForFreshContent() {
        // Reset the shared WebView to a blank document when it is detached so
        // the next checkout starts from a stable base state.
        debugPrepareForFreshContentCount += 1
        webView.hasLoadedPreviewShell = false
        webView.loadedPreviewShellAppearanceIsDark = nil
        webView.stopLoading()
        webView.loadHTMLString(blankHTML, baseURL: nil)
    }

    func detachCurrentWebView(resetContent: Bool = false) {
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        webView.shouldShowContextMenu = { false }
        clearSessionDebugState()
        hasCheckedOut = false
        currentCheckoutLoadCount = 0
        currentCheckoutUsedPrewarmedRuntime = false

        if resetContent {
            prepareForFreshContent()
        }
    }

    func detach() {
        detachCurrentWebView()
    }

    func reset() {
        prepareForFreshContent()
    }
}

private final class PrewarmNavigationDelegate: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Error>?

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

final class PreviewWebView: WKWebView {
    // Shared in-window WebView shell for any preview type that can live within
    // the same reusable lifecycle. New WebView-backed formats should prefer
    // reusing this shell and swapping template/bootstrap content before
    // introducing another long-lived WKWebView/runtime pair.
    var hasLoadedPreviewShell = false
    var loadedPreviewShellAppearanceIsDark: Bool?
    var shouldShowContextMenu: () -> Bool = { false }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard shouldShowContextMenu() else {
            return nil
        }
        return super.menu(for: event)
    }

    @discardableResult
    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        super.loadHTMLString(string, baseURL: baseURL)
    }

    @MainActor
    override func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)?
    ) {
        super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
    }
}
