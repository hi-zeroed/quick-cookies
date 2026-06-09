import SwiftUI
import WebKit
import AppKit

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
            onBootstrapReady: onBootstrapReady
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

        private let controller = MarkdownPreviewController(policy: MarkdownPreviewPolicy())

        init(parent: MarkdownWebPreviewView) {
            self.parent = parent
        }

        func mountBorrowedWebViewIfNeeded(in container: NSView) {
            // Markdown borrows the shared WebKit runtime instead of owning a
            // dedicated long-lived WebView. Future WebView-backed file types
            // should prefer this borrow/reuse model first, and only introduce a
            // different shell template when their content model truly differs;
            // a different shell still does not justify a second always-on
            // runtime by default.
            //
            // If future work targets "app just launched, immediate first
            // preview" latency, keep this mount path simple and attack prewarm
            // timing upstream; this hot-path mount is already close to its
            // practical floor.
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
            updateIfNeeded()
        }

        func unmountBorrowedWebView() {
            controller.unbind()
            PreviewRuntimeRegistry.shared.webKitRuntime().detachCurrentWebView()
            mountedWebView = nil
            mountedContainer = nil
        }

        func updateIfNeeded() {
            guard let webView = mountedWebView else { return }

            controller.previewTimeline = parent.previewTimeline
            controller.onBootstrapReady = parent.onBootstrapReady

            let contentSig = "\(parent.filePath)|\(parent.markdownText.count)|\(parent.markdownText.hashValue)|\(parent.isDarkAppearance)|\(parent.preferFileBackedRendering)"
            let styleSig = "\(parent.bodyFontName)|\(parent.bodyFontSize)"

            if lastContentSignature != contentSig {
                lastContentSignature = contentSig
                lastStyleSignature = styleSig
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
