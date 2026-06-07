import Foundation
import AppKit

struct MarkdownInitialSource {
    let blocks: [MarkdownRenderBlock]
    let fileSize: UInt64
    let effectiveFileSize: UInt64
    let requiresDeferredLoad: Bool
}

enum MarkdownPreviewBridge {
    static func makeInitialSource(
        filePath: String,
        fallbackMarkdown: String,
        baseDirectoryURL: URL?
    ) -> MarkdownInitialSource {
        let fileSize = MarkdownFileStreamReader.fileSize(path: filePath)
        let fallbackByteCount = fallbackMarkdown.utf8.count
        let requiresDeferredLoad = fileSize > UInt64(fallbackByteCount)

        let stableSource: String
        if fallbackMarkdown.isEmpty {
            stableSource = ""
        } else if requiresDeferredLoad {
            stableSource = stablePrefix(from: fallbackMarkdown)
        } else {
            stableSource = fallbackMarkdown
        }

        let processedMarkdown = MarkdownPreprocessor.preprocess(stableSource)
        let parser = MarkdownBlockStreamParser(baseDirectoryURL: baseDirectoryURL)
        return MarkdownInitialSource(
            blocks: parser.parse(processedMarkdown),
            fileSize: fileSize,
            effectiveFileSize: max(fileSize, UInt64(processedMarkdown.utf8.count)),
            requiresDeferredLoad: requiresDeferredLoad
        )
    }

    static func prepareContent(
        filePath: String,
        fallbackMarkdown: String,
        preferFileBackedRendering: Bool,
        baseDirectoryURL: URL?,
        policy: MarkdownPreviewPolicy,
        droppingLeadingBlocks: Int = 0,
        knownFileSize: UInt64? = nil,
        allowsEmptyPlaceholder: Bool = true
    ) -> MarkdownPreviewPreparedContent {
        let fileSize = knownFileSize ?? MarkdownFileStreamReader.fileSize(path: filePath)
        let shouldPreferFile = policy.prefersFileBackedRendering(
            fileSize: fileSize,
            fallbackLength: fallbackMarkdown.utf8.count,
            requestedByView: preferFileBackedRendering
        )

        let sourceMarkdown: String
        if shouldPreferFile {
            switch MarkdownFileStreamReader.readEntireFile(path: filePath) {
            case .success(let content):
                sourceMarkdown = content
            case .failure(let error):
                sourceMarkdown = fallbackMarkdown.isEmpty
                    ? "Markdown preview error:\n\n\(error.errorDescription ?? "无法读取文件内容")"
                    : fallbackMarkdown
            }
        } else {
            sourceMarkdown = fallbackMarkdown
        }

        let processedMarkdown = MarkdownPreprocessor.preprocess(sourceMarkdown)
        let parser = MarkdownBlockStreamParser(baseDirectoryURL: baseDirectoryURL)
        var blocks = parser.parse(processedMarkdown)

        if droppingLeadingBlocks > 0, droppingLeadingBlocks < blocks.count {
            blocks = Array(blocks.dropFirst(droppingLeadingBlocks)).enumerated().map { offset, block in
                MarkdownRenderBlock(
                    id: "markdown-block-deferred-\(offset + droppingLeadingBlocks)",
                    kind: block.kind,
                    markdown: block.markdown,
                    preferredHeight: block.preferredHeight,
                    imageMetas: block.imageMetas,
                    codeLanguage: block.codeLanguage
                )
            }
        } else if droppingLeadingBlocks >= blocks.count {
            blocks = []
        }

        if blocks.isEmpty && allowsEmptyPlaceholder {
            blocks = [
                MarkdownRenderBlock(
                    id: "markdown-block-empty",
                    kind: .paragraph,
                    markdown: "",
                    preferredHeight: 24,
                    imageMetas: [],
                    codeLanguage: nil
                )
            ]
        }

        return makePreparedContent(
            from: blocks,
            effectiveFileSize: max(fileSize, UInt64(processedMarkdown.utf8.count)),
            policy: policy
        )
    }

    static func javaScriptForConfigure(shouldVirtualize: Bool, overscanScreens: Int) -> String {
        "window.__quickCookiesMarkdown.configure({ virtualize: \(shouldVirtualize ? "true" : "false"), overscanScreens: \(overscanScreens) });"
    }

    static func javaScriptForReset() -> String {
        "window.__quickCookiesMarkdown.reset();"
    }

    static func javaScriptForAppend(batch: MarkdownPreviewBatch) -> String? {
        guard let data = try? JSONEncoder().encode(batch),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return "window.__quickCookiesMarkdown.appendBatch(JSON.parse('\(javaScriptSingleQuotedString(json))'));"
    }

    static func javaScriptForBootstrap(preparedContent: MarkdownPreviewPreparedContent) -> String? {
        guard let bootstrapBatch = preparedContent.batches.first,
              let appendScript = javaScriptForBootstrap(batch: bootstrapBatch) else {
            return nil
        }

        let configureScript = javaScriptForConfigure(
            shouldVirtualize: preparedContent.shouldVirtualize,
            overscanScreens: preparedContent.overscanScreens
        )

        return """
        \(configureScript)
        \(appendScript)
        """
    }

    static func javaScriptForBootstrap(batch: MarkdownPreviewBatch) -> String? {
        guard let data = try? JSONEncoder().encode(batch),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return "window.__quickCookiesMarkdown.bootstrapBatch(JSON.parse('\(javaScriptSingleQuotedString(json))'));"
    }

    static func javaScriptForBootstrapSnapshot(_ snapshot: MarkdownRenderSnapshot) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]

        guard let data = try? encoder.encode(snapshot),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return "window.__quickCookiesMarkdown.bootstrapSnapshot(JSON.parse('\(javaScriptSingleQuotedString(json))'));"
    }

    static func javaScriptForApplyStyle(bodyFontName: String, bodyFontSize: CGFloat) -> String {
        let bodyFontFamily = cssFontFamily(
            for: bodyFontName,
            fallbacks: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
        )
        let codeFontFamily = cssFontFamily(
            for: bodyFontName,
            fallbacks: "\"SFMono-Regular\", Menlo, Consolas, monospace"
        )
        let fontSize = max(bodyFontSize, 12)
        let bodyFontFamilyJS = javaScriptSingleQuotedString(bodyFontFamily)
        let codeFontFamilyJS = javaScriptSingleQuotedString(codeFontFamily)

        return """
        document.documentElement.style.setProperty('--body-font-family', '\(bodyFontFamilyJS)');
        document.documentElement.style.setProperty('--code-font-family', '\(codeFontFamilyJS)');
        document.documentElement.style.setProperty('--body-font-size', '\(fontSize)px');
        window.__quickCookiesMarkdown.refreshTheme();
        """
    }

    static func javaScriptForUpdateBaseURL(_ baseDirectoryURL: URL?) -> String {
        let href = baseDirectoryURL?.absoluteString ?? ""
        let hrefJS = javaScriptSingleQuotedString(href)

        return """
        (function() {
            var head = document.head || document.getElementsByTagName('head')[0];
            if (!head) { return; }
            var base = head.querySelector('base');
            if (!base) {
                base = document.createElement('base');
                head.insertBefore(base, head.firstChild);
            }
            base.setAttribute('href', '\(hrefJS)');
        })();
        """
    }

    static func cssFontFamily(for name: String, fallbacks: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == "System Default (Inter)" {
            return fallbacks
        }

        let resolvedName: String
        switch trimmedName {
        case "JetBrains Mono":
            resolvedName = "JetBrains Mono"
        default:
            resolvedName = trimmedName
        }

        let escapedName = resolvedName.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedName)\", \(fallbacks)"
    }

    static func javaScriptSingleQuotedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    static func initialContentHTML(for snapshot: MarkdownRenderSnapshot) -> String {
        snapshot.renderedBlocks.map { block in
            let bodyHTML = block.html
            let minHeightAttribute: String
            let resolvedHeight = block.height ?? snapshot.blockHeights[block.id]
            if let resolvedHeight {
                minHeightAttribute = #" style="min-height: \#(Int(ceil(resolvedHeight)))px""#
            } else {
                minHeightAttribute = ""
            }

            return """
            <section class="markdown-block-shell" data-block-id="\(htmlAttributeEscaped(block.id))" data-kind="\(htmlAttributeEscaped(block.kind.rawValue))" data-virtualized="false"\(minHeightAttribute)>
            <div class="markdown-block-body">\(bodyHTML)</div>
            </section>
            """
        }.joined(separator: "\n")
    }

    static func emptyPlaceholderBlock() -> MarkdownRenderBlock {
        MarkdownRenderBlock(
            id: "markdown-block-empty",
            kind: .paragraph,
            markdown: "",
            preferredHeight: 24,
            imageMetas: [],
            codeLanguage: nil
        )
    }

    static func makePreparedContent(
        from blocks: [MarkdownRenderBlock],
        effectiveFileSize: UInt64,
        policy: MarkdownPreviewPolicy,
        forceSingleBatch: Bool = false
    ) -> MarkdownPreviewPreparedContent {
        let shouldVirtualize = policy.shouldVirtualize(fileSize: effectiveFileSize, blockCount: blocks.count)
        let overscanScreens = policy.usesAggressiveVirtualization(fileSize: effectiveFileSize)
            ? max(policy.overscanScreens - 1, 2)
            : policy.overscanScreens

        return MarkdownPreviewPreparedContent(
            batches: makeBatches(from: blocks, policy: policy, forceSingleBatch: forceSingleBatch),
            shouldVirtualize: shouldVirtualize,
            overscanScreens: overscanScreens
        )
    }

    private static func makeBatches(
        from blocks: [MarkdownRenderBlock],
        policy: MarkdownPreviewPolicy,
        forceSingleBatch: Bool
    ) -> [MarkdownPreviewBatch] {
        guard !blocks.isEmpty else { return [] }

        if forceSingleBatch {
            return [MarkdownPreviewBatch(appendMode: .initial, blocks: blocks)]
        }

        var batches: [MarkdownPreviewBatch] = []
        var index = 0

        let initialCount = min(policy.initialBatchBlockCount, blocks.count)
        batches.append(MarkdownPreviewBatch(appendMode: .initial, blocks: Array(blocks[0..<initialCount])))
        index = initialCount

        while index < blocks.count {
            let end = min(index + policy.incrementalBatchBlockCount, blocks.count)
            batches.append(MarkdownPreviewBatch(appendMode: .incremental, blocks: Array(blocks[index..<end])))
            index = end
        }

        return batches
    }

    private static func stablePrefix(from markdown: String) -> String {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        guard !lines.isEmpty else { return markdown }

        var safeLineIndex = 0
        var isInsideFence = false
        var fenceMarker: Character?
        var fenceCount = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let first = trimmed.first, (first == "`" || first == "~") {
                let prefixCount = trimmed.prefix { $0 == first }.count
                if prefixCount >= 3 {
                    if isInsideFence, first == fenceMarker, prefixCount >= fenceCount {
                        isInsideFence = false
                        safeLineIndex = index + 1
                    } else if !isInsideFence {
                        isInsideFence = true
                        fenceMarker = first
                        fenceCount = prefixCount
                    }
                }
            }

            if !isInsideFence && trimmed.isEmpty {
                safeLineIndex = index + 1
            }
        }

        if safeLineIndex <= 0 || safeLineIndex >= lines.count {
            return markdown
        }

        return lines.prefix(safeLineIndex).joined(separator: "\n")
    }

    private static func htmlAttributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
