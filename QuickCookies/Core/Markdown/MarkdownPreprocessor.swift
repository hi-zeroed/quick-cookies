import Foundation

enum MarkdownPreprocessor {
    static func preprocess(_ text: String) -> String {
        rewriteOutsideCodeFences(in: text, transform: convertObsidianImageEmbeds)
    }

    private static func rewriteOutsideCodeFences(
        in text: String,
        transform: (String) -> String
    ) -> String {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var result: [String] = []
        var buffer: [String] = []
        var activeFenceMarker: Character?

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            result.append(transform(buffer.joined(separator: "\n")))
            buffer.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let stringLine = String(line)

            if let marker = fenceMarker(for: stringLine) {
                if activeFenceMarker == nil {
                    flushBuffer()
                    activeFenceMarker = marker
                } else if activeFenceMarker == marker {
                    activeFenceMarker = nil
                }

                result.append(stringLine)
                continue
            }

            if activeFenceMarker != nil {
                result.append(stringLine)
            } else {
                buffer.append(stringLine)
            }
        }

        flushBuffer()
        return result.joined(separator: "\n")
    }

    private static func fenceMarker(for line: String) -> Character? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let count = trimmed.prefix { $0 == marker }.count
        return count >= 3 ? marker : nil
    }

    private static func convertObsidianImageEmbeds(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"!\[\[([^|\]]+\.(?:png|jpe?g|gif|webp|bmp|tiff?|svg|heic|heif|ico))(?:(?:\|[^\]]*)?)\]\]"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }

        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "![](<$1>)"
        )
    }
}
