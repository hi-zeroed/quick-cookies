import AppKit
import Foundation

/// 表示一个可用于接力打开当前文件的外部应用程序
public struct RelayApp: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let shortName: String
    public let bundleIdentifier: String?
    public let url: URL
    public let icon: NSImage
    public let isDefault: Bool

    public init(
        id: String,
        name: String,
        shortName: String,
        bundleIdentifier: String?,
        url: URL,
        icon: NSImage,
        isDefault: Bool
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.icon = icon
        self.isDefault = isDefault
    }

    public static func == (lhs: RelayApp, rhs: RelayApp) -> Bool {
        lhs.id == rhs.id && lhs.isDefault == rhs.isDefault
    }
}

/// 外部应用接力管理器，负责查询系统默认应用、候选编辑器、并执行外部打开
public final class ExternalAppRelay {
    public static let shared = ExternalAppRelay()

    public init() {}

    /// 已知常用开发、设计与办公编辑器的优先级及短名称映射表
    private static let knownEditorShortNames: [String: (shortName: String, priority: Int)] = [
        "com.microsoft.VSCode": ("VS Code", 100),
        "com.microsoft.VSCodeInsiders": ("VS Code Insiders", 99),
        "com.todesktop.230313mzl4w4u92": ("Cursor", 98), // Cursor IDE Bundle ID
        "com.apple.dt.Xcode": ("Xcode", 97),
        "dev.zed.Zed": ("Zed", 96),
        "abnerworks.Typora": ("Typora", 95),
        "md.obsidian": ("Obsidian", 94),
        "com.sublimetext.4": ("Sublime Text", 93),
        "com.sublimetext.3": ("Sublime Text", 93),
        "com.jetbrains.intellij": ("IntelliJ IDEA", 90),
        "com.jetbrains.intellij.ce": ("IntelliJ IDEA CE", 90),
        "com.jetbrains.webstorm": ("WebStorm", 89),
        "com.jetbrains.pycharm": ("PyCharm", 88),
        "com.jetbrains.pycharm.ce": ("PyCharm CE", 88),
        "com.jetbrains.goland": ("GoLand", 87),
        "com.jetbrains.CLion": ("CLion", 86),
        "com.jetbrains.rider": ("Rider", 85),
        "com.panic.Nova": ("Nova", 84),
        "org.vim.MacVim": ("MacVim", 83),
        "com.coteditor.CotEditor": ("CotEditor", 82),
        "com.barebones.bbedit": ("BBEdit", 81),
        "com.apple.TextEdit": ("TextEdit", 70),
        "com.apple.Preview": ("Preview", 60),
        "com.apple.iWork.Pages": ("Pages", 60),
        "com.apple.iWork.Numbers": ("Numbers", 60),
        "com.apple.iWork.Keynote": ("Keynote", 60),
        "com.microsoft.Word": ("Word", 60),
        "com.microsoft.Excel": ("Excel", 60),
        "com.microsoft.Powerpoint": ("PowerPoint", 60),
        "com.google.Chrome": ("Chrome", 50),
        "com.apple.Safari": ("Safari", 50),
    ]

    /// 获取指定文件的默认打开应用以及候选应用列表（已去重并按相关性排序）
    public func getApps(for fileURL: URL) -> (defaultApp: RelayApp?, candidates: [RelayApp]) {
        let workspace = NSWorkspace.shared

        // 1. 获取系统默认打开 App 的 URL
        let defaultAppURL = workspace.urlForApplication(toOpen: fileURL)

        var defaultRelayApp: RelayApp? = nil
        if let defaultURL = defaultAppURL {
            defaultRelayApp = createAppModel(from: defaultURL, isDefault: true)
        }

        // 2. 获取能够打开该文件的所有候选 App URL 列表
        let candidateURLs = workspace.urlsForApplications(toOpen: fileURL)
        
        var apps: [RelayApp] = []
        var seenBundleIds = Set<String>()
        var seenPaths = Set<String>()

        // 记录默认 App 的特征以防重复
        if let defaultApp = defaultRelayApp {
            if let bid = defaultApp.bundleIdentifier {
                seenBundleIds.insert(bid.lowercased())
            }
            seenPaths.insert(defaultApp.url.path.lowercased())
        }

        for appURL in candidateURLs {
            let pathLower = appURL.path.lowercased()
            let bundleId = Bundle(url: appURL)?.bundleIdentifier?.lowercased()

            // 过滤重复应用
            if let bid = bundleId, seenBundleIds.contains(bid) {
                continue
            }
            if seenPaths.contains(pathLower) {
                continue
            }

            if let bid = bundleId {
                seenBundleIds.insert(bid)
            }
            seenPaths.insert(pathLower)

            if let app = createAppModel(from: appURL, isDefault: false) {
                apps.append(app)
            }
        }

        // 3. 对候选列表按权重智能排序（已知常用编辑器置顶，其余按名称字母排序）
        let sortedCandidates = apps.sorted { app1, app2 in
            let p1 = priority(for: app1)
            let p2 = priority(for: app2)
            if p1 != p2 {
                return p1 > p2
            }
            return app1.name.localizedStandardCompare(app2.name) == .orderedAscending
        }

        return (defaultRelayApp, sortedCandidates)
    }

    /// 使用指定的外部应用打开文件
    @discardableResult
    public func open(fileURL: URL, with app: RelayApp) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true

        NSWorkspace.shared.open([fileURL], withApplicationAt: app.url, configuration: configuration) { _, error in
            if let error = error {
                NSLog("[ExternalAppRelay] Failed to open %@ with %@: %@", fileURL.path, app.name, error.localizedDescription)
            }
        }
        return true
    }

    /// 使用系统默认应用打开文件
    @discardableResult
    public func openWithDefault(fileURL: URL) -> Bool {
        if let defaultURL = NSWorkspace.shared.urlForApplication(toOpen: fileURL) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = true
            NSWorkspace.shared.open([fileURL], withApplicationAt: defaultURL, configuration: configuration, completionHandler: nil)
            return true
        } else {
            return NSWorkspace.shared.open(fileURL)
        }
    }

    /// 在 Finder 中高亮显示文件
    public func revealInFinder(fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    /// 在终端（Terminal / iTerm2）中打开指定目录
    @discardableResult
    public func openInTerminal(directoryURL: URL) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        if let itermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
            NSWorkspace.shared.open([directoryURL], withApplicationAt: itermURL, configuration: configuration, completionHandler: nil)
            return true
        }

        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open([directoryURL], withApplicationAt: terminalURL, configuration: configuration, completionHandler: nil)
            return true
        }

        return NSWorkspace.shared.open(directoryURL)
    }

    /// 复制文件路径至剪贴板
    public func copyPathToClipboard(fileURL: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileURL.path, forType: .string)
    }

    /// 根据 Bundle ID 获取已知应用的友好短名称
    public static func shortName(forBundleIdentifier bundleId: String?, defaultName: String) -> String {
        if let bid = bundleId, let known = knownEditorShortNames[bid] {
            return known.shortName
        }
        if defaultName.hasSuffix(".app") {
            return String(defaultName.dropLast(4))
        }
        return defaultName
    }

    /// 根据 Bundle ID 获取编辑器的排序优先级分数
    public static func priorityScore(forBundleIdentifier bundleId: String?) -> Int {
        if let bid = bundleId, let known = knownEditorShortNames[bid] {
            return known.priority
        }
        return 0
    }

    // MARK: - Private Helpers

    public func createAppModel(from appURL: URL, isDefault: Bool) -> RelayApp? {
        let bundle = Bundle(url: appURL)
        let bundleIdentifier = bundle?.bundleIdentifier

        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        let shortName = Self.shortName(forBundleIdentifier: bundleIdentifier, defaultName: displayName)

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)

        let id = bundleIdentifier ?? appURL.path

        return RelayApp(
            id: id,
            name: displayName,
            shortName: shortName,
            bundleIdentifier: bundleIdentifier,
            url: appURL,
            icon: icon,
            isDefault: isDefault
        )
    }

    private func priority(for app: RelayApp) -> Int {
        Self.priorityScore(forBundleIdentifier: app.bundleIdentifier)
    }
}
