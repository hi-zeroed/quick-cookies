import Foundation

enum FileRenderType {
    case markdown       // Markdown 渲染为 HTML
    case code           // 代码/配置文件，语法高亮
    case plainText      // 纯文本，无高亮
}

struct FileTypeClassifier {
    /// 根据文件路径判断渲染类型
    static func classify(path: String) -> FileRenderType {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        // Markdown 文件
        if Constants.markdownExtensions.contains(ext) {
            return .markdown
        }

        // 支持的代码/配置文件
        if Constants.supportedExtensions.contains(ext) {
            return .code
        }

        // 特殊文件名（无后缀）
        let filename = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        if filename == "makefile" || filename == "dockerfile" {
            return .code
        }

        // 其他文本文件
        return .plainText
    }

    /// 判断文件是否支持
    static func isSupported(path: String) -> Bool {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        if Constants.supportedExtensions.contains(ext) {
            return true
        }

        // 特殊文件名
        let filename = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return filename == "makefile" || filename == "dockerfile"
    }

    /// 获取 Highlightr 语言名称
    static func getLanguageName(path: String) -> String? {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        return Constants.languageMap[ext]
    }
}