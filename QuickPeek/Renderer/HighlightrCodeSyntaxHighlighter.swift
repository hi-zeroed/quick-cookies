import SwiftUI
import MarkdownUI

/// 桥接自定义 Highlightr 到 MarkdownUI 的 CodeSyntaxHighlighter 协议
struct HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let language = language,
              let highlighter = SyntaxHighlighter.shared else {
            return Text(code)
        }

        // 利用全局缓存 HighlightCache，以代码内容的 Hash 值作为标识进行匹配
        let cacheKey = "markdown_block_\(code.hashValue)"
        let fixedDate = Date(timeIntervalSince1970: 0) // hash 变化会自动变更 key，因此使用固定日期

        if let cached = HighlightCache.shared.get(for: cacheKey, modificationDate: fixedDate) {
            return Text(AttributedString(cached))
        }

        // 限制：如果代码块长度超过 100 行，则不进行同步语法解析以保护主线程，直接返回普通 Text
        let lines = code.components(separatedBy: "\n")
        guard lines.count <= 100 else {
            return Text(code)
        }

        if let attributed = highlighter.highlight(code: code, language: language) {
            HighlightCache.shared.set(attributed, for: cacheKey, modificationDate: fixedDate)
            return Text(AttributedString(attributed))
        }

        return Text(code)
    }
}

extension CodeSyntaxHighlighter where Self == HighlightrCodeSyntaxHighlighter {
    /// 原生 MarkdownUI 高亮处理器插件
    static var highlightr: Self {
        HighlightrCodeSyntaxHighlighter()
    }
}
