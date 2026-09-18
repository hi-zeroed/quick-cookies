import Foundation

/// 经过规范化解析的文件目标
public struct ResolvedPathTarget: Equatable, Sendable {
    public let fileURL: URL
    public let isDirectory: Bool
    public let targetLine: Int?

    public init(fileURL: URL, isDirectory: Bool, targetLine: Int? = nil) {
        self.fileURL = fileURL
        self.isDirectory = isDirectory
        self.targetLine = targetLine
    }
}

/// 全系统文本路径嗅探与解析引擎
/// 负责将来自剪贴板、系统服务划选文本、拖放输入等来源的杂乱文本解析为确切存在的本地物理路径与可选目标行号。
public enum UniversalPathResolver {

    /// 解析一段输入文本为物理文件目标
    /// - Parameters:
    ///   - input: 待解析的字符串（可能包含路径、波浪号、引号、行号或混杂在自然语言中）
    ///   - fileManager: 文件管理器，默认为 `.default`，便于测试注入
    /// - Returns: 若能成功定位到实际存在的本地文件或目录，返回 `ResolvedPathTarget`，否则返回 `nil`
    public static func resolve(_ input: String, fileManager: FileManager = .default) -> ResolvedPathTarget? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. 优先尝试直接将整段输入作为路径解析（支持包裹引号、波浪号、file:// 与末尾行号）
        if let directHit = resolveSingleCandidate(trimmed, fileManager: fileManager) {
            return directHit
        }

        // 2. 宽松提取模式：如果整段输入没有直接命中，尝试从中检索可能潜藏的绝对路径/波浪号路径
        if let extracted = extractAndResolveEmbeddedPath(from: trimmed, fileManager: fileManager) {
            return extracted
        }

        return nil
    }

    // MARK: - 内部解析子流程

    /// 解析单个候选路径项
    private static func resolveSingleCandidate(_ candidate: String, fileManager: FileManager) -> ResolvedPathTarget? {
        let cleaned = stripEnclosingDelimiters(candidate)
        guard !cleaned.isEmpty else { return nil }

        // 1. 检查并分离行号与列号（如 /path/to/file.swift:142:5 或 ~/demo.py:88）
        let cliTarget = CLILineParser.parseTarget(cleaned)
        let rawPath = cliTarget.filePath
        let targetLine = cliTarget.line

        // 2. 规范化路径字符串
        guard let normalizedPath = normalizePathString(rawPath) else { return nil }

        // 3. 校验物理文件存在性
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: normalizedPath, isDirectory: &isDir) {
            return ResolvedPathTarget(
                fileURL: URL(fileURLWithPath: normalizedPath, isDirectory: isDir.boolValue),
                isDirectory: isDir.boolValue,
                targetLine: targetLine
            )
        }

        // 4. 若为相对路径，尝试基于当前工作目录校验
        if !normalizedPath.hasPrefix("/") {
            let currentDir = fileManager.currentDirectoryPath
            let combined = (currentDir as NSString).appendingPathComponent(normalizedPath)
            if fileManager.fileExists(atPath: combined, isDirectory: &isDir) {
                return ResolvedPathTarget(
                    fileURL: URL(fileURLWithPath: combined, isDirectory: isDir.boolValue),
                    isDirectory: isDir.boolValue,
                    targetLine: targetLine
                )
            }
        }

        return nil
    }

    /// 清洗首尾的包裹符号（如单双引号、反引号、括号等）
    private static func stripEnclosingDelimiters(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 循环去除可能的多层包裹（例如 "(`~/file.txt:10`)"）
        var modified = true
        while modified {
            modified = false

            // 去除首尾成对或单侧的引号
            if (str.hasPrefix("\"") && str.hasSuffix("\"")) ||
               (str.hasPrefix("'") && str.hasSuffix("'")) ||
               (str.hasPrefix("`") && str.hasSuffix("`")) {
                if str.count >= 2 {
                    str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    modified = true
                    continue
                }
            }

            // 去除成对的外层括号
            if (str.hasPrefix("(") && str.hasSuffix(")")) ||
               (str.hasPrefix("[") && str.hasSuffix("]")) ||
               (str.hasPrefix("<") && str.hasSuffix(">")) ||
               (str.hasPrefix("{") && str.hasSuffix("}")) {
                if str.count >= 2 {
                    str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    modified = true
                    continue
                }
            }
        }

        return str
    }

    /// 将原始字符串统一转换为标准 POSIX 物理路径
    private static func normalizePathString(_ raw: String) -> String? {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }

        // 处理 file:// 协议
        if path.hasPrefix("file://") {
            if let url = URL(string: path) {
                path = url.path
            } else {
                // 兜底剥离前缀并处理百分号转义
                let stripped = String(path.dropFirst("file://".count))
                path = stripped.removingPercentEncoding ?? stripped
            }
        }

        // 处理 ~ 波浪号展开
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }

        // 规范化标准路径（消除 /./ 与 /../）
        path = (path as NSString).standardizingPath
        return path.isEmpty ? nil : path
    }

    /// 从混杂的长文本中搜寻并尝试解析包含的绝对路径与波浪号路径
    private static func extractAndResolveEmbeddedPath(from text: String, fileManager: FileManager) -> ResolvedPathTarget? {
        // 匹配规则：
        // 1. 优先捕获被单双引号或反引号包裹的路径（允许路径内部包含空格），例如: "at '/Users/name/My Folder/file.swift:142'"
        // 2. 捕获未包裹的标准绝对路径与波浪号路径（无空格）
        let pattern = #"["'`]((?:~|/)[^"'`\n\r]+)["'`](?::\d+(?::\d+)?)?|(?<![a-zA-Z0-9_\-\.\/])(?:~|/)[a-zA-Z0-9_\-\.\/]+(?::\d+(?::\d+)?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        // 优先尝试更长、更具体的匹配项
        let candidates = matches.map { nsString.substring(with: $0.range) }
            .sorted { $0.count > $1.count }

        for candidate in candidates {
            if let target = resolveSingleCandidate(candidate, fileManager: fileManager) {
                return target
            }
        }

        return nil
    }
}
