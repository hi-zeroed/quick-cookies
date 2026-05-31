import SwiftUI
import MarkdownUI

/// 桥接自定义 Highlightr 到 MarkdownUI 的 CodeSyntaxHighlighter 协议
struct HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let language = language,
              let highlighter = SyntaxHighlighter.shared else {
            return Text(code)
        }

        // 动态推算当前是否为深色模式以应用正确的外观和缓存
        let isDark: Bool
        switch Settings.shared.themeMode {
        case .light:
            isDark = false
        case .dark:
            isDark = true
        case .system:
            isDark = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"

        // 获取用户配置的编辑器字体与代码块字号（略小于普通正文以适配排版）
        let fontName = Settings.shared.editorFont
        let fontSize = Settings.shared.fontSize * 0.9

        // 利用全局缓存 HighlightCache，隔离缓存主键（包含字体、字号、和内容 Hash）
        let cacheKey = "markdown_block_\(code.hashValue)"
        let fixedDate = Date(timeIntervalSince1970: 0) // hash 变化会自动变更 key，因此使用固定日期

        if let cached = HighlightCache.shared.get(for: cacheKey, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: fixedDate) {
            return Text(AttributedString(cached))
        }

        // 限制：如果代码块长度超过 100 行，则不进行同步语法解析以保护主线程，直接返回普通 Text
        let lines = code.components(separatedBy: "\n")
        guard lines.count <= 100 else {
            return Text(code)
        }

        if let attributed = highlighter.highlight(code: code, language: language, theme: themeName) {
            // 对高亮产生的富文本应用字体及字号，保留粗斜体
            let customAttributed = attributed.applyingEditorFont(name: fontName, size: fontSize)
            HighlightCache.shared.set(customAttributed, for: cacheKey, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: fixedDate)
            return Text(AttributedString(customAttributed))
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
