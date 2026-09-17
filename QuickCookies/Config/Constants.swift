import Foundation
import AppKit

enum Constants {
    // 默认热键语义：双击 Command；若用户录制了常规组合键，则走普通 keyDown 监听。
    static let defaultHotkeyModifiers: NSEvent.ModifierFlags = [.command]
    static let defaultHotkeyKeyCode: UInt16 = 0 // 0 表示“双击修饰键”模式，而不是普通 keyDown keyCode

    // 默认剪贴板透视热键：Control + Option + V (Keycode 9 为字母 V，无任何主流编辑器冲突)
    static let defaultClipboardHotkeyModifiers: NSEvent.ModifierFlags = [.control, .option]
    static let defaultClipboardHotkeyKeyCode: UInt16 = 9

    // 默认直接唤起分享卡片热键：Control + Option + C (Keycode 8 为字母 C)
    static let defaultShareCardHotkeyModifiers: NSEvent.ModifierFlags = [.control, .option]
    static let defaultShareCardHotkeyKeyCode: UInt16 = 8

    // 双击修饰键触发的时间间隔（秒）
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

    // 压缩包与归档文件类型
    static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "7z", "rar", "jar", "war", "ear"
    ]

    // 音频文件类型
    static let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "aiff", "caf", "ogg"
    ]

    // 视频文件类型
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "webm"
    ]

    // 字体文件类型
    static let fontExtensions: Set<String> = [
        "ttf", "otf", "woff", "woff2"
    ]

    // 十六进制二进制透视扩展名（支持纯原生 Hex 字节检视）
    static let hexExtensions: Set<String> = [
        "bin", "dat", "wasm", "hex", "dylib", "so", "o", "a", "class", "pyc", "elf"
    ]

    // CSV / TSV 数据表格扩展名（支持虚拟化数据网格与源码双模切换）
    static let csvExtensions: Set<String> = [
        "csv", "tsv"
    ]

    // 二进制文件扩展名黑名单（遇到此类文件直接阻断，不作文本或常规Hex预览）
    static let binaryBlacklistExtensions: Set<String> = [
        "dmg", "pkg", "exe", "dll",
        "mp3", "mp4", "avi", "mov", "wav", "flac", "m4a", "ogg", "webm", "mkv", "flv", "swf",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "epub", "crx", "db", "sqlite", "localstorage",
        "iso", "img", "ttf", "otf", "woff", "woff2", "eot",
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "pdf" // 媒体、PDF和压缩包由专门的渲染器处理，故从文本黑名单拦截
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
