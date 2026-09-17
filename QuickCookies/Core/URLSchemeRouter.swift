import Foundation

/// QuickCookies URL Scheme 路由指令
public enum URLSchemeAction: Equatable {
    /// 打开指定文件预览（支持指定行号）
    case openFile(path: String, line: Int?)
    /// 直达代码卡片工坊（可选指定目标文件，若为 nil 则嗅探剪贴板或访达选中）
    case openShareCard(path: String?)
    /// 透视剪贴板内容（代码/文本/JSON/图片）
    case inspectClipboard
    /// 透视当前访达（Finder）选中的文件
    case triggerFinderSelection
}

/// QuickCookies URL Scheme 路由解析器
/// 支持将 `quickcookies://preview?...` 解析为明确的业务动作，零 UI/系统强耦合。
public enum URLSchemeRouter {
    public static func parse(url: URL) -> URLSchemeAction? {
        guard url.scheme == "quickcookies", url.host == "preview" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        let action = queryItems.first(where: { $0.name == "action" })?.value
        let mode = queryItems.first(where: { $0.name == "mode" })?.value
        let source = queryItems.first(where: { $0.name == "source" })?.value
        let path = queryItems.first(where: { $0.name == "path" })?.value
        let line = queryItems.first(where: { $0.name == "line" })?.value.flatMap(Int.init)

        // 1. 卡片工坊直达：action=shareCard 或 mode=card
        if action == "shareCard" || mode == "card" {
            let validPath = (path?.isEmpty == false) ? path : nil
            return .openShareCard(path: validPath)
        }

        // 2. 剪贴板透视: source=clipboard
        if source == "clipboard" {
            return .inspectClipboard
        }

        // 3. 指定路径预览: path=...
        if let path = path, !path.isEmpty {
            return .openFile(path: path, line: line)
        }

        // 4. 透视当前访达选中的文件: action=finderSelection 或空 query
        if action == "finderSelection" || queryItems.isEmpty {
            return .triggerFinderSelection
        }

        return nil
    }
}
