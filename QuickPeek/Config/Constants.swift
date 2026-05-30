import Foundation
import AppKit

enum Constants {
    // 默认快捷键：双击 Option 键（类似 PopClip）
    static let defaultHotkeyModifiers: NSEvent.ModifierFlags = [.option]
    static let defaultHotkeyKeyCode: UInt16 = 0 // Option 键没有 keycode，使用 modifier 检测

    // 双击 Option 触发的时间间隔（毫秒）
    static let doublePressInterval: TimeInterval = 0.5 // 500ms

    // 支持的文件扩展名
    static let supportedExtensions: Set<String> = [
        // 配置文件
        "json", "yaml", "yml", "toml", "xml", "env",
        // Markdown
        "md", "markdown",
        // Shell
        "sh", "zsh", "bash",
        // 代码
        "ts", "tsx", "js", "jsx", "py", "go", "rs", "java", "kt",
        "swift", "c", "cpp", "h", "rb", "php", "sql",
        // 其他文本
        "txt", "log", "csv", "conf", "config", "ini",
        "gitignore", "dockerignore", "editorconfig",
    ]

    // Markdown 文件类型
    static let markdownExtensions: Set<String> = ["md", "markdown"]

    // 代码文件 → Highlightr 语言名映射
    static let languageMap: [String: String] = [
        "json": "json",
        "yaml": "yaml",
        "yml": "yaml",
        "toml": "toml",
        "xml": "xml",
        "sh": "bash",
        "zsh": "bash",
        "bash": "bash",
        "ts": "typescript",
        "tsx": "typescript",
        "js": "javascript",
        "jsx": "javascript",
        "py": "python",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "swift": "swift",
        "c": "c",
        "cpp": "cpp",
        "h": "c",
        "rb": "ruby",
        "php": "php",
        "sql": "sql",
        "env": "bash",
    ]

    // 文件大小警告阈值
    static let largeFileThreshold: Int = 5 * 1024 * 1024 // 5MB

    // 语法高亮阈值（超过此大小跳过高亮，显示纯文本）
    static let syntaxHighlightThreshold: Int = 100 * 1024 // 100KB

    // Toast 自动消失时间
    static let toastDuration: TimeInterval = 3.0
}