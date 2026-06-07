import Foundation
import AppKit

enum MarkdownHTMLShell {
    static func renderHTML(
        baseDirectoryURL: URL?,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        initialContentHTML: String = "",
        bootstrapJavaScript: String? = nil
    ) -> String {
        renderDocument(
            baseDirectoryURL: baseDirectoryURL,
            isDarkAppearance: isDarkAppearance,
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize,
            initialContentHTML: initialContentHTML,
            runtimeScript: MarkdownRendererRuntime.visibleRuntimeScript(),
            trailingScript: bootstrapJavaScript
        )
    }

    static func renderPrerenderHTML(
        baseDirectoryURL: URL?,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat
    ) -> String {
        renderDocument(
            baseDirectoryURL: baseDirectoryURL,
            isDarkAppearance: isDarkAppearance,
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize,
            initialContentHTML: "",
            runtimeScript: MarkdownRendererRuntime.prerenderRuntimeScript(),
            trailingScript: nil
        )
    }

    private static func renderDocument(
        baseDirectoryURL: URL?,
        isDarkAppearance: Bool,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        initialContentHTML: String,
        runtimeScript: String,
        trailingScript: String?
    ) -> String {
        let baseTag: String
        if let baseDirectoryURL {
            baseTag = #"<base href="\#(baseDirectoryURL.absoluteString)">"#
        } else {
            baseTag = ""
        }

        let textColor = isDarkAppearance ? "#e1e1e6" : "#1f2328"
        let mutedTextColor = isDarkAppearance ? "#9aa4b2" : "#59636e"
        let borderColor = isDarkAppearance ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"
        let quoteBorder = isDarkAppearance ? "#3d444d" : "#d0d7de"
        let tableBorderColor = isDarkAppearance ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.12)"
        let tableStripe = isDarkAppearance ? "rgba(255,255,255,0.045)" : "rgba(0,0,0,0.045)"
        let linkColor = isDarkAppearance ? "#58a6ff" : "#0969da"
        let bodyFontFamily = MarkdownPreviewBridge.cssFontFamily(
            for: bodyFontName,
            fallbacks: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
        )
        let codeFontFamily = MarkdownPreviewBridge.cssFontFamily(
            for: bodyFontName,
            fallbacks: "\"SFMono-Regular\", Menlo, Consolas, monospace"
        )
        let syntaxTheme = loadHighlightrThemeCSS(isDarkAppearance: isDarkAppearance) ?? ""
        let highlightScript = loadHighlightrScript() ?? ""
        let safeHighlightScript = highlightScript.replacingOccurrences(
            of: "</script>",
            with: "<\\/script>",
            options: .caseInsensitive
        )
        let safeRuntimeScript = runtimeScript.replacingOccurrences(
            of: "</script>",
            with: "<\\/script>",
            options: .caseInsensitive
        )
        let safeTrailingScript = trailingScript?
            .replacingOccurrences(of: "</script>", with: "<\\/script>", options: .caseInsensitive) ?? ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \(baseTag)
        <style>
        \(bundledFontFaceCSS())
        :root {
            --body-font-family: \(bodyFontFamily);
            --code-font-family: \(codeFontFamily);
            --body-font-size: \(max(bodyFontSize, 12))px;
            --border-color: \(borderColor);
            --table-border-color: \(tableBorderColor);
            --table-stripe: \(tableStripe);
        }
        html, body {
            margin: 0;
            padding: 0;
            background: transparent;
            color: \(textColor);
        }
        body {
            font-family: var(--body-font-family);
            font-size: var(--body-font-size);
            line-height: 1.65;
            box-sizing: border-box;
            word-break: break-word;
            overflow-wrap: anywhere;
        }
        #content {
            min-height: calc(100vh - 40px);
            padding: 20px;
            box-sizing: border-box;
        }
        .markdown-body {
            color: \(textColor);
            background: transparent;
            font-family: var(--body-font-family);
            font-size: var(--body-font-size);
        }
        .markdown-block-shell {
            width: 100%;
            contain: layout style;
            min-height: 0;
        }
        .markdown-block-shell[data-virtualized='true'] {
            overflow: hidden;
        }
        .markdown-block-body {
            width: 100%;
        }
        .markdown-block-body > :first-child {
            margin-top: 0 !important;
        }
        .markdown-block-body > :last-child {
            margin-bottom: 16px;
        }
        .markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6 {
            margin-top: 1.5em;
            margin-bottom: 0.7em;
            font-weight: 650;
            line-height: 1.25;
        }
        .markdown-body h1, .markdown-body h2 {
            padding-bottom: 0.3em;
            border-bottom: 1px solid var(--border-color);
        }
        .markdown-body p,
        .markdown-body ul,
        .markdown-body ol,
        .markdown-body blockquote,
        .markdown-body pre,
        .markdown-body table {
            margin-top: 0;
            margin-bottom: 16px;
        }
        .markdown-body a {
            color: \(linkColor);
            text-decoration: none;
        }
        .markdown-body a:hover {
            text-decoration: underline;
        }
        .markdown-body code,
        .markdown-body pre,
        .markdown-body pre code {
            font-family: var(--code-font-family);
        }
        .markdown-body code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 0.85em;
            border-radius: 6px;
            background: transparent;
        }
        .markdown-body pre {
            padding: 16px;
            overflow-x: auto;
            border-radius: 6px;
            background: transparent;
            border: 1px solid var(--border-color);
        }
        .hljs {
            background: transparent !important;
            padding: 0 !important;
        }
        .markdown-body pre code {
            padding: 0;
            background: transparent;
            font-size: 0.85em;
            line-height: 1.425;
        }
        .markdown-body blockquote {
            padding: 0 1em;
            color: \(mutedTextColor);
            border-left: 0.25em solid \(quoteBorder);
        }
        .qc-table-wrap {
            width: 100%;
            overflow: hidden;
        }
        .markdown-body table {
            width: 100%;
            max-width: 100%;
            border-spacing: 0;
            border-collapse: separate;
            table-layout: fixed;
            border-radius: 8px;
            border: 1px solid var(--table-border-color);
            overflow: hidden;
            margin-top: 0;
            margin-bottom: 16px;
        }
        .markdown-body th,
        .markdown-body td {
            padding: 8px 13px;
            border-bottom: 1px solid var(--table-border-color);
            border-right: 1px solid var(--table-border-color);
            white-space: normal;
            word-break: break-word;
            overflow-wrap: anywhere;
            vertical-align: top;
        }
        .markdown-body th:last-child,
        .markdown-body td:last-child {
            border-right: 0;
        }
        .markdown-body tr:last-child td {
            border-bottom: 0;
        }
        .markdown-body tr:nth-child(2n) {
            background: var(--table-stripe);
        }
        .markdown-body img {
            max-width: 100%;
            height: auto;
            border-radius: 6px;
        }
        .markdown-body img.qc-image-broken {
            max-width: none;
            max-height: 1.2em;
            border-radius: 0;
            aspect-ratio: auto !important;
        }
        .markdown-body hr {
            height: 1px;
            border: 0;
            background: var(--border-color);
            margin: 24px 0;
        }
        \(syntaxTheme)
        </style>
        <script>
        \(MarkedJS.source)
        </script>
        <script>
        \(safeHighlightScript)
        </script>
        <script>
        \(safeRuntimeScript)
        </script>
        </head>
        <body>
        <div id="content" class="markdown-body">\(initialContentHTML)</div>
        <script>
        \(safeTrailingScript)
        </script>
        </body>
        </html>
        """
    }

    private static func bundledFontFaceCSS() -> String {
        let definitions: [(name: String, ext: String, weight: String, style: String)] = [
            ("JetBrainsMono-Regular", "ttf", "400", "normal"),
            ("JetBrainsMono-Italic", "ttf", "400", "italic"),
            ("JetBrainsMono-Bold", "ttf", "700", "normal"),
            ("JetBrainsMono-BoldItalic", "ttf", "700", "italic")
        ]

        let rules = definitions.compactMap { definition -> String? in
            guard let url = bundledFontURL(named: definition.name, ext: definition.ext) else {
                return nil
            }
            return """
            @font-face {
                font-family: 'JetBrains Mono';
                src: local('JetBrains Mono'),
                     local('JetBrainsMono-Regular'),
                     local('\(definition.name)'),
                     url('\(MarkdownPreviewBridge.javaScriptSingleQuotedString(url.absoluteString))') format('truetype');
                font-weight: \(definition.weight);
                font-style: \(definition.style);
            }
            """
        }

        return rules.joined(separator: "\n")
    }

    private static func bundledFontURL(named name: String, ext: String) -> URL? {
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fonts") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static func loadHighlightrScript() -> String? {
        guard let bundle = highlightrResourceBundle(),
              let url = bundle.url(forResource: "highlight", withExtension: "min.js"),
              let content = try? String(contentsOf: url) else {
            return nil
        }
        return content
    }

    private static func loadHighlightrThemeCSS(isDarkAppearance: Bool) -> String? {
        let themeName = isDarkAppearance ? "github-dark" : "github"
        guard let bundle = highlightrResourceBundle(),
              let url = bundle.url(forResource: themeName, withExtension: "min.css"),
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

    private static var candidateBundles: [Bundle] {
        var bundles = [Bundle.main, Bundle(for: Settings.self), Bundle(for: SyntaxHighlighter.self)]
        bundles.append(contentsOf: Bundle.allFrameworks)
        bundles.append(contentsOf: Bundle.allBundles)
        return bundles
    }
}

@MainActor
enum MarkdownPreviewShellWarmer {
    static func warmIfNeeded(
        runtime: WebKitRuntime,
        isDarkAppearance: Bool = false,
        bodyFontName: String,
        bodyFontSize: CGFloat,
        warmSnapshotRenderer: () -> Void = {
            MarkdownPreviewSnapshotRendererWarmer.warmIfNeeded()
        }
    ) async throws {
        let shellHTML = MarkdownHTMLShell.renderHTML(
            baseDirectoryURL: nil,
            isDarkAppearance: isDarkAppearance,
            bodyFontName: bodyFontName,
            bodyFontSize: bodyFontSize,
            initialContentHTML: "",
            bootstrapJavaScript: nil
        )

        try await runtime.prepareReusableShellIfNeeded(
            html: shellHTML,
            reusableShellAppearanceIsDark: isDarkAppearance
        )

        warmSnapshotRenderer()
    }
}
