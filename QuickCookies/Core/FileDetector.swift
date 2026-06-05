import Foundation
import AppKit

enum FileDetector {
    enum DetectError: Error, LocalizedError {
        case finderNotRunning
        case noFileSelected
        case scriptingBridgeError(String)

        var errorDescription: String? {
            switch self {
            case .finderNotRunning:
                return "请先打开 Finder"
            case .noFileSelected:
                return "未检测到选中文件 (Finder selection为空)"
            case .scriptingBridgeError(let message):
                return "调试诊断: \(message)"
            }
        }
    }

    /// 静态常驻预编译 AppleScript 对象，消除高频执行时的重复解析与编译开销
    private static let finderSelectionScript: NSAppleScript? = {
        let scriptText = """
        tell application "Finder"
            set theSelection to selection
            if theSelection is not {} then
                try
                    return POSIX path of (item 1 of theSelection as alias)
                on error
                    return ""
                end try
            else
                if (count of Finder windows) > 0 then
                    try
                        return POSIX path of (target of window 1 as alias)
                    on error
                        return ""
                    end try
                end if
            end if
        end tell
        """
        return NSAppleScript(source: scriptText)
    }()

    /// 获取 Finder 当前选中的文件路径（使用高性能进程内 NSAppleScript，无缓存 Bug，零子进程）
    static func getSelectedFilePath() -> Result<String, DetectError> {
        // 检查 Finder 是否运行
        guard isFinderRunning() else {
            return .failure(.finderNotRunning)
        }

        guard let script = finderSelectionScript else {
            return .failure(.scriptingBridgeError("无法初始化 AppleScript 脚本"))
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error = error {
            let errorMsg = error["NSAppleScriptErrorMessage"] as? String ?? "未知 AppleScript 错误"
            return .failure(.scriptingBridgeError(errorMsg))
        }

        let path = descriptor.stringValue ?? ""
        if path.isEmpty {
            return .failure(.noFileSelected)
        }

        return .success(path)
    }

    /// 检查 Finder 是否运行
    private static func isFinderRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.finder"
        }
    }
}