import Foundation

enum FileRenderType {
    case markdown       // Markdown 渲染为 HTML
    case code           // 代码/配置文件，语法高亮
    case plainText      // 纯文本，无高亮
    case pdf            // PDF 预览
    case image          // 图片预览
    case unsupported    // 不支持预览的文件
}

struct FileTypeClassifier {
    /// 根据文件路径判断渲染类型
    static func classify(path: String) -> FileRenderType {
        let resolvedPath = FileUtils.resolveSymlink(at: path)
        if !isSupported(path: resolvedPath) {
            return .unsupported
        }

        let ext = URL(fileURLWithPath: resolvedPath)
            .pathExtension
            .lowercased()

        if ext == "pdf" {
            return .pdf
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "bmp"]
        if imageExtensions.contains(ext) {
            return .image
        }

        // Markdown 文件
        if Constants.markdownExtensions.contains(ext) {
            return .markdown
        }

        // 支持的代码/配置文件
        if Constants.supportedExtensions.contains(ext) {
            return .code
        }

        // 特殊文件名（无后缀）
        let filename = URL(fileURLWithPath: resolvedPath).lastPathComponent.lowercased()
        if filename == "makefile" || filename == "dockerfile" {
            return .code
        }

        // 其它一切未知扩展名均默认判定为纯文本模式
        return .plainText
    }

    /// 判断文件是否支持
    static func isSupported(path: String) -> Bool {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        if ext == "pdf" {
            return true
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "bmp"]
        if imageExtensions.contains(ext) {
            return true
        }

        // 如果扩展名在二进制黑名单中，直接拦截
        if Constants.binaryBlacklistExtensions.contains(ext) {
            return false
        }

        // 其它一切未知扩展名默认放行支持（读取文件时如检测为二进制会优雅报错）
        return true
    }

    /// 获取 Highlightr 语言名称
    static func getLanguageName(path: String) -> String? {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        return Constants.languageMap[ext]
    }
}