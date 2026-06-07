import Foundation

struct MarkdownBlockStreamParser {
    let baseDirectoryURL: URL?

    private enum HTMLBlockDescriptor {
        case standalone
        case container(tag: String, depth: Int)
    }

    func parse(_ text: String) -> [MarkdownRenderBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownRenderBlock] = []
        var index = 0
        var blockIndex = 0

        while index < lines.count {
            let line = lines[index]

            if isBlank(line) {
                index += 1
                continue
            }

            if let fence = fenceInfo(for: line) {
                let start = index
                index += 1

                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.hasPrefix(String(repeating: String(fence.marker), count: fence.count)) {
                        index += 1
                        break
                    }
                    index += 1
                }

                appendBlock(
                    kind: .code,
                    lines: Array(lines[start..<min(index, lines.count)]),
                    blockIndex: &blockIndex,
                    codeLanguage: fence.language,
                    into: &blocks
                )
                continue
            }

            if isTableHeader(line: line, nextLine: index + 1 < lines.count ? lines[index + 1] : nil) {
                let start = index
                index += 2
                while index < lines.count {
                    let current = lines[index]
                    if isBlank(current) || isStructuralBoundary(current) {
                        break
                    }
                    if !current.contains("|") {
                        break
                    }
                    index += 1
                }

                appendBlock(
                    kind: .table,
                    lines: Array(lines[start..<index]),
                    blockIndex: &blockIndex,
                    into: &blocks
                )
                continue
            }

            if isHeading(line) {
                appendBlock(kind: .heading, lines: [line], blockIndex: &blockIndex, into: &blocks)
                index += 1
                continue
            }

            if isThematicBreak(line) {
                appendBlock(kind: .thematicBreak, lines: [line], blockIndex: &blockIndex, into: &blocks)
                index += 1
                continue
            }

            if isQuote(line) {
                let start = index
                index += 1
                while index < lines.count {
                    let current = lines[index]
                    if isBlank(current) || isQuote(current) {
                        index += 1
                    } else {
                        break
                    }
                }

                appendBlock(
                    kind: .quote,
                    lines: Array(lines[start..<index]),
                    blockIndex: &blockIndex,
                    into: &blocks
                )
                continue
            }

            if isList(line) {
                let start = index
                index += 1
                while index < lines.count {
                    let current = lines[index]
                    if isBlank(current) {
                        index += 1
                        continue
                    }
                    if isList(current) || isIndentedContinuation(current) {
                        index += 1
                        continue
                    }
                    break
                }

                appendBlock(
                    kind: .list,
                    lines: Array(lines[start..<index]),
                    blockIndex: &blockIndex,
                    into: &blocks
                )
                continue
            }

            if let htmlDescriptor = htmlBlockDescriptor(for: line) {
                let start = index
                index += 1

                switch htmlDescriptor {
                case .standalone:
                    while index < lines.count, !isBlank(lines[index]) {
                        if isStructuralBoundary(lines[index]) {
                            break
                        }
                        index += 1
                    }
                case .container(let tag, var depth):
                    while index < lines.count, depth > 0 {
                        depth += htmlContainerDepthDelta(for: lines[index], tag: tag)
                        index += 1
                    }
                }

                appendBlock(
                    kind: .html,
                    lines: Array(lines[start..<index]),
                    blockIndex: &blockIndex,
                    into: &blocks
                )
                continue
            }

            let start = index
            index += 1
            while index < lines.count {
                let current = lines[index]
                if isBlank(current) || isStructuralBoundary(current) {
                    break
                }
                index += 1
            }

            let paragraphLines = Array(lines[start..<index])
            let kind: MarkdownRenderBlockKind = isStandaloneImageBlock(paragraphLines) ? .image : .paragraph
            appendBlock(kind: kind, lines: paragraphLines, blockIndex: &blockIndex, into: &blocks)
        }

        return blocks
    }

    private func appendBlock(
        kind: MarkdownRenderBlockKind,
        lines: [String],
        blockIndex: inout Int,
        codeLanguage: String? = nil,
        into blocks: inout [MarkdownRenderBlock]
    ) {
        let markdown = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        guard !markdown.isEmpty else { return }

        let imageMetas = MarkdownImageProbe.probeImages(in: markdown, baseDirectoryURL: baseDirectoryURL)
        let preferredHeight = estimateHeight(for: lines, kind: kind, imageMetas: imageMetas)

        blocks.append(
            MarkdownRenderBlock(
                id: "markdown-block-\(blockIndex)",
                kind: kind,
                markdown: markdown,
                preferredHeight: preferredHeight,
                imageMetas: imageMetas,
                codeLanguage: codeLanguage
            )
        )
        blockIndex += 1
    }

    private func estimateHeight(
        for lines: [String],
        kind: MarkdownRenderBlockKind,
        imageMetas: [MarkdownImageMeta]
    ) -> Double? {
        switch kind {
        case .code:
            return max(88, Double(lines.count) * 24 + 28)
        case .table:
            return max(96, Double(lines.count) * 28 + 20)
        case .image:
            if let meta = imageMetas.first,
               let width = meta.width,
               let height = meta.height,
               width > 0,
               height > 0 {
                let clampedWidth = min(Double(width), 720)
                let ratio = Double(height) / Double(width)
                return max(160, clampedWidth * ratio + 24)
            }
            return nil
        case .thematicBreak:
            return 28
        default:
            return nil
        }
    }

    private func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefixHashes = trimmed.prefix { $0 == "#" }
        return !prefixHashes.isEmpty && prefixHashes.count <= 6 && trimmed.dropFirst(prefixHashes.count).first == " "
    }

    private func isQuote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private func isList(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return true
        }

        let pattern = #"^\d+[.)]\s+"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func isIndentedContinuation(_ line: String) -> Bool {
        let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
        return leadingWhitespace.count >= 2
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(?:\*\s*){3,}$|^(?:-\s*){3,}$|^(?:_\s*){3,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func isTableHeader(line: String, nextLine: String?) -> Bool {
        guard line.contains("|"), let nextLine else { return false }
        let trimmed = nextLine.trimmingCharacters(in: .whitespaces)
        let pattern = #"^\|?(?:\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func isHTMLBlock(_ line: String) -> Bool {
        htmlBlockDescriptor(for: line) != nil
    }

    private func htmlBlockDescriptor(for line: String) -> HTMLBlockDescriptor? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("<") else { return nil }

        if trimmed.hasPrefix("<img") {
            return .standalone
        }

        guard let tag = supportedHTMLContainerTag(in: trimmed) else {
            return nil
        }

        let depth = htmlContainerDepthDelta(for: trimmed, tag: tag)
        return depth > 0 ? .container(tag: tag, depth: depth) : .standalone
    }

    private func supportedHTMLContainerTag(in trimmedLine: String) -> String? {
        let lowercased = trimmedLine.lowercased()
        let supportedTags = ["div", "table", "p", "section", "article", "blockquote", "pre"]

        for tag in supportedTags where lowercased.hasPrefix("<\(tag)") {
            return tag
        }

        return nil
    }

    private func htmlContainerDepthDelta(for line: String, tag: String) -> Int {
        countHTMLContainerOpenings(in: line, tag: tag) - countHTMLContainerClosings(in: line, tag: tag)
    }

    private func countHTMLContainerOpenings(in line: String, tag: String) -> Int {
        let pattern = #"<\#(tag)\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }

        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, options: [], range: range).reduce(into: 0) { count, match in
            guard let matchRange = Range(match.range, in: line) else { return }
            let snippet = line[matchRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if snippet.hasPrefix("</") || snippet.hasSuffix("/>") {
                return
            }
            count += 1
        }
    }

    private func countHTMLContainerClosings(in line: String, tag: String) -> Int {
        let pattern = #"</\#(tag)\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }

        let range = NSRange(line.startIndex..., in: line)
        return regex.numberOfMatches(in: line, options: [], range: range)
    }

    private func isStandaloneImageBlock(_ lines: [String]) -> Bool {
        guard lines.count == 1 else { return false }
        let trimmed = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let markdownPattern = #"^!\[[^\]]*\]\((?:<[^>]+>|[^) \t]+)(?:\s+"[^"]*")?\)$"#
        let htmlPattern = #"^<img\s+[^>]*src=['"][^'"]+['"][^>]*>$"#
        return trimmed.range(of: markdownPattern, options: .regularExpression) != nil ||
            trimmed.range(of: htmlPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isStructuralBoundary(_ line: String) -> Bool {
        isHeading(line) ||
        isQuote(line) ||
        isList(line) ||
        isThematicBreak(line) ||
        isHTMLBlock(line) ||
        fenceInfo(for: line) != nil
    }

    private func fenceInfo(for line: String) -> (marker: Character, count: Int, language: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let prefix = trimmed.prefix { $0 == marker }
        guard prefix.count >= 3 else { return nil }

        let rest = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        let language = rest.isEmpty ? nil : String(rest.split(separator: " ").first ?? "")
        return (marker: marker, count: prefix.count, language: language)
    }
}
