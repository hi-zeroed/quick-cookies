import Foundation

enum FileRenderType {
    case markdown       // Markdown 渲染为 HTML
    case code           // 代码/配置文件，语法高亮
    case plainText      // 纯文本，无高亮
    case pdf            // PDF 预览
    case image          // 图片预览
    case unsupported    // 不支持预览的文件
    case office         // Word, Excel, PPT, RTF, RTFD, Pages, Numbers, Keynote, CSV 等
    case archive        // Zip, Tar, Gz, 7z, Rar 等压缩包与归档文件
    case folder         // 本地普通文件夹与目录
    case audio          // 音频文件预览 (MP3, WAV, M4A, FLAC 等)
    case video          // 视频文件预览 (MP4, MOV, M4V, WEBM 等)
    case font           // 字体文件预览 (TTF, OTF, WOFF, WOFF2)
    case hex            // 十六进制二进制透视 (BIN, DAT, WASM, DYLIB, SO 等)
}

struct FileTypeClassifier {
    /// 根据文件路径判断渲染类型
    static func classify(path: String) -> FileRenderType {
        let resolvedPath = FileUtils.resolveSymlink(at: path)
        if !isSupported(path: resolvedPath) {
            return .unsupported
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDir), isDir.boolValue {
            return .folder
        }

        let ext = URL(fileURLWithPath: resolvedPath)
            .pathExtension
            .lowercased()

        if ext == "pdf" {
            return .pdf
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "tif", "heic", "heif", "ico", "svg"]
        if imageExtensions.contains(ext) {
            return .image
        }

        // 优先匹配音视频与字体
        if Constants.audioExtensions.contains(ext) {
            return .audio
        }
        if Constants.videoExtensions.contains(ext) {
            return .video
        }
        if Constants.fontExtensions.contains(ext) {
            return .font
        }

        // 优先匹配办公文档与富文本
        let officeExtensions: Set<String> = ["rtf", "rtfd", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers"]
        if officeExtensions.contains(ext) {
            return .office
        }

        // 优先匹配压缩包与归档文件
        if Constants.archiveExtensions.contains(ext) {
            return .archive
        }

        // 优先匹配明确的十六进制二进制透视格式
        if Constants.hexExtensions.contains(ext) {
            return .hex
        }

        // 快速进行物理二进制检测 (只读取最前 1KB 字节检查 null 字节)
        // 必须在排除已知支持的图片、PDF、Office 和压缩包等格式之后检测，防误杀
        if isBinaryFileFastCheck(path: resolvedPath) {
            return .hex
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
        // 1. 本地文件夹目录类型
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                return true
            }
        } else {
            return false
        }

        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        if ext == "pdf" {
            return true
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "tif", "heic", "heif", "ico", "svg"]
        if imageExtensions.contains(ext) {
            return true
        }

        // 直接放行支持的办公文档和富文本格式
        let officeExtensions: Set<String> = ["rtf", "rtfd", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers"]
        if officeExtensions.contains(ext) {
            return true
        }

        // 直接放行支持的压缩包与归档文件
        if Constants.archiveExtensions.contains(ext) {
            return true
        }

        // 直接放行支持的音视频与字体文件
        if Constants.audioExtensions.contains(ext) || Constants.videoExtensions.contains(ext) || Constants.fontExtensions.contains(ext) {
            return true
        }

        // 直接放行支持的十六进制透视格式
        if Constants.hexExtensions.contains(ext) {
            return true
        }

        // 如果扩展名在二进制黑名单中，直接拦截
        if Constants.binaryBlacklistExtensions.contains(ext) {
            return false
        }

        // 其它一切未知扩展名默认放行支持（读取文件时如检测为二进制会优雅报错）
        return true
    }

    /// 快速同步二进制检测（限制前 1KB，主线程高防）
    private static func isBinaryFileFastCheck(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer {
            try? fileHandle.close()
        }
        
        let data: Data
        if #available(macOS 10.15, *) {
            data = (try? fileHandle.read(upToCount: 1024)) ?? Data()
        } else {
            data = fileHandle.readData(ofLength: 1024)
        }
        
        return data.contains(0x00)
    }

    /// 获取 Highlightr 语言名称
    static func getLanguageName(path: String) -> String? {
        let ext = URL(fileURLWithPath: path)
            .pathExtension
            .lowercased()

        return Constants.languageMap[ext]
    }
}
