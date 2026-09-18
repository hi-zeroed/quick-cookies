import SwiftUI
import WebKit
import AppKit
import Combine

struct MarkdownPreviewDisplayPolicy {
    static func shouldMountPreview(
        renderType: FileRenderType,
        isLoading: Bool,
        hasLoadedInitialContent: Bool,
        keepsPreviousPreviewMounted: Bool = false
    ) -> Bool {
        guard renderType == .markdown else { return true }
        guard isLoading else { return true }
        return hasLoadedInitialContent || keepsPreviousPreviewMounted
    }
}

struct MarkdownView: View {
    let filePath: String
    let markdownText: String
    let previewTimeline: MarkdownPreviewTimelineTracker?
    let onBootstrapReady: (() -> Void)?
    var findBarState: FindBarState? = nil

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings = Settings.shared

    var body: some View {
        MarkdownWebPreviewView(
            filePath: filePath,
            markdownText: markdownText,
            isDarkAppearance: colorScheme == .dark,
            bodyFontName: settings.editorFont,
            bodyFontSize: settings.fontSize,
            preferFileBackedRendering: true,
            previewTimeline: previewTimeline,
            onBootstrapReady: onBootstrapReady,
            findBarState: findBarState
        )
        .background(Color.appBackground)
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}

private struct MarkdownWebPreviewView: NSViewRepresentable {
    let filePath: String
    let markdownText: String
    let isDarkAppearance: Bool
    let bodyFontName: String
    let bodyFontSize: CGFloat
    let preferFileBackedRendering: Bool
    let previewTimeline: MarkdownPreviewTimelineTracker?
    let onBootstrapReady: (() -> Void)?
    let findBarState: FindBarState?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        previewTimeline?.mark(.previewMountStarted)
        context.coordinator.mountBorrowedWebViewIfNeeded(in: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        previewTimeline?.mark(.previewMountStarted)
        context.coordinator.parent = self
        context.coordinator.mountBorrowedWebViewIfNeeded(in: container)
        context.coordinator.updateIfNeeded()
    }

    static func dismantleNSView(_ container: NSView, coordinator: Coordinator) {
        coordinator.unmountBorrowedWebView()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: MarkdownWebPreviewView
        var lastContentSignature: String?
        var lastStyleSignature: String?
        weak var mountedContainer: NSView?
        weak var mountedWebView: PreviewWebView?
        var findBarState: FindBarState?
        private var cancellables = Set<AnyCancellable>()

        private let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())

        init(parent: MarkdownWebPreviewView) {
            self.parent = parent
        }

        func mountBorrowedWebViewIfNeeded(in container: NSView) {
            mountedContainer = container
            guard mountedWebView == nil else {
                if mountedWebView?.superview !== container, let mountedWebView {
                    attach(webView: mountedWebView, to: container)
                }
                return
            }

            let runtime = PreviewRuntimeRegistry.shared.webKitRuntime()
            parent.previewTimeline?.mark(.runtimeCheckoutStarted)
            let webView = runtime.checkoutWebViewSync()
            parent.previewTimeline?.mark(.runtimeCheckoutCompleted)
            mountedWebView = webView
            attach(webView: webView, to: container)
            controller.bind(webView: webView)
            setupFindBarSubscription(findBarState: parent.findBarState, webView: webView)
            updateIfNeeded()
        }

        func unmountBorrowedWebView() {
            cancellables.removeAll()
            findBarState = nil
            lastSearchQuery = ""
            totalMatchCount = 0
            currentMatchIdx = 0
            controller.unbind()
            PreviewRuntimeRegistry.shared.webKitRuntime().detachCurrentWebView()
            mountedWebView = nil
            mountedContainer = nil
        }

        func updateIfNeeded() {
            guard let webView = mountedWebView else { return }

            setupFindBarSubscription(findBarState: parent.findBarState, webView: webView)
            controller.previewTimeline = parent.previewTimeline
            controller.onBootstrapReady = parent.onBootstrapReady

            let contentSig = "\(parent.filePath)|\(parent.markdownText.count)|\(parent.markdownText.hashValue)|\(parent.isDarkAppearance)|\(parent.preferFileBackedRendering)"
            let styleSig = "\(parent.bodyFontName)|\(parent.bodyFontSize)"

            if lastContentSignature != contentSig {
                lastContentSignature = contentSig
                lastStyleSignature = styleSig
                webView.evaluateJavaScript("window.scrollTo(0, 0);", completionHandler: nil)
                controller.loadContent(
                    filePath: parent.filePath,
                    markdownText: parent.markdownText,
                    isDarkAppearance: parent.isDarkAppearance,
                    bodyFontName: parent.bodyFontName,
                    bodyFontSize: parent.bodyFontSize,
                    preferFileBackedRendering: parent.preferFileBackedRendering
                )
            } else if lastStyleSignature != styleSig {
                lastStyleSignature = styleSig
                controller.applyStyle(
                    bodyFontName: parent.bodyFontName,
                    bodyFontSize: parent.bodyFontSize
                )
                webView.shouldShowContextMenu = { [weak self] in
                    self?.controller.hasTextSelection == true
                }
            }
        }

        private var lastSearchQuery: String = ""
        private var totalMatchCount: Int = 0
        private var currentMatchIdx: Int = 0

        func setupFindBarSubscription(findBarState: FindBarState?, webView: PreviewWebView) {
            if self.findBarState === findBarState && !cancellables.isEmpty {
                return
            }
            self.findBarState = findBarState
            cancellables.removeAll()
            guard let findBarState = findBarState else { return }

            findBarState.$query
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .removeDuplicates()
                .sink { [weak self, weak webView] query in
                    guard let self = self, let webView = webView else { return }
                    self.performMarkdownSearch(query: query, in: webView, backwards: false)
                }
                .store(in: &cancellables)

            findBarState.$isPresented
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak webView] isPresented in
                    guard let self = self, let webView = webView else { return }
                    if !isPresented {
                        self.clearMarkdownSearch(in: webView)
                    } else if !findBarState.query.isEmpty {
                        self.performMarkdownSearch(query: findBarState.query, in: webView, backwards: false)
                    }
                }
                .store(in: &cancellables)

            findBarState.findNextTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak webView] in
                    guard let self = self, let webView = webView, !findBarState.query.isEmpty else { return }
                    self.performMarkdownSearch(query: findBarState.query, in: webView, backwards: false)
                }
                .store(in: &cancellables)

            findBarState.findPreviousTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak webView] in
                    guard let self = self, let webView = webView, !findBarState.query.isEmpty else { return }
                    self.performMarkdownSearch(query: findBarState.query, in: webView, backwards: true)
                }
                .store(in: &cancellables)
        }

        private func performMarkdownSearch(query: String, in webView: PreviewWebView, backwards: Bool) {
            guard !query.isEmpty else {
                clearMarkdownSearch(in: webView)
                return
            }

            let isNewQuery = query != lastSearchQuery
            lastSearchQuery = query

            if #available(macOS 11.0, *) {
                let config = WKFindConfiguration()
                config.backwards = backwards
                config.caseSensitive = false
                config.wraps = true
                webView.find(query, configuration: config) { [weak self, weak webView] result in
                    guard let self = self, let webView = webView else { return }
                    guard result.matchFound else {
                        self.totalMatchCount = 0
                        self.currentMatchIdx = 0
                        DispatchQueue.main.async {
                            self.findBarState?.totalMatches = 0
                            self.findBarState?.currentMatchIndex = 0
                        }
                        return
                    }

                    if isNewQuery || self.totalMatchCount == 0 {
                        self.calculateMarkdownMatches(query: query, in: webView) { [weak self] total in
                            guard let self = self, self.lastSearchQuery == query else { return }
                            self.totalMatchCount = max(total, 1)
                            self.currentMatchIdx = 1
                            DispatchQueue.main.async {
                                self.findBarState?.totalMatches = self.totalMatchCount
                                self.findBarState?.currentMatchIndex = self.currentMatchIdx
                            }
                        }
                    } else {
                        let total = max(self.totalMatchCount, 1)
                        if backwards {
                            self.currentMatchIdx -= 1
                            if self.currentMatchIdx < 1 { self.currentMatchIdx = total }
                        } else {
                            self.currentMatchIdx += 1
                            if self.currentMatchIdx > total { self.currentMatchIdx = 1 }
                        }
                        DispatchQueue.main.async {
                            self.findBarState?.totalMatches = self.totalMatchCount
                            self.findBarState?.currentMatchIndex = self.currentMatchIdx
                        }
                    }
                }
            }
        }

        private func calculateMarkdownMatches(
            query: String,
            in webView: PreviewWebView,
            completion: @escaping (Int) -> Void
        ) {
            let escapedQuery = (try? String(data: JSONEncoder().encode(query), encoding: .utf8)) ?? "\"\""
            let script = """
            (function(q) {
                if (!q || !document.body) return 0;
                var lowerQ = q.toLowerCase();
                var qLen = lowerQ.length;
                if (qLen === 0) return 0;
                var walker = document.createTreeWalker(
                    document.body,
                    NodeFilter.SHOW_TEXT,
                    {
                        acceptNode: function(node) {
                            if (!node || !node.parentElement) return NodeFilter.FILTER_REJECT;
                            var tag = node.parentElement.tagName;
                            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT') {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    }
                );
                var count = 0;
                var node;
                while ((node = walker.nextNode())) {
                    var val = node.nodeValue;
                    if (!val) continue;
                    var lowerVal = val.toLowerCase();
                    var idx = 0;
                    while ((idx = lowerVal.indexOf(lowerQ, idx)) !== -1) {
                        count++;
                        idx += qLen;
                    }
                }
                return count;
            })(\(escapedQuery))
            """

            webView.evaluateJavaScript(script) { result, _ in
                let count = (result as? NSNumber)?.intValue ?? (result as? Int ?? 0)
                completion(count)
            }
        }

        private func clearMarkdownSearch(in webView: PreviewWebView) {
            lastSearchQuery = ""
            totalMatchCount = 0
            currentMatchIdx = 0
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.findBarState?.totalMatches != 0 {
                    self.findBarState?.totalMatches = 0
                }
                if self.findBarState?.currentMatchIndex != 0 {
                    self.findBarState?.currentMatchIndex = 0
                }
            }
            webView.evaluateJavaScript("window.getSelection()?.removeAllRanges()", completionHandler: nil)
        }

        private func attach(webView: PreviewWebView, to container: NSView) {
            if webView.superview !== container {
                webView.removeFromSuperview()
                webView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    webView.topAnchor.constraint(equalTo: container.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
            }
        }
    }
}
