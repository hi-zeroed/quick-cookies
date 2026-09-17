import Foundation

/// 命令行与直达跳转参数解析器
/// 负责将诸如 `path/to/file.swift:142`、`path/to/file.swift:142:5` 或显式指定行号解析为规范的文件路径与目标行号。
public struct CLILineTarget: Equatable {
    public let filePath: String
    public let line: Int?
    public let column: Int?

    public init(filePath: String, line: Int? = nil, column: Int? = nil) {
        self.filePath = filePath
        self.line = line
        self.column = column
    }
}

public enum CLILineParser {
    /// 从单个路径参数字符串解析路径、行号与列号
    /// 例如：
    /// - "App.swift" -> ("App.swift", nil, nil)
    /// - "App.swift:142" -> ("App.swift", 142, nil)
    /// - "App.swift:142:15" -> ("App.swift", 142, 15)
    /// - "/path/to:folder/App.swift:88" -> ("/path/to:folder/App.swift", 88, nil)
    public static func parseTarget(_ input: String) -> CLILineTarget {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CLILineTarget(filePath: "")
        }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return CLILineTarget(filePath: trimmed)
        }

        // 检查最后一段是否是纯数字
        let lastPart = String(parts.last!)
        if let lastNum = Int(lastPart), lastNum > 0 {
            // 倒数第二段是否也是纯数字（例如 file.swift:142:15 中的 142）
            if parts.count >= 3 {
                let secondLastPart = String(parts[parts.count - 2])
                if let lineNum = Int(secondLastPart), lineNum > 0 {
                    let path = parts[0..<(parts.count - 2)].joined(separator: ":")
                    return CLILineTarget(filePath: path, line: lineNum, column: lastNum)
                }
            }

            let path = parts[0..<(parts.count - 1)].joined(separator: ":")
            return CLILineTarget(filePath: path, line: lastNum, column: nil)
        }

        return CLILineTarget(filePath: trimmed)
    }

    /// 从命令行参数列表解析出目标路径与行号
    /// 支持参数形态：
    /// - ["file.swift:142"]
    /// - ["-l", "142", "file.swift"]
    /// - ["--line", "142", "file.swift"]
    /// - ["file.swift", "-l", "142"]
    public static func parseArguments(_ args: [String]) -> CLILineTarget? {
        var explicitLine: Int? = nil
        var targetCandidate: String? = nil

        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "-l" || arg == "--line" {
                if index + 1 < args.count, let line = Int(args[index + 1]), line > 0 {
                    explicitLine = line
                    index += 2
                    continue
                } else {
                    index += 1
                    continue
                }
            }

            if !arg.hasPrefix("-") && targetCandidate == nil {
                targetCandidate = arg
            }
            index += 1
        }

        guard let target = targetCandidate else {
            return nil
        }

        let parsed = parseTarget(target)
        let resolvedLine = explicitLine ?? parsed.line

        return CLILineTarget(
            filePath: parsed.filePath,
            line: resolvedLine,
            column: parsed.column
        )
    }
}
