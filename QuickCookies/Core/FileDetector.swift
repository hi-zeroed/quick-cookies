import Foundation
import AppKit

enum FileDetector {
    enum DetectError: Error, LocalizedError {
        case finderNotRunning
        case noFileSelected
        case appleScriptError(String)

        var errorDescription: String? {
            switch self {
            case .finderNotRunning:
                return "请先打开 Finder"
            case .noFileSelected:
                return "未检测到选中文件 (Finder selection为空)"
            case .appleScriptError(let message):
                return "调试诊断: \(message)"
            }
        }
    }

    /// 获取 Finder 当前选中的文件路径
    static func getSelectedFilePath() -> Result<String, DetectError> {
        // 检查 Finder 是否运行
        guard isFinderRunning() else {
            return .failure(.finderNotRunning)
        }

        // 执行高兼容性 AppleScript，获取选中项或窗口目标的 URL 属性，避免 as text 强转报错
        let script = """
        tell application "Finder"
            try
                set sel to selection
                if sel is {} then
                    if window 1 exists then
                        set selItem to target of window 1
                    else
                        return ""
                    end if
                else
                    set selItem to item 1 of sel
                end if
                return url of selItem
            on error errText number errNum
                return "SCRIPT_ERROR:" & errNum & ":" & errText
            end try
        end tell
        """

        switch runAppleScript(script) {
        case .success(let urlString):
            if urlString.hasPrefix("SCRIPT_ERROR:") {
                return .failure(.appleScriptError(urlString))
            }
            guard let url = URL(string: urlString) else {
                return .failure(.appleScriptError("无法将 Finder 返回值解析为URL: \(urlString)"))
            }
            let path = url.path
            return .success(path)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// 检查 Finder 是否运行
    private static func isFinderRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.finder"
        }
    }

    /// 使用 Process 子进程独立运行 osascript，避开主线程 AppleEvent 死锁
    private static func runAppleScript(_ source: String) -> Result<String, DetectError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
                return .failure(.appleScriptError("osascript 退出码 [\(process.terminationStatus)]: \(errMsg)"))
            }
            
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
            if output.isEmpty {
                return .failure(.noFileSelected)
            }
            return .success(output)
        } catch {
            return .failure(.appleScriptError("执行 osascript 失败: \(error.localizedDescription)"))
        }
    }
}