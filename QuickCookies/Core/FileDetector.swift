import Foundation
import AppKit
import ScriptingBridge

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

    /// 获取 Finder 当前选中的文件路径（使用高性能 Scripting Bridge，内存级 IPC，零子进程）
    static func getSelectedFilePath() -> Result<String, DetectError> {
        // 检查 Finder 是否运行
        guard isFinderRunning() else {
            return .failure(.finderNotRunning)
        }

        guard let finderApp = SBApplication(bundleIdentifier: "com.apple.finder") else {
            return .failure(.scriptingBridgeError("无法获取 Finder 脚本桥实例"))
        }

        // 1. 尝试获取选中项
        if let selection = finderApp.value(forKey: "selection") as? SBObject,
           let items = selection.get() as? [AnyObject],
           !items.isEmpty {
            let firstItem = items[0]
            if let urlString = firstItem.value?(forKey: "URL") as? String {
                return parseUrlString(urlString)
            }
        }

        // 2. 兜底：如果未选中任何项，且有打开的 Finder 窗口，则使用最前窗口的 target 路径
        if let windows = finderApp.value(forKey: "FinderWindows") as? SBElementArray,
           windows.count > 0,
           let firstWindow = windows.object(at: 0) as? SBObject,
           let target = firstWindow.value(forKey: "target") as? SBObject,
           let urlString = target.value(forKey: "URL") as? String {
            return parseUrlString(urlString)
        }

        return .failure(.noFileSelected)
    }

    private static func parseUrlString(_ urlString: String) -> Result<String, DetectError> {
        guard let url = URL(string: urlString) else {
            return .failure(.scriptingBridgeError("无法解析 Finder 返回的 URL: \(urlString)"))
        }
        return .success(url.path)
    }

    /// 检查 Finder 是否运行
    private static func isFinderRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.finder"
        }
    }
}