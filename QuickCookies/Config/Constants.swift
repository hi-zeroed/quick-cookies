import Foundation
import AppKit

enum Constants {
    // 默认快捷键：双击 Option 键（类似 PopClip）
    static let defaultHotkeyModifiers: NSEvent.ModifierFlags = [.option]
    static let defaultHotkeyKeyCode: UInt16 = 0 // Option 键没有 keycode，使用 modifier 检测

    // 双击 Option 触发的时间间隔（毫秒）
    static let doublePressInterval: TimeInterval = 0.5 // 500ms

    // 支持的代码与配置文件扩展名（已知支持高亮）
    static let supportedExtensions: Set<String> = [
        // 网页开发
        "html", "css", "scss", "sass", "less", "js", "jsx", "ts", "tsx", "json", "vue", "svelte", "mdx", "graphql", "gql", "cjs", "mjs", "cts", "mts", "jsonc", "json5",
        // 系统/脚本
        "sh", "zsh", "bash", "fish", "py", "go", "rs", "java", "kt", "swift", "c", "cpp", "h", "hpp", "cc", "cxx", "rb", "php", "sql", "command", "ksh",
        // 其它系统语言
        "lua", "pl", "pm", "groovy", "scala", "hs", "erl", "ex", "exs", "clj", "cljs", "lisp", "lsp", "scheme", "scm", "zig", "nim", "cr", "d", "sol", "dart",
        // 配置文件与数据
        "yaml", "yml", "toml", "xml", "plist", "ini", "conf", "config", "properties", "env", "csv", "tsv", "log", "diff", "patch", "eyaml",
        // 构建文件
        "gradle", "sbt", "podspec", "dockerfile", "makefile", "jenkinsfile", "fastfile", "lock"
    ]

    // Markdown 文件类型
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mdwn", "mkd", "mkdn"]

    // 二进制文件扩展名黑名单（遇到此类文件直接阻断，不作文本预览）
    static let binaryBlacklistExtensions: Set<String> = [
        "zip", "tar", "gz", "7z", "rar", "dmg", "pkg", "exe", "dll", "so", "dylib",
        "mp3", "mp4", "avi", "mov", "wav", "flac", "m4a", "ogg", "webm", "mkv", "flv", "swf",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "epub", "crx", "db", "sqlite", "localstorage",
        "class", "pyc", "o", "a", "bin", "dat", "iso", "img", "ttf", "otf", "woff", "woff2", "eot",
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "pdf" // 媒体和PDF由专门的渲染器处理，故从文本黑名单拦截
    ]

    // 代码文件 → Highlightr 语言名映射
    static let languageMap: [String: String] = [
        "json": "json",
        "jsonc": "json",
        "json5": "json",
        "yaml": "yaml",
        "yml": "yaml",
        "eyaml": "yaml",
        "toml": "toml",
        "xml": "xml",
        "plist": "xml",
        "sh": "bash",
        "zsh": "bash",
        "bash": "bash",
        "fish": "bash",
        "command": "bash",
        "ksh": "bash",
        "ts": "typescript",
        "tsx": "typescript",
        "cts": "typescript",
        "mts": "typescript",
        "js": "javascript",
        "jsx": "javascript",
        "cjs": "javascript",
        "mjs": "javascript",
        "py": "python",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "swift": "swift",
        "c": "c",
        "cpp": "cpp",
        "h": "c",
        "hpp": "cpp",
        "cc": "cpp",
        "cxx": "cpp",
        "rb": "ruby",
        "php": "php",
        "sql": "sql",
        "env": "bash",
        "lua": "lua",
        "pl": "perl",
        "pm": "perl",
        "groovy": "groovy",
        "scala": "scala",
        "hs": "haskell",
        "erl": "erlang",
        "ex": "elixir",
        "exs": "elixir",
        "clj": "clojure",
        "cljs": "clojure",
        "lisp": "lisp",
        "lsp": "lisp",
        "scheme": "lisp",
        "scm": "lisp",
        "dart": "dart",
        "html": "xml",
        "css": "css",
        "scss": "scss",
        "sass": "scss",
        "less": "less",
        "vue": "xml",
        "svelte": "xml",
        "gradle": "groovy",
        "podspec": "ruby",
        "jenkinsfile": "groovy",
        "fastfile": "ruby",
        "ini": "ini",
        "conf": "ini",
        "config": "ini"
    ]

    // 增量读取分段大小 (256KB)
    static let chunkSize: Int = 256 * 1024

    // 警告大文件阈值（50MB），普通读取上限也放宽
    static let largeFileThreshold: Int = 50 * 1024 * 1024

    // 语法高亮阈值（此处不设硬限制，采用异步增量解决卡顿）
    static let syntaxHighlightThreshold: Int = 50 * 1024 * 1024

    // Toast 自动消失时间
    static let toastDuration: TimeInterval = 3.0
}