import Foundation
import AppKit

@MainActor
final class PreviewRuntimeRegistry {
    static let shared = PreviewRuntimeRegistry()

    // Shared runtime policy:
    // - keep a single reusable WebKit runtime for in-window WebView previews
    // - prewarm that runtime once instead of prewarming one runtime per file type
    // - future WebView-backed formats may use different shell templates, but
    //   should still prefer this shared runtime over introducing a second
    //   always-on WKWebView stack
    //
    // Cold-start evolution note:
    // - the current product choice is to optimize the always-on menu bar flow
    //   first, so one immediate startup preview may still miss prewarm
    // - if first-open-after-launch becomes a priority later, evolve the timing
    //   and trigger policy here before adding more runtime instances or more
    //   Markdown-specific special cases
    private let sharedWebKitRuntime: WebKitRuntime
    private var scheduledWebKitPrewarmTask: Task<Void, Never>?

    private init() {
        self.sharedWebKitRuntime = WebKitRuntime()
    }

    init(webKitRuntime: WebKitRuntime) {
        self.sharedWebKitRuntime = webKitRuntime
    }

    func runtime(for kind: PreviewRuntimeKind) -> any PreviewRuntime {
        switch kind {
        case .web, .text, .document, .media:
            return sharedWebKitRuntime
        }
    }

    func webKitRuntime() -> WebKitRuntime {
        sharedWebKitRuntime
    }

    func scheduleWebKitPrewarmIfNeeded(after delay: TimeInterval = 0) {
        guard scheduledWebKitPrewarmTask == nil else { return }

        scheduledWebKitPrewarmTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer { self.scheduledWebKitPrewarmTask = nil }

            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }
            try? await self.sharedWebKitRuntime.prewarmIfNeeded()
        }
    }

    func scheduleMarkdownPreviewShellWarmIfNeeded(
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        after delay: TimeInterval = 0
    ) {
        // One scheduled prewarm task is enough for the current single-window
        // preview model. If future profiling says startup-adjacent first opens
        // matter more, prefer improving when this task is scheduled or what
        // signal triggers it instead of introducing parallel always-on shells.
        guard scheduledWebKitPrewarmTask == nil else { return }

        scheduledWebKitPrewarmTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer { self.scheduledWebKitPrewarmTask = nil }

            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            do {
                try await MarkdownPreviewShellWarmer.warmIfNeeded(
                    runtime: self.sharedWebKitRuntime,
                    isDarkAppearance: isDarkAppearance,
                    bodyFontName: bodyFontName,
                    bodyFontSize: bodyFontSize
                )
            } catch {
                try? await self.sharedWebKitRuntime.prewarmIfNeeded()
            }
        }
    }
}
