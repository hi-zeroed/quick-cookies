import Foundation
import Highlightr

class SyntaxHighlighter {
    static let shared: SyntaxHighlighter? = {
        guard let highlightr = Highlightr() else {
            return nil
        }
        // 默认采用经典 Atom One Dark 暗黑主题，完美融入深色背景
        highlightr.setTheme(to: "atom-one-dark")
        return SyntaxHighlighter(highlightr: highlightr)
    }()

    private let highlightr: Highlightr
    private let lock = NSLock()

    private init(highlightr: Highlightr) {
        self.highlightr = highlightr
    }

    /// 高亮代码，返回带 HTML 标签的字符串（原接口保持兼容）
    func highlight(code: String, language: String) -> NSAttributedString? {
        lock.lock()
        defer { lock.unlock() }
        return highlightr.highlight(code, as: language)
    }

    /// 高亮代码，支持指定主题名（线程安全锁保护）
    func highlight(code: String, language: String, theme: String) -> NSAttributedString? {
        lock.lock()
        defer { lock.unlock() }
        highlightr.setTheme(to: theme)
        return highlightr.highlight(code, as: language)
    }

    /// 切换主题
    func setTheme(_ theme: String) {
        lock.lock()
        defer { lock.unlock() }
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
