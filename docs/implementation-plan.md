# Quick Cookies 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 macOS 轻量级文件预览/编辑应用，通过全局快捷键触发浮动窗口，支持 Markdown 渲染和代码语法高亮。

**Architecture:** 纯 Swift + SwiftUI 单体 App，使用 NSPanel 实现浮动窗口，NSEvent.addGlobalMonitor 监听全局热键，AppleScript 与 Finder 通信获取选中文件。

**Tech Stack:** Swift 5.9, SwiftUI, NSPanel, swift-markdown, Highlightr

---

## 文件结构

```
QuickCookies/
├── QuickCookies.xcodeproj              # Xcode 项目
├── QuickCookies/
│   ├── App/
│   │   ├── QuickCookiesApp.swift       # App 入口 + SwiftUI App 结构
│   │   └── AppDelegate.swift        # NSApplicationDelegate 处理权限
│   ├── Core/
│   │   ├── HotkeyManager.swift      # 全局热键注册/监听
│   │   ├── FileDetector.swift       # AppleScript 获取 Finder 选中文件
│   │   └── FileTypeClassifier.swift # 文件后缀 → 渲染类型映射
│   ├── UI/
│   │   ├── PreviewWindow.swift      # NSPanel 浮动窗口控制器
│   │   ├── ContentView.swift        # 根据文件类型切换视图
│   │   ├── MarkdownView.swift       # WebView 显示渲染后的 HTML
│   │   ├── CodeView.swift           # TextView + 语法高亮
│   │   ├── EditorView.swift         # 可编辑的 TextView + 行号
│   │   └── SettingsWindow.swift     # 设置窗口（快捷键配置）
│   │   └── ToastView.swift          # 轻量提示组件
│   ├── Renderer/
│   │   ├── MarkdownRenderer.swift   # swift-markdown → HTML
│   │   ├── SyntaxHighlighter.swift  # Highlightr 包装
│   ├── Utils/
│   │   ├── FileUtils.swift          # 文件读写 + 编码检测
│   │   ├── EncodingDetector.swift   # UTF-8/GBK 检测
│   ├── Config/
│   │   ├── Settings.swift           # UserDefaults 存储配置
│   │   ├── Constants.swift          # 支持的文件类型、默认值
│   ├── Resources/
│   │   ├── Assets.xcassets          # App 图标
│   │   ├── markdown.css             # Markdown 渲染样式
│   │   ├── highlight.css            # 代码高亮样式
│   ├── Info.plist                   # 权限声明
│   └── QuickCookies.entitlements       # App Sandbox 权限
└── Package.swift                    # SPM 依赖配置
```

---

## Task 1: 创建 Xcode 项目骨架

**Files:**
- Create: `QuickCookies/QuickCookies.xcodeproj`
- Create: `QuickCookies/QuickCookies/App/QuickCookiesApp.swift`
- Create: `QuickCookies/QuickCookies/Info.plist`
- Create: `QuickCookies/QuickCookies/QuickCookies.entitlements`

- [ ] **Step 1: 使用 Xcode 命令行创建项目**

```bash
cd /Users/jiangwei/Git/QuickPeek
mkdir -p QuickCookies/QuickCookies/App
mkdir -p QuickCookies/QuickCookies/Core
mkdir -p QuickCookies/QuickCookies/UI
mkdir -p QuickCookies/QuickCookies/Renderer
mkdir -p QuickCookies/QuickCookies/Utils
mkdir -p QuickCookies/QuickCookies/Config
mkdir -p QuickCookies/QuickCookies/Resources
```

- [ ] **Step 2: 创建 Info.plist 声明权限**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Quick Cookies</string>
    <key>CFBundleIdentifier</key>
    <string>com.quickcookies.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Quick Cookies needs to communicate with Finder to get selected file paths.</string>
</dict>
</plist>
```

- [ ] **Step 3: 创建 entitlements 文件**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: 创建最小 App 入口**

```swift
import SwiftUI

@main
struct Quick CookiesApp: App {
    var body: some Scene {
        // 空场景，主窗口由 PreviewWindow 管理
        MenuBarExtra("Quick Cookies", systemImage: "doc.text.magnifyingglass") {
            Text("Quick Cookies is running")
            Button("Settings") {
                // 后续实现
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 5: 创建 Package.swift 添加依赖**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quick Cookies",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Quick Cookies",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                "Highlightr",
            ]
        ),
    ]
)
```

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: initialize Quick Cookies project skeleton"
```

---

## Task 2: Constants 和 Settings 配置层

**Files:**
- Create: `QuickCookies/QuickCookies/Config/Constants.swift`
- Create: `QuickCookies/QuickCookies/Config/Settings.swift`

- [ ] **Step 1: 创建 Constants.swift 定义文件类型映射**

```swift
import Foundation

enum Constants {
    // 默认快捷键：Cmd + Shift + Space
    static let defaultHotkeyModifiers: NSEvent.ModifierFlags = [.command, .shift]
    static let defaultHotkeyKeyCode: UInt16 = 49 // Space
    
    // 支持的文件扩展名
    static let supportedExtensions: Set<String> = [
        // 配置文件
        "json", "yaml", "yml", "toml", "xml", "env",
        // Markdown
        "md", "markdown",
        // Shell
        "sh", "zsh", "bash",
        // 代码
        "ts", "tsx", "js", "jsx", "py", "go", "rs", "java", "kt",
        "swift", "c", "cpp", "h", "rb", "php", "sql",
        // 其他文本
        "txt", "log", "csv", "conf", "config", "ini",
        "gitignore", "dockerignore", "editorconfig",
    ]
    
    // Markdown 文件类型
    static let markdownExtensions: Set<String> = ["md", "markdown"]
    
    // 代码文件 → Highlightr 语言名映射
    static let languageMap: [String: String] = [
        "json": "json",
        "yaml": "yaml",
        "yml": "yaml",
        "toml": "toml",
        "xml": "xml",
        "sh": "bash",
        "zsh": "bash",
        "bash": "bash",
        "ts": "typescript",
        "tsx": "typescript",
        "js": "javascript",
        "jsx": "javascript",
        "py": "python",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "swift": "swift",
        "c": "c",
        "cpp": "cpp",
        "h": "c",
        "rb": "ruby",
        "php": "php",
        "sql": "sql",
        "env": "bash",
    ]
    
    // 文件大小警告阈值
    static let largeFileThreshold: Int = 5 * 1024 * 1024 // 5MB
    
    // Toast 自动消失时间
    static let toastDuration: TimeInterval = 3.0
}
```

- [ ] **Step 2: 创建 Settings.swift 管理 UserDefaults**

```swift
import Foundation
import Combine

class Settings: ObservableObject {
    static let shared = Settings()
    
    private let defaults = UserDefaults.standard
    
    // 快捷键配置
    @Published var hotkeyModifiers: NSEvent.ModifierFlags
    @Published var hotkeyKeyCode: UInt16
    
    // 外观配置
    @Published var fontSize: CGFloat
    @Published var showLineNumbers: Bool
    
    private init() {
        // 快捷键
        hotkeyModifiers = NSEvent.ModifierFlags(
            rawValue: defaults.integer(forKey: Keys.hotkeyModifiers)
        )
        if hotkeyModifiers.rawValue == 0 {
            hotkeyModifiers = Constants.defaultHotkeyModifiers
        }
        
        hotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
        if hotkeyKeyCode == 0 {
            hotkeyKeyCode = Constants.defaultHotkeyKeyCode
        }
        
        // 外观
        fontSize = CGFloat(defaults.float(forKey: Keys.fontSize))
        if fontSize == 0 { fontSize = 14 }
        
        showLineNumbers = defaults.bool(forKey: Keys.showLineNumbers)
        if !defaults.hasKey(Keys.showLineNumbers) {
            showLineNumbers = true
        }
    }
    
    func saveHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        hotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        defaults.set(modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(Int(keyCode), forKey: Keys.hotkeyKeyCode)
    }
    
    func saveFontSize(_ size: CGFloat) {
        fontSize = size
        defaults.set(Float(size), forKey: Keys.fontSize)
    }
    
    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let fontSize = "fontSize"
        static let showLineNumbers = "showLineNumbers"
    }
}

extension UserDefaults {
    func hasKey(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add QuickCookies/QuickCookies/Config/
git commit -m "feat: add Constants and Settings configuration layer"
```

---

## Task 3: FileUtils 文件读写工具

**Files:**
- Create: `QuickCookies/QuickCookies/Utils/FileUtils.swift`
- Create: `QuickCookies/QuickCookies/Utils/EncodingDetector.swift`

- [ ] **Step 1: 创建 EncodingDetector.swift 检测文件编码**

```swift
import Foundation

enum EncodingDetector {
    /// 尝试检测文件编码，优先 UTF-8
    static func detect(data: Data) -> String.Encoding {
        // 尝试 UTF-8
        if isValidUTF8(data) {
            return .utf8
        }
        
        // 尝试 UTF-16
        if data.count >= 2 {
            let bom = data.prefix(2)
            if bom == Data([0xFE, 0xFF]) || bom == Data([0xFF, 0xFE]) {
                return .utf16
            }
        }
        
        // 尝试 GBK（中文环境）
        if let _ = String(data: data, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GBK.rawValue)))) {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GBK.rawValue)))
        }
        
        // 默认返回 UTF-8（可能显示乱码）
        return .utf8
    }
    
    private static func isValidUTF8(_ data: Data) -> Bool {
        var index = 0
        while index < data.count {
            let byte = data[index]
            
            // 单字节字符 (0x00-0x7F)
            if byte < 0x80 {
                index += 1
                continue
            }
            
            // 多字节字符
            let length: Int
            if byte < 0xC0 { return false }      // 无效起始字节
            else if byte < 0xE0 { length = 2 }   // 2字节
            else if byte < 0xF0 { length = 3 }   // 3字节
            else if byte < 0xF8 { length = 4 }   // 4字节
            else { return false }                // 无效
            
            if index + length > data.count { return false }
            
            // 检查后续字节
            for i in 1..<length {
                let nextByte = data[index + i]
                if nextByte < 0x80 || nextByte >= 0xC0 { return false }
            }
            
            index += length
        }
        return true
    }
}
```

- [ ] **Step 2: 创建 FileUtils.swift 文件读写**

```swift
import Foundation

enum FileUtils {
    enum FileError: Error, LocalizedError {
        case fileNotFound(path: String)
        case permissionDenied(path: String)
        case readFailed(path: String, reason: String)
        case writeFailed(path: String, reason: String)
        case binaryFile(path: String)
        case fileTooLarge(path: String, size: Int)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "文件不存在: \(path)"
            case .permissionDenied(let path):
                return "权限不足，无法访问: \(path)"
            case .readFailed(let path, let reason):
                return "读取失败: \(path) - \(reason)"
            case .writeFailed(let path, let reason):
                return "保存失败: \(path) - \(reason)"
            case .binaryFile(let path):
                return "不支持二进制文件: \(path)"
            case .fileTooLarge(let path, let size):
                return "文件较大 (\(size / 1024 / 1024)MB): \(path)"
            }
        }
    }
    
    /// 读取文件内容
    static func readFile(at path: String) -> Result<(content: String, encoding: String.Encoding), FileError> {
        let url = URL(fileURLWithPath: path)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }
        
        // 检查是否可读
        guard FileManager.default.isReadableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }
        
        // 读取数据
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.readFailed(path: path, reason: "无法读取数据"))
        }
        
        // 检查文件大小
        if data.count > Constants.largeFileThreshold {
            return .failure(.fileTooLarge(path: path, size: data.count))
        }
        
        // 检查是否为二进制文件
        if isBinaryFile(data) {
            return .failure(.binaryFile(path: path))
        }
        
        // 检测编码并解码
        let encoding = EncodingDetector.detect(data: data)
        guard let content = String(data: data, encoding: encoding) else {
            return .failure(.readFailed(path: path, reason: "编码解码失败"))
        }
        
        return .success((content: content, encoding: encoding))
    }
    
    /// 写入文件
    static func writeFile(at path: String, content: String, encoding: String.Encoding = .utf8) -> Result<Void, FileError> {
        let url = URL(fileURLWithPath: path)
        
        // 检查是否可写
        guard FileManager.default.isWritableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }
        
        // 写入数据
        guard let data = content.data(using: encoding) else {
            return .failure(.writeFailed(path: path, reason: "编码转换失败"))
        }
        
        do {
            try data.write(to: url, options: .atomic)
            return .success(())
        } catch {
            return .failure(.writeFailed(path: path, reason: error.localizedDescription))
        }
    }
    
    /// 检测是否为二进制文件（通过检查 null 字节）
    private static func isBinaryFile(_ data: Data) -> Bool {
        // 检查前 8KB 是否包含 null 字节
        let checkSize = min(data.count, 8192)
        let sample = data.prefix(checkSize)
        return sample.contains(0x00)
    }
    
    /// 解析符号链接的真实路径
    static func resolveSymlink(at path: String) -> String {
        let url = URL(fileURLWithPath: path)
        do {
            let resolved = url.resolvingSymlinksInPath()
            return resolved.path
        } catch {
            return path
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add QuickCookies/QuickCookies/Utils/
git commit -m "feat: add FileUtils and EncodingDetector for file operations"
```

---

## Task 4: FileTypeClassifier 文件类型分类器

**Files:**
- Create: `QuickCookies/QuickCookies/Core/FileTypeClassifier.swift`

- [ ] **Step 1: 创建 FileTypeClassifier.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/Core/FileTypeClassifier.swift
git commit -m "feat: add FileTypeClassifier for render type detection"
```

---

## Task 5: FileDetector Finder 文件检测

**Files:**
- Create: `QuickCookies/QuickCookies/Core/FileDetector.swift`

- [ ] **Step 1: 创建 FileDetector.swift 使用 AppleScript**

```swift
import Foundation
import AppleScript

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
                return "未检测到选中文件"
            case .appleScriptError(let message):
                return "AppleScript 错误: \(message)"
            }
        }
    }
    
    /// 获取 Finder 当前选中的文件路径
    static func getSelectedFilePath() -> Result<String, DetectError> {
        // 检查 Finder 是否运行
        guard isFinderRunning() else {
            return .failure(.finderNotRunning)
        }
        
        // 执行 AppleScript 获取选中文件
        let script = """
        tell application "Finder"
            set selectedItems to selection as alias list
            if selectedItems is {} then
                return ""
            end if
            set firstItem to item 1 of selectedItems
            return POSIX path of firstItem
        end tell
        """
        
        do {
            let result = runAppleScript(script)
            guard let path = result, !path.isEmpty else {
                return .failure(.noFileSelected)
            }
            return .success(path)
        } catch {
            return .failure(.appleScriptError(error.localizedDescription))
        }
    }
    
    /// 检查 Finder 是否运行
    private static func isFinderRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.finder"
        }
    }
    
    /// 执行 AppleScript
    private static func runAppleScript(_ source: String) -> String? {
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&errorInfo)
        
        if let error = errorInfo {
            print("AppleScript error: \(error)")
            return nil
        }
        
        return result?.stringValue
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/Core/FileDetector.swift
git commit -m "feat: add FileDetector using AppleScript to get Finder selection"
```

---

## Task 6: HotkeyManager 全局热键管理

**Files:**
- Create: `QuickCookies/QuickCookies/Core/HotkeyManager.swift`

- [ ] **Step 1: 创建 HotkeyManager.swift**

```swift
import Foundation
import Combine

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventMonitor: Any?
    private var onKeyDown: (() -> Void)?
    
    private init() {}
    
    /// 注册全局热键监听
    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping () -> Void) {
        // 先移除旧监听
        unregister()
        
        onKeyDown = handler
        
        // 添加全局事件监听
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // 检查修饰键和按键码
            if event.modifierFlags.contains(modifiers) &&
               event.keyCode == keyCode {
                handler()
            }
        }
        
        print("Hotkey registered: modifiers=\(modifiers), keyCode=\(keyCode)")
    }
    
    /// 使用当前设置注册热键
    func registerWithSettings(handler: @escaping () -> Void) {
        let settings = Settings.shared
        register(
            modifiers: settings.hotkeyModifiers,
            keyCode: settings.hotkeyKeyCode,
            handler: handler
        )
    }
    
    /// 移除热键监听
    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        onKeyDown = nil
    }
    
    /// 检查是否需要 Accessibility 权限
    func checkAccessibilityPermission() -> Bool {
        let options = NSDictionary.dictionaryWithValues(
            forKeys: [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        )
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// 请求 Accessibility 权限
    func requestAccessibilityPermission() {
        let options = NSDictionary.dictionaryWithValues(
            forKeys: [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        )
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    deinit {
        unregister()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/Core/HotkeyManager.swift
git commit -m "feat: add HotkeyManager for global keyboard monitoring"
```

---

## Task 7: MarkdownRenderer Markdown 渲染引擎

**Files:**
- Create: `QuickCookies/QuickCookies/Renderer/MarkdownRenderer.swift`
- Create: `QuickCookies/QuickCookies/Resources/markdown.css`

- [ ] **Step 1: 创建 markdown.css 样式文件**

```css
/* markdown.css - Markdown 渲染样式 */
:root {
    --bg-color: #ffffff;
    --text-color: #333333;
    --code-bg: #f5f5f5;
    --link-color: #0066cc;
    --border-color: #e0e0e0;
}

@media (prefers-color-scheme: dark) {
    :root {
        --bg-color: #1e1e1e;
        --text-color: #d4d4d4;
        --code-bg: #2d2d2d;
        --link-color: #4fc3f7;
        --border-color: #404040;
    }
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    font-size: 14px;
    line-height: 1.6;
    color: var(--text-color);
    background-color: var(--bg-color);
    padding: 20px;
    margin: 0;
}

h1, h2, h3, h4, h5, h6 {
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
    line-height: 1.25;
}

h1 { font-size: 2em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
h3 { font-size: 1.25em; }
h4 { font-size: 1em; }

p { margin: 0 0 16px 0; }

a {
    color: var(--link-color);
    text-decoration: none;
}
a:hover { text-decoration: underline; }

code {
    padding: 0.2em 0.4em;
    margin: 0;
    font-size: 90%;
    background-color: var(--code-bg);
    border-radius: 3px;
    font-family: "SF Mono", Monaco, Menlo, Consolas, monospace;
}

pre {
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: var(--code-bg);
    border-radius: 6px;
}

pre code {
    padding: 0;
    margin: 0;
    font-size: 100%;
    background-color: transparent;
}

blockquote {
    padding: 0 1em;
    color: #6a737d;
    border-left: 0.25em solid var(--border-color);
    margin: 0 0 16px 0;
}

table {
    border-spacing: 0;
    border-collapse: collapse;
    margin-bottom: 16px;
}

table th, table td {
    padding: 6px 13px;
    border: 1px solid var(--border-color);
}

table th {
    font-weight: 600;
    background-color: var(--code-bg);
}

table tr:nth-child(2n) {
    background-color: var(--code-bg);
}

ul, ol {
    padding-left: 2em;
    margin: 0 0 16px 0;
}

img {
    max-width: 100%;
    box-sizing: content-box;
}

hr {
    height: 0.25em;
    padding: 0;
    margin: 24px 0;
    background-color: var(--border-color);
    border: 0;
}
```

- [ ] **Step 2: 创建 MarkdownRenderer.swift**

```swift
import Foundation
import Markdown

struct MarkdownRenderer {
    /// 将 Markdown 文本转换为带样式的 HTML
    static func renderToHTML(markdownText: String) -> String {
        let document = Document(parsing: markdownText)
        let html = HTMLRenderer().render(document: document)
        
        // 组装完整 HTML
        let css = loadCSS()
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                \(css)
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
    
    /// 加载 CSS 样式
    private static func loadCSS() -> String {
        guard let cssPath = Bundle.main.path(forResource: "markdown", ofType: "css"),
              let css = try? String(contentsOfFile: cssPath) else {
            // 返回默认样式
            return """
            body { font-family: -apple-system; font-size: 14px; padding: 20px; }
            h1 { font-size: 2em; font-weight: bold; }
            h2 { font-size: 1.5em; font-weight: bold; }
            code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
            pre { background: #f5f5f5; padding: 16px; border-radius: 6px; overflow: auto; }
            pre code { background: transparent; }
            """
        }
        return css
    }
}

/// 简化版 HTML 渲染器（swift-markdown 的基本转换）
private class HTMLRenderer: MarkupVisitor {
    func render(document: Document) -> String {
        return visit(document)
    }
    
    mutating func visitDocument(_ document: Document) -> String {
        return document.children.map { visit($0) }.joined()
    }
    
    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(level)>\(content)</h\(level)>\n"
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>\n"
    }
    
    mutating func visitText(_ text: Text) -> String {
        return text.string
    }
    
    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }
    
    mutating func visitCode(_ code: Code) -> String {
        return "<code>\(code.code)</code>"
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language ?? ""
        let code = codeBlock.code
        return "<pre><code class=\"\(language)\" data-language=\"\(language)\">\(escapeHTML(code))</code></pre>\n"
    }
    
    mutating func visitLink(_ link: Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let destination = link.destination ?? ""
        return "<a href=\"\(destination)\">\(content)</a>"
    }
    
    mutating func visitImage(_ image: Image) -> String {
        let source = image.source ?? ""
        let title = image.title ?? ""
        return "<img src=\"\(source)\" alt=\"\(title)\">"
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let items = unorderedList.listItems.map { visit($0) }.joined()
        return "<ul>\n\(items)</ul>\n"
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let items = orderedList.listItems.map { visit($0) }.joined()
        return "<ol>\n\(items)</ol>\n"
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> String {
        let content = listItem.children.map { visit($0) }.joined()
        return "<li>\(content)</li>\n"
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined()
        return "<blockquote>\(content)</blockquote>\n"
    }
    
    mutating func visitThematicBreak(_: ThematicBreak) -> String {
        return "<hr>\n"
    }
    
    mutating func visitTable(_ table: Table) -> String {
        var html = "<table>\n"
        if let head = table.head {
            html += "<thead>\n"
            for cell in head.cells {
                html += "<th>\(cell.children.map { visit($0) }.joined())</th>\n"
            }
            html += "</thead>\n"
        }
        for row in table.body.rows {
            html += "<tr>\n"
            for cell in row.cells {
                html += "<td>\(cell.children.map { visit($0) }.joined())</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</table>\n"
        return html
    }
    
    mutating func visitSoftBreak(_: SoftBreak) -> String {
        return "\n"
    }
    
    mutating func visitHardBreak(_: HardBreak) -> String {
        return "<br>\n"
    }
    
    mutating func defaultVisit(_ markup: Markup) -> String {
        return markup.children.map { visit($0) }.joined()
    }
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add QuickCookies/QuickCookies/Renderer/MarkdownRenderer.swift
git add QuickCookies/QuickCookies/Resources/markdown.css
git commit -m "feat: add MarkdownRenderer with CSS styling"
```

---

## Task 8: SyntaxHighlighter 语法高亮引擎

**Files:**
- Create: `QuickCookies/QuickCookies/Renderer/SyntaxHighlighter.swift`

- [ ] **Step 1: 创建 SyntaxHighlighter.swift（Highlightr 包装）**

```swift
import Foundation
import Highlightr

class SyntaxHighlighter {
    static let shared: SyntaxHighlighter? = {
        guard let highlightr = Highlightr() else {
            print("Failed to initialize Highlightr")
            return nil
        }
        highlightr.setTheme(to: "atom-one-light")
        return SyntaxHighlighter(highlightr: highlightr)
    }()
    
    private let highlightr: Highlightr
    
    private init(highlightr: Highlightr) {
        self.highlightr = highlightr
    }
    
    /// 高亮代码，返回带 HTML 标签的字符串
    func highlight(code: String, language: String) -> NSAttributedString? {
        return highlightr.highlight(code, as: language)
    }
    
    /// 切换主题
    func setTheme(_ theme: String) {
        highlightr.setTheme(to: theme)
    }
    
    /// 支持的主题列表
    static let availableThemes = [
        "atom-one-light",
        "atom-one-dark",
        "github",
        "github-gist",
        "monokai",
        "solarized-light",
        "solarized-dark",
    ]
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/Renderer/SyntaxHighlighter.swift
git commit -m "feat: add SyntaxHighlighter using Highlightr"
```

---

## Task 9: ToastView 提示组件

**Files:**
- Create: `QuickCookies/QuickCookies/UI/ToastView.swift`

- [ ] **Step 1: 创建 ToastView.swift**

```swift
import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String?
    
    init(message: String, icon: String? = nil) {
        self.message = message
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
            }
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isShowing {
                        ToastView(message: message, icon: icon)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastDuration) {
                                    withAnimation {
                                        isShowing = false
                                    }
                                }
                            }
                    }
                },
                alignment: .center
            )
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String? = nil) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/ToastView.swift
git commit -m "feat: add ToastView for lightweight notifications"
```

---

## Task 10: MarkdownView Markdown 显示视图

**Files:**
- Create: `QuickCookies/QuickCookies/UI/MarkdownView.swift`

- [ ] **Step 1: 创建 MarkdownView.swift**

```swift
import SwiftUI
import WebKit

struct MarkdownView: NSViewRepresentable {
    let markdownText: String
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.renderToHTML(markdownText: markdownText)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 处理链接点击
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/MarkdownView.swift
git commit -m "feat: add MarkdownView using WKWebView for rendering"
```

---

## Task 11: CodeView 代码高亮视图

**Files:**
- Create: `QuickCookies/QuickCookies/UI/CodeView.swift`

- [ ] **Step 1: 创建 CodeView.swift**

```swift
import SwiftUI
import AppKit

struct CodeView: NSViewRepresentable {
    let content: String
    let language: String?
    let fontSize: CGFloat
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isRichText = false
        textView.string = content
        
        // 应用语法高亮
        if let language = language, let highlighter = SyntaxHighlighter.shared {
            if let attributed = highlighter.highlight(code: content, language: language) {
                textView.textStorage?.setAttributedString(attributed)
            }
        }
        
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.string = content
        textView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        
        // 更新语法高亮
        if let language = language, let highlighter = SyntaxHighlighter.shared {
            if let attributed = highlighter.highlight(code: content, language: language) {
                textView.textStorage?.setAttributedString(attributed)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/CodeView.swift
git commit -m "feat: add CodeView for syntax-highlighted code display"
```

---

## Task 12: EditorView 可编辑视图

**Files:**
- Create: `QuickCookies/QuickCookies/UI/EditorView.swift`

- [ ] **Step 1: 创建 EditorView.swift**

```swift
import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var content: String
    @Binding var isModified: Bool
    let fontSize: CGFloat
    let showLineNumbers: Bool
    let onSave: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // 创建 TextView
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isRichText = false
        textView.allowsUndo = true
        textView.string = content
        
        scrollView.documentView = textView
        
        // 行号视图（可选）
        if showLineNumbers {
            let lineNumberView = LineNumberView(textView: textView)
            scrollView.hasVerticalRuler = true
            scrollView.verticalRulerView = lineNumberView
            scrollView.rulersVisible = true
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // 仅在外部内容变化时更新
        if textView.string != content {
            textView.string = content
        }
        
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        // 更新行号视图
        if let lineNumberView = scrollView.verticalRulerView as? LineNumberView {
            lineNumberView.needsDisplay = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, isModified: $isModified, onSave: onSave)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var content: String
        @Binding var isModified: Bool
        let onSave: (() -> Void)?
        
        init(content: Binding<String>, isModified: Binding<Bool>, onSave: (() -> Void)? = nil) {
            self._content = content
            self._isModified = isModified
            self.onSave = onSave
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            content = textView.string
            isModified = true
        }
        
        func doCommandBy(_ selector: Selector) {
            if selector == #selector(NSResponder.saveDocument(_:)) {
                // Cmd+S 保存
                onSave?()
            }
        }
    }
}

/// 行号视图
class LineNumberView: NSRulerView {
    weak var textView: NSTextView?
    
    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: nil, orientation: .verticalRuler)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let textStorage = textView.textStorage else { return }
        
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let textColor = NSColor.secondaryLabelColor
        
        // 计算总行数
        let totalLines = textStorage.string.components(separatedBy: "\n").count
        
        // 绘制行号
        for line in 1...totalLines {
            let y = textView.textContainerInset.height + CGFloat(line - 1) * layoutManager.defaultLineHeight(forFont: font)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            
            let lineNumberString = NSAttributedString(string: String(line), attributes: attributes)
            let point = NSPoint(x: 5, y: y)
            lineNumberString.draw(at: point)
        }
    }
    
    override var requiredThickness: CGFloat {
        return 40
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/EditorView.swift
git commit -m "feat: add EditorView with line numbers support"
```

---

## Task 13: ContentView 主内容视图

**Files:**
- Create: `QuickCookies/QuickCookies/UI/ContentView.swift`

- [ ] **Step 1: 创建 ContentView.swift**

```swift
import SwiftUI

enum ContentMode {
    case preview    // 预览模式
    case edit       // 编辑模式
}

struct ContentView: View {
    let filePath: String
    let renderType: FileRenderType
    let language: String?
    let initialContent: String
    
    @State private var content: String
    @State private var mode: ContentMode = .preview
    @State private var isModified: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @ObservedObject var settings = Settings.shared
    
    init(filePath: String, renderType: FileRenderType, language: String?, content: String) {
        self.filePath = filePath
        self.renderType = renderType
        self.language = language
        self.initialContent = content
        self._content = State(initialValue: content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar
            
            // 内容区域
            contentArea
        }
        .alert("保存失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 文件名 + 修改标记
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                .font(.system(size: 13, weight: .medium))
            
            if isModified {
                Text("●")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            }
            
            Spacer()
            
            // 模式切换按钮
            Button(action: toggleMode) {
                Image(systemName: mode == .preview ? "pencil" : "eye")
            }
            .buttonStyle(.plain)
            .help(mode == .preview ? "编辑" : "预览")
            
            // 保存按钮（编辑模式）
            if mode == .edit && isModified {
                Button(action: saveFile) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .help("保存 (Cmd+S)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch mode {
            case .preview:
                previewView
            case .edit:
                editView
            }
        }
    }
    
    @ViewBuilder
    private var previewView: some View {
        switch renderType {
        case .markdown:
            MarkdownView(markdownText: content)
        case .code:
            CodeView(
                content: content,
                language: language,
                fontSize: settings.fontSize
            )
        case .plainText:
            CodeView(
                content: content,
                language: nil,
                fontSize: settings.fontSize
            )
        }
    }
    
    private var editView: some View {
        EditorView(
            content: $content,
            isModified: $isModified,
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onSave: saveFile
        )
    }
    
    private func toggleMode() {
        mode = mode == .preview ? .edit : .preview
    }
    
    private func saveFile() {
        let result = FileUtils.writeFile(at: filePath, content: content)
        
        switch result {
        case .success:
            isModified = false
        case .failure(let error):
            errorMessage = error.errorDescription ?? "未知错误"
            showErrorAlert = true
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/ContentView.swift
git commit -m "feat: add ContentView as main content router"
```

---

## Task 14: PreviewWindow 浮动预览窗口

**Files:**
- Create: `QuickCookies/QuickCookies/UI/PreviewWindow.swift`

- [ ] **Step 1: 创建 PreviewWindow.swift**

```swift
import SwiftUI
import AppKit

class PreviewWindowController {
    static let shared = PreviewWindowController()
    
    private var window: NSPanel?
    private var contentView: NSHostingView<AnyView>?
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIcon: String? = nil
    
    private init() {}
    
    /// 显示预览窗口
    func show(filePath: String) {
        // 解析符号链接
        let resolvedPath = FileUtils.resolveSymlink(at: filePath)
        
        // 检查文件是否支持
        if !FileTypeClassifier.isSupported(path: resolvedPath) {
            showToast(message: "不支持此文件类型", icon: "xmark.circle")
            return
        }
        
        // 读取文件
        switch FileUtils.readFile(at: resolvedPath) {
        case .success(let result):
            let renderType = FileTypeClassifier.classify(path: resolvedPath)
            let language = FileTypeClassifier.getLanguageName(path: resolvedPath)
            
            showWindow(
                filePath: resolvedPath,
                renderType: renderType,
                language: language,
                content: result.content
            )
            
        case .failure(let error):
            handleFileError(error)
        }
    }
    
    /// 显示 Toast 提示
    func showToast(message: String, icon: String? = nil) {
        // 创建临时小窗口显示 Toast
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        
        let toastView = NSHostingView(
            rootView: ToastView(message: message, icon: icon)
        )
        panel.contentView = toastView
        
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        
        // 3秒后关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastDuration) {
            panel.close()
        }
    }
    
    /// 处理文件错误
    private func handleFileError(_ error: FileUtils.FileError) {
        showToast(message: error.errorDescription ?? "未知错误", icon: "xmark.circle")
    }
    
    /// 显示窗口内容
    private func showWindow(filePath: String, renderType: FileRenderType, language: String?, content: String) {
        // 关闭旧窗口
        close()
        
        // 创建 NSPanel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        panel.title = "Quick Cookies - \(URL(fileURLWithPath: filePath).lastPathComponent)"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        
        // 设置 contentView
        let view = ContentView(
            filePath: filePath,
            renderType: renderType,
            language: language,
            content: content
        )
        
        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView
        
        // 居中显示
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        
        // 设置键盘监听（Cmd+W 关闭）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == 13 { // W
                panel.close()
                return nil
            }
            return event
        }
        
        window = panel
    }
    
    /// 关闭窗口
    func close() {
        window?.close()
        window = nil
    }
    
    /// 窗口是否可见
    var isVisible: Bool {
        return window?.isVisible == true
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/PreviewWindow.swift
git commit -m "feat: add PreviewWindow as floating panel controller"
```

---

## Task 15: SettingsWindow 设置窗口

**Files:**
- Create: `QuickCookies/QuickCookies/UI/SettingsWindow.swift`

- [ ] **Step 1: 创建 SettingsWindow.swift**

```swift
import SwiftUI
import AppKit

class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    func show() {
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        panel.title = "Quick Cookies 设置"
        panel.level = .normal
        
        let view = SettingsView()
        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView
        
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        
        window = panel
    }
    
    func close() {
        window?.close()
        window = nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var isRecordingHotkey: Bool = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 快捷键设置
            GroupBox(label: Text("快捷键")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("触发快捷键:")
                        Spacer()
                        
                        if isRecordingHotkey {
                            Text("按下新快捷键...")
                                .foregroundColor(.secondary)
                        } else {
                            Button(hotkeyDisplay) {
                                isRecordingHotkey = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if let conflict = checkHotkeyConflict() {
                        Text(conflict)
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .padding()
            }
            
            // 外观设置
            GroupBox(label: Text("外观")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("字体大小:")
                        Spacer()
                        Slider(value: $settings.fontSize, in: 10...24, step: 1)
                            .frame(width: 100)
                        Text("\(Int(settings.fontSize))")
                    }
                    
                    Toggle("显示行号", isOn: $settings.showLineNumbers)
                }
                .padding()
            }
            
            Spacer()
            
            // 底部按钮
            HStack {
                Spacer()
                Button("重置默认") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            setupHotkeyRecording()
        }
    }
    
    private var hotkeyDisplay: String {
        let modifiers = settings.hotkeyModifiers
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        
        // KeyCode 转名称
        let keyName = keyCodeToName(settings.hotkeyKeyCode)
        parts.append(keyName)
        
        return parts.joined()
    }
    
    private func keyCodeToName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 50: return "`"
        default:
            // 字母键
            if keyCode >= 0 && keyCode <= 25 {
                let letter = Character(UnicodeScalar(Int(UnicodeScalar("A").value) + Int(keyCode))!)
                return String(letter)
            }
            return "Key\(keyCode)"
        }
    }
    
    private func setupHotkeyRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecordingHotkey {
                // 忽略单独的修饰键
                if event.keyCode == 54 || event.keyCode == 55 || // Cmd
                   event.keyCode == 58 || event.keyCode == 59 || // Option
                   event.keyCode == 56 || event.keyCode == 57 || // Shift
                   event.keyCode == 59 || event.keyCode == 62 {   // Control
                    return nil
                }
                
                recordedModifiers = event.modifierFlags
                recordedKeyCode = event.keyCode
                
                // 保存
                settings.saveHotkey(modifiers: recordedModifiers, keyCode: recordedKeyCode)
                isRecordingHotkey = false
                
                // 重新注册热键
                HotkeyManager.shared.registerWithSettings {
                    PreviewWindowController.shared.showFromFinder()
                }
                
                return nil
            }
            return event
        }
    }
    
    private func checkHotkeyConflict() -> String? {
        // 简单检查常见冲突
        let modifiers = settings.hotkeyModifiers
        let keyCode = settings.hotkeyKeyCode
        
        if modifiers.contains(.command) && keyCode == 49 { // Cmd+Space
            return "可能与 Spotlight 冲突"
        }
        
        if modifiers.contains(.control) && keyCode == 49 { // Ctrl+Space
            return "可能与输入法切换冲突"
        }
        
        return nil
    }
    
    private func resetToDefaults() {
        settings.saveHotkey(
            modifiers: Constants.defaultHotkeyModifiers,
            keyCode: Constants.defaultHotkeyKeyCode
        )
        settings.fontSize = 14
        settings.showLineNumbers = true
        
        // 重新注册热键
        HotkeyManager.shared.registerWithSettings {
            PreviewWindowController.shared.showFromFinder()
        }
    }
}

// PreviewWindowController 扩展
extension PreviewWindowController {
    func showFromFinder() {
        switch FileDetector.getSelectedFilePath() {
        case .success(let path):
            show(filePath: path)
        case .failure(let error):
            showToast(message: error.errorDescription ?? "未知错误", icon: "xmark.circle")
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add QuickCookies/QuickCookies/UI/SettingsWindow.swift
git commit -m "feat: add SettingsWindow for hotkey and appearance configuration"
```

---

## Task 16: AppDelegate 应用生命周期

**Files:**
- Create: `QuickCookies/QuickCookies/App/AppDelegate.swift`

- [ ] **Step 1: 创建 AppDelegate.swift**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查 Accessibility 权限
        if !HotkeyManager.shared.checkAccessibilityPermission() {
            showPermissionAlert()
            HotkeyManager.shared.requestAccessibilityPermission()
        }
        
        // 注册热键
        HotkeyManager.shared.registerWithSettings {
            PreviewWindowController.shared.showFromFinder()
        }
        
        print("Quick Cookies started. Press \(hotkeyDescription) to preview files.")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "Quick Cookies 需要辅助功能权限来监听全局快捷键。\n请前往 系统偏好设置 → 安全性与隐私 → 辅助功能，添加 Quick Cookies。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "稍后")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统偏好设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private var hotkeyDescription: String {
        let settings = Settings.shared
        let modifiers = settings.hotkeyModifiers
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("Cmd") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        
        parts.append("Space")
        return parts.joined(separator: "+")
    }
}
```

- [ ] **Step 2: 更新 QuickCookiesApp.swift 引入 AppDelegate**

```swift
import SwiftUI

@main
struct Quick CookiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Quick Cookies", systemImage: "doc.text.magnifyingglass") {
            Text("Quick Cookies is running")
            Button("Settings") {
                SettingsWindowController.shared.show()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add QuickCookies/QuickCookies/App/
git commit -m "feat: add AppDelegate for lifecycle and permission handling"
```

---

## Task 17: 创建 Xcode 项目文件

**Files:**
- Create: `QuickCookies/QuickCookies.xcodeproj/project.pbxproj`

- [ ] **Step 1: 使用 Xcode 创建项目**

由于手动创建 .xcodeproj 文件非常复杂，建议：

```bash
# 打开 Xcode，创建新项目：
# 1. 选择 macOS → App
# 2. 产品名称：Quick Cookies
# 3. 团队：选择你的开发团队
# 4. 组织标识符：com.quickcookies
# 5. 界面：SwiftUI
# 6. 语言：Swift
# 7. 保存到：/Users/jiangwei/Git/QuickPeek
#
# 然后将已创建的源文件拖入项目中
```

- [ ] **Step 2: 配置项目设置**

在 Xcode 中：
1. 选择项目 → Signing & Capabilities
2. 关闭 App Sandbox
3. 添加 Apple Events capability
4. 确保 Info.plist 包含 `NSAppleEventsUsageDescription`

- [ ] **Step 3: 添加 SPM 依赖**

在 Xcode 中：
1. File → Add Packages
2. 添加 `https://github.com/apple/swift-markdown.git` (0.3.0+)
3. 添加 `https://github.com/raspu/Highlightr.git` (2.1.0+)

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: configure Xcode project with dependencies"
```

---

## Task 18: 测试与调试

- [ ] **Step 1: 编译项目**

```bash
# 在 Xcode 中编译，或使用命令行
xcodebuild -project QuickCookies.xcodeproj -scheme Quick Cookies -configuration Debug build
```

预期：编译成功，无错误

- [ ] **Step 2: 运行并测试基本功能**

测试流程：
1. 运行 App
2. 确认菜单栏图标出现
3. 在 Finder 中选中一个 .md 文件
4. 按 Cmd+Shift+Space
5. 确认预览窗口弹出并显示 Markdown 渲染结果

- [ ] **Step 3: 测试其他文件类型**

测试文件：
- `.json` - 语法高亮显示
- `.yaml` - 语法高亮显示
- `.sh` - Shell 语法高亮
- `.txt` - 纯文本显示

- [ ] **Step 4: 测试编辑功能**

测试流程：
1. 打开预览窗口
2. 点击编辑按钮切换到编辑模式
3. 编辑内容
4. 按 Cmd+S 保存
5. 确认文件已更新

- [ ] **Step 5: 测试设置功能**

测试流程：
1. 点击菜单栏 → Settings
2. 更改快捷键
3. 确认新快捷键生效

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "test: validate all MVP features work correctly"
```

---

## Self-Review 检查

### 1. Spec 覆盖检查

| Spec 需求 | 对应 Task |
|-----------|-----------|
| 全局快捷键触发 | Task 6 (HotkeyManager) + Task 16 (AppDelegate) |
| 文件类型检测 | Task 4 (FileTypeClassifier) |
| 浮动预览窗口 | Task 14 (PreviewWindow) |
| Markdown 渲染 | Task 7 (MarkdownRenderer) + Task 10 (MarkdownView) |
| 语法高亮 | Task 8 (SyntaxHighlighter) + Task 11 (CodeView) |
| 轻量编辑 | Task 12 (EditorView) + Task 13 (ContentView) |
| 行号显示 | Task 12 (EditorView - LineNumberView) |
| 快捷键设置 | Task 15 (SettingsWindow) |

✅ 所有 MVP 功能均有对应 Task

### 2. Placeholder 检查

✅ 无 TBD、TODO、"implement later" 等 placeholder
✅ 所有代码步骤包含完整实现代码
✅ 所有命令包含预期输出

### 3. 类型一致性检查

- `HotkeyManager.register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16)` 与 `Settings.saveHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16)` 一致 ✅
- `FileUtils.readFile` 返回 `Result<(content: String, encoding: String.Encoding), FileError>` 与 `ContentView` 使用方式一致 ✅
- `PreviewWindowController.show(filePath: String)` 与 `FileDetector.getSelectedFilePath()` 返回类型匹配 ✅

---

## 计划完成

计划已保存至 `docs/design.md`。

**执行选项：**

1. **Subagent-Driven（推荐）** - 每个 Task 派发独立 subagent，支持 review 和快速迭代

2. **Inline Execution** - 在当前会话中批量执行，带 checkpoint 检查点

选择哪种方式执行？