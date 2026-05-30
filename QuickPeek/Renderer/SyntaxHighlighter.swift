import Foundation
import Highlightr

class SyntaxHighlighter {
    static let shared: SyntaxHighlighter? = {
        guard let highlightr = Highlightr() else {
            print("Failed to initialize Highlightr")
            return nil
        }
        // 默认采用高颜值 GitHub Dark 暗黑主题，完美融合本应用底色
        highlightr.setTheme(to: "github-dark")
        return SyntaxHighlighter(highlightr: highlightr)
    }()

    private let highlightr: Highlightr

    private init(highlightr: Highlightr) {
        self.highlightr = highlightr
    }

    /// 高亮代码，返回带 HTML 标签的字符串
    func highlight(code: String, language: String) -> NSAttributedString? {
        return highlightr.highlight(code, as: language)
    }

    /// 切换主题
    func setTheme(_ theme: String) {
        highlightr.setTheme(to: theme)
    }

    /// 支持的主题列表
    static let availableThemes = [
        "github-dark",
        "github-dark-dimmed",
        "github",
        "atom-one-dark",
        "atom-one-light",
        "monokai",
        "dracula",
        "nord",
        "vs2015",
        "solarized-dark",
        "solarized-light",
    ]
}