import Foundation
import Combine
import AppKit
import ServiceManagement

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light".localized()
        case .dark: return "Dark".localized()
        case .system: return "System".localized()
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case zhHans = "zhHans"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Follow System".localized()
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()
    
    // 备份当前语言以供本地化无警报访问
    static var currentLanguage: Language = .en

    private let defaults = UserDefaults.standard

    // 快捷键配置
    @Published var hotkeyModifiers: NSEvent.ModifierFlags
    @Published var hotkeyKeyCode: UInt16
    @Published var clipboardHotkeyModifiers: NSEvent.ModifierFlags
    @Published var clipboardHotkeyKeyCode: UInt16
    @Published var shareCardHotkeyModifiers: NSEvent.ModifierFlags
    @Published var shareCardHotkeyKeyCode: UInt16

    // 外观配置
    @Published var fontSize: CGFloat
    @Published var themeMode: ThemeMode {
        didSet {
            defaults.set(themeMode.rawValue, forKey: Keys.themeMode)
            NotificationCenter.default.post(name: .settingsThemeModeDidChange, object: self)
        }
    }
    
    // 多语言配置
    @Published var language: Language {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            Settings.currentLanguage = (language == Language.system) ? Settings.getSystemLanguage() : language
            NotificationCenter.default.post(name: .settingsLanguageDidChange, object: self)
        }
    }

    static func getSystemLanguage() -> Language {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .zhHans
        } else {
            return .en
        }
    }

    // 编辑器字体
    @Published var editorFont: String {
        didSet {
            defaults.set(editorFont, forKey: Keys.editorFont)
        }
    }

    // 开机自启动
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            syncLaunchAtLogin()
        }
    }

    private init() {
        // 先初始化所有 stored properties（使用默认值）
        hotkeyModifiers = Constants.defaultHotkeyModifiers
        hotkeyKeyCode = Constants.defaultHotkeyKeyCode
        clipboardHotkeyModifiers = Constants.defaultClipboardHotkeyModifiers
        clipboardHotkeyKeyCode = Constants.defaultClipboardHotkeyKeyCode
        shareCardHotkeyModifiers = Constants.defaultShareCardHotkeyModifiers
        shareCardHotkeyKeyCode = Constants.defaultShareCardHotkeyKeyCode
        fontSize = 13
        themeMode = .system
        language = Language.system
        Settings.currentLanguage = Settings.getSystemLanguage()
        editorFont = "JetBrains Mono"
        launchAtLogin = false

        // 然后从 UserDefaults 加载实际值
        loadFromUserDefaults()
    }

    private func loadFromUserDefaults() {
        // 快捷键
        if defaults.hasKey(Keys.hotkeyModifiers) {
            hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        }

        if defaults.hasKey(Keys.hotkeyKeyCode) {
            hotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
        }

        if defaults.hasKey(Keys.clipboardHotkeyModifiers) {
            clipboardHotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UInt(defaults.integer(forKey: Keys.clipboardHotkeyModifiers))
            )
        }

        if defaults.hasKey(Keys.clipboardHotkeyKeyCode) {
            clipboardHotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.clipboardHotkeyKeyCode))
        }

        if defaults.hasKey(Keys.shareCardHotkeyModifiers) {
            shareCardHotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UInt(defaults.integer(forKey: Keys.shareCardHotkeyModifiers))
            )
        }

        if defaults.hasKey(Keys.shareCardHotkeyKeyCode) {
            shareCardHotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.shareCardHotkeyKeyCode))
        }

        // 外观
        let savedFontSize = CGFloat(defaults.float(forKey: Keys.fontSize))
        if savedFontSize != 0 {
            fontSize = savedFontSize
        }

        if let savedTheme = defaults.string(forKey: Keys.themeMode),
           let mode = ThemeMode(rawValue: savedTheme) {
            themeMode = mode
        } else {
            themeMode = .system
        }
        
        // 语言加载与自适应
        if let savedLang = defaults.string(forKey: Keys.language),
           let lang = Language(rawValue: savedLang) {
            language = lang
        } else {
            language = Language.system
        }
        Settings.currentLanguage = (language == Language.system) ? Settings.getSystemLanguage() : language

        // 编辑器字体
        if let savedFont = defaults.string(forKey: Keys.editorFont) {
            editorFont = savedFont
        }

        // 自启动
        if defaults.hasKey(Keys.launchAtLogin) {
            launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        }
    }

    func saveHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        hotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        defaults.set(modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(Int(keyCode), forKey: Keys.hotkeyKeyCode)
        NotificationCenter.default.post(name: .settingsHotkeyDidChange, object: self)
    }

    func saveClipboardHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        clipboardHotkeyModifiers = modifiers
        clipboardHotkeyKeyCode = keyCode
        defaults.set(modifiers.rawValue, forKey: Keys.clipboardHotkeyModifiers)
        defaults.set(Int(keyCode), forKey: Keys.clipboardHotkeyKeyCode)
        NotificationCenter.default.post(name: .settingsClipboardHotkeyDidChange, object: self)
    }

    func saveShareCardHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        shareCardHotkeyModifiers = modifiers
        shareCardHotkeyKeyCode = keyCode
        defaults.set(modifiers.rawValue, forKey: Keys.shareCardHotkeyModifiers)
        defaults.set(Int(keyCode), forKey: Keys.shareCardHotkeyKeyCode)
        NotificationCenter.default.post(name: .settingsShareCardHotkeyDidChange, object: self)
    }

    func saveFontSize(_ size: CGFloat) {
        fontSize = size
        defaults.set(Float(size), forKey: Keys.fontSize)
    }

    private func syncLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // Keep launch-at-login failures silent here; UI can decide if user-facing feedback is needed.
            _ = error
        }
    }

    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let clipboardHotkeyModifiers = "clipboardHotkeyModifiers"
        static let clipboardHotkeyKeyCode = "clipboardHotkeyKeyCode"
        static let shareCardHotkeyModifiers = "shareCardHotkeyModifiers"
        static let shareCardHotkeyKeyCode = "shareCardHotkeyKeyCode"
        static let fontSize = "fontSize"
        static let themeMode = "themeMode"
        static let language = "language"
        static let editorFont = "editorFont"
        static let launchAtLogin = "launchAtLogin"
    }
}

extension UserDefaults {
    func hasKey(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

import SwiftUI

extension NSColor {
    /// 整体背景色：暗色下为极深灰色，亮色下为优雅淡灰白
    static let appBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        } else {
            return NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    })
    
    /// 正文文本颜色
    static let appText = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.85, alpha: 1.0)
        } else {
            return NSColor(white: 0.15, alpha: 1.0)
        }
    })
    
    /// 工具栏背景色
    static let toolbarBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        } else {
            return NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    })

    /// 卡片背景色：暗色下为暗灰，亮色下为纯白
    static let cardBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        } else {
            return NSColor(white: 1.0, alpha: 1.0)
        }
    })

    /// 边框细线颜色
    static let appBorder = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.20, alpha: 1.0)
        } else {
            return NSColor(white: 0.88, alpha: 1.0)
        }
    })

    /// 键帽/按钮背景色
    static let kbdBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
        } else {
            return NSColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        }
    })
}

extension Color {
    static let appBackground = Color(NSColor.appBackground)
    static let appText = Color(NSColor.appText)
    static let toolbarBackground = Color(NSColor.toolbarBackground)
    static let cardBackground = Color(NSColor.cardBackground)
    static let appBorder = Color(NSColor.appBorder)
    static let kbdBackground = Color(NSColor.kbdBackground)
}

struct Localization {
    static func translate(_ key: String, lang: Language) -> String {
        let dict: [String: [Language: String]] = [
            // Onboarding & Flow
            "Onboarding": [.en: "Onboarding", .zhHans: "新手向导"],
            "Next": [.en: "Next", .zhHans: "下一步"],
            "Back": [.en: "Back", .zhHans: "上一步"],
            "Start Using QuickCookies": [.en: "Start Using QuickCookies", .zhHans: "开始使用 QuickCookies"],
            "Skip": [.en: "Skip", .zhHans: "跳过"],
            "Skip Guide": [.en: "Skip Guide", .zhHans: "跳过向导"],
            "Continue": [.en: "Continue", .zhHans: "继续"],
            "Get Started": [.en: "Get Started", .zhHans: "开始使用"],
            "Let's go": [.en: "Get Started", .zhHans: "开始使用"],
            "Takes about a minute": [.en: "Takes about a minute · No extra permissions needed", .zhHans: "约需 1 分钟 · 无需额外系统权限"],
            "Takes about a minute · No extra permissions needed": [.en: "Takes about a minute · No extra permissions needed", .zhHans: "约需 1 分钟 · 无需额外系统权限"],
            "Welcome to QuickCookies": [.en: "Welcome to QuickCookies", .zhHans: "欢迎使用 QuickCookies"],
            "Instant card preview for your Finder files": [.en: "Fast, lightweight file previews for Finder", .zhHans: "在访达中快速预览各类文件"],
            "Fast, lightweight file previews for Finder": [.en: "Fast, lightweight file previews for Finder", .zhHans: "在访达中快速预览各类文件"],
            "Instant Card Preview for Finder": [.en: "Fast File Preview for Finder", .zhHans: "在访达中快速预览文件"],
            "Instant preview code, markdown, archives and documents without opening heavy apps.": [.en: "Preview code, markdown, archives, and documents instantly without opening heavy editors.", .zhHans: "无需打开大型编辑器，即刻预览代码、Markdown、压缩包与各类文档。"],
            
            // Hotkey & Practice
            "How would you like to open previews?": [.en: "How would you like to open previews?", .zhHans: "选择呼出预览的快捷键"],
            "How do you want to summon?": [.en: "How would you like to open previews?", .zhHans: "选择呼出预览的快捷键"],
            "Choose the shortcut to press in Finder.": [.en: "Choose the shortcut to press in Finder.", .zhHans: "在访达中连按快捷键即可快速呼出。"],
            "Choose the hotkey you press in Finder.": [.en: "Choose the shortcut to press in Finder.", .zhHans: "在访达中连按快捷键即可快速呼出。"],
            "Double Command": [.en: "Double Command", .zhHans: "双击 Command"],
            "Double Option": [.en: "Double Option", .zhHans: "双击 Option"],
            "Instant Search": [.en: "Instant Search", .zhHans: "即时查找"],
            "Double-press Command (Recommended)": [.en: "Double Command (Recommended)", .zhHans: "双击 Command (推荐)"],
            "Double-press Option": [.en: "Double Option", .zhHans: "双击 Option"],
            "Recommended": [.en: "Recommended", .zhHans: "推荐"],
            "Classic": [.en: "Classic", .zhHans: "经典"],
            "Double Command is recommended for natural macOS interaction.": [.en: "Double Command is recommended for natural macOS interaction.", .zhHans: "推荐双击 Command，符合 macOS 使用直觉且不易冲突。"],
            "Double Command is recommended for natural macOS muscle memory.": [.en: "Double Command is recommended for natural macOS interaction.", .zhHans: "推荐双击 Command，符合 macOS 使用直觉且不易冲突。"],
            "Press twice anywhere in Finder to trigger instant card preview.": [.en: "Press twice anywhere in Finder to open preview.", .zhHans: "在访达中连按两次快捷键即可快速呼出预览。"],
            "Try pressing twice on your keyboard now:": [.en: "Try pressing twice on your keyboard now:", .zhHans: "现在可在键盘上连按两次进行测试："],
            "Shortcut detected! Works perfectly.": [.en: "Shortcut detected! Works perfectly.", .zhHans: "连按成功！快捷键已生效"],
            "Triggered! Perfect muscle memory!": [.en: "Shortcut detected! Works perfectly.", .zhHans: "连按成功！快捷键已生效"],
            "Waiting for double-press...": [.en: "Waiting for shortcut...", .zhHans: "等待连按快捷键..."],
            "Interactive Hotkey Playground": [.en: "Shortcut Practice", .zhHans: "快捷键测试"],

            // Feature Showcase
            "What QuickCookies previews": [.en: "Supported File Previews", .zhHans: "支持丰富格式预览"],
            "What can QuickCookies do?": [.en: "Supported File Previews", .zhHans: "支持丰富格式预览"],
            "Preview files instantly without opening heavy editors.": [.en: "Preview files instantly without opening heavy editors.", .zhHans: "无需打开大型编辑器，即刻查看文件内容。"],
            "Instant preview without opening heavy apps.": [.en: "Preview files instantly without opening heavy editors.", .zhHans: "无需打开大型编辑器，即刻查看文件内容。"],
            "Superpower Showcase": [.en: "Feature Overview", .zhHans: "功能概览"],
            "Explore what QuickCookies can preview for you in Finder:": [.en: "See what QuickCookies can preview for you in Finder:", .zhHans: "了解 QuickCookies 在访达中支持的预览格式："],
            "Code & Config": [.en: "Code & Config", .zhHans: "代码与配置"],
            "Markdown Docs": [.en: "Markdown Docs", .zhHans: "Markdown 排版"],
            "Archive & Folders": [.en: "Archive & Folders", .zhHans: "归档与文件夹"],
            "App Relay": [.en: "External Editor", .zhHans: "外部编辑器接力"],
            "60+ Languages": [.en: "60+ Languages", .zhHans: "60+ 种语言"],
            "GitHub Typography": [.en: "GitHub Typography", .zhHans: "GitHub 排版"],
            "Instant Inspection": [.en: "Instant Inspection", .zhHans: "免解压直接浏览"],
            "0-Extract X-Ray": [.en: "Instant Inspection", .zhHans: "免解压直接浏览"],
            "Syntax highlighting for 60+ languages with line numbers & streaming highlight.": [.en: "Syntax highlighting for 60+ languages with line numbers and fast loading.", .zhHans: "支持 60+ 种代码与配置文件的语法高亮，配备行号与流畅加载。"],
            "GitHub-style typography with rounded tables, transparent background & local images.": [.en: "GitHub-style Markdown typography with tables and image preview.", .zhHans: "GitHub 风格排版，支持表格渲染与本地图片预览。"],
            "GitHub-style typography with rounded tables & images.": [.en: "GitHub-style typography with rounded tables and images.", .zhHans: "GitHub 风格排版，支持圆角表格与图片。"],
            "0-extract structure inspection, format size bar & collapsible directory tree.": [.en: "Inspect archive contents without extraction, with file tree and category stats.", .zhHans: "免解压直接浏览压缩包内容，支持折叠目录树与文件分类统计。"],
            "One-click handoff to VS Code, Cursor, Xcode or your favorite editors.": [.en: "Open files in VS Code, Cursor, Xcode, or your default editor at any time.", .zhHans: "支持随时在 VS Code、Cursor 或 Xcode 等编辑器中打开。"],
            "Open in External Editor": [.en: "Open in External Editor", .zhHans: "在外部编辑器中打开"],
            "Feature": [.en: "Feature", .zhHans: "功能"],
            "Status": [.en: "Status", .zhHans: "状态"],

            // CLI Tool
            "Command Line Tool (CLI)": [.en: "Command Line Tool (CLI)", .zhHans: "命令行工具 (CLI)"],
            "Preview files instantly from Terminal using 'qc <path>'.": [.en: "Preview files instantly from Terminal using 'qc <path>'.", .zhHans: "在终端中随时使用 'qc <path>' 秒开文件预览。"],
            "Installed": [.en: "Installed", .zhHans: "已安装"],
            "Install CLI Tool": [.en: "Install CLI Tool", .zhHans: "安装命令行工具"],
            "Reinstall CLI": [.en: "Reinstall CLI", .zhHans: "重新安装 CLI"],

            // Code Card Export & Clipboard Inspector
            "Share Code Card": [.en: "Share Code Card", .zhHans: "分享代码卡片"],
            "Share Card": [.en: "Share Card", .zhHans: "分享卡片"],
            "Text / Quote": [.en: "Text / Quote", .zhHans: "文本 / 引用"],
            "Cancel": [.en: "Cancel", .zhHans: "取消"],
            "Padding": [.en: "Padding", .zhHans: "边距"],
            "Aurora": [.en: "Aurora", .zhHans: "极光"],
            "Sunset": [.en: "Sunset", .zhHans: "加州日落"],
            "Ocean": [.en: "Ocean", .zhHans: "深邃海洋"],
            "Charcoal": [.en: "Charcoal", .zhHans: "黑曜石"],
            "Cyberpunk": [.en: "Cyberpunk", .zhHans: "赛博朋克"],
            "Cosmic": [.en: "Cosmic", .zhHans: "宇宙星云"],
            "Emerald": [.en: "Emerald", .zhHans: "薄荷祖母绿"],
            "Monochrome": [.en: "Monochrome", .zhHans: "黑白极简"],
            "Focused %d lines": [.en: "Focused %d lines", .zhHans: "已聚焦 %d 行"],
            "Focused 1 line": [.en: "Focused 1 line", .zhHans: "已聚焦 1 行"],
            "Clear Focus": [.en: "Clear Focus", .zhHans: "清空聚焦"],
            "Theme": [.en: "Theme", .zhHans: "背景主题"],
            "Line Numbers": [.en: "Line Numbers", .zhHans: "显示行号"],
            "Watermark": [.en: "Watermark", .zhHans: "品牌水印"],
            "Compact": [.en: "Compact", .zhHans: "紧凑"],
            "Regular": [.en: "Regular", .zhHans: "适中"],
            "Spacious": [.en: "Spacious", .zhHans: "舒展"],
            "Standard": [.en: "Standard", .zhHans: "标准"],
            "Wide": [.en: "Wide", .zhHans: "宽幅"],
            "Width": [.en: "Width", .zhHans: "卡片宽度"],
            "Copy Image (⌘C)": [.en: "Copy Image (⌘C)", .zhHans: "拷贝图片 (⌘C)"],
            "Save Image... (⌘S)": [.en: "Save Image... (⌘S)", .zhHans: "保存图片... (⌘S)"],
            "Copied card image to clipboard": [.en: "Copied card image to clipboard", .zhHans: "已拷贝卡片图片至剪贴板"],
            "Saved card image successfully": [.en: "Saved card image successfully", .zhHans: "卡片图片保存成功"],
            "Failed to copy image": [.en: "Failed to copy image", .zhHans: "拷贝卡片图片失败"],
            "Failed to render image": [.en: "Failed to render image", .zhHans: "渲染卡片失败"],
            "Auto": [.en: "Auto", .zhHans: "自适应"],
            "Aspect Ratio": [.en: "Aspect Ratio", .zhHans: "比例"],
            "Transparent": [.en: "Transparent", .zhHans: "透明底"],
            "Ambient Glow": [.en: "Ambient Glow", .zhHans: "微光辉光"],
            "Inspect Clipboard": [.en: "Inspect Clipboard", .zhHans: "透视剪贴板"],
            "Inspect clipboard content instantly": [.en: "Inspect clipboard content instantly", .zhHans: "一键预览剪贴板中的文本、代码或图片"],
            "Share as Card": [.en: "Share as Card", .zhHans: "分享为卡片"],
            "Directly preview and export as card": [.en: "Directly preview and export as card", .zhHans: "直接预览并导出精美代码卡片"],
            "Clipboard (%@)": [.en: "Clipboard (%@)", .zhHans: "剪贴板 (%@)"],
            "Clipboard (JSON)": [.en: "Clipboard (JSON)", .zhHans: "剪贴板 (JSON)"],
            "Clipboard (Markdown)": [.en: "Clipboard (Markdown)", .zhHans: "剪贴板 (Markdown)"],
            "Clipboard Image (PNG)": [.en: "Clipboard Image (PNG)", .zhHans: "剪贴板图片 (PNG)"],
            "Clipboard Text": [.en: "Clipboard Text", .zhHans: "剪贴板文本"],
            "Clipboard is empty": [.en: "Clipboard is empty", .zhHans: "剪贴板为空"],
            "Failed to read clipboard": [.en: "Failed to read clipboard", .zhHans: "读取剪贴板失败"],
            "Failed to save image: %@": [.en: "Failed to save image: %@", .zhHans: "保存卡片图片失败：%@"],

            // Ready & Personalize
            "You're all set": [.en: "You're all set", .zhHans: "一切就绪"],
            "QuickCookies is ready to preview files in Finder.": [.en: "QuickCookies is ready to preview files in Finder.", .zhHans: "QuickCookies 已准备就绪，随时在访达中为你预览。"],
            "QuickCookies is standing by in Finder.": [.en: "QuickCookies is ready to preview files in Finder.", .zhHans: "QuickCookies 已准备就绪，随时在访达中为你预览。"],
            "Privacy & Security": [.en: "Privacy & Security", .zhHans: "隐私与安全"],
            "Pure architecture": [.en: "Privacy & Security", .zhHans: "隐私与安全"],
            "Zero": [.en: "Zero", .zhHans: "0 门槛"],
            "Zero Accessibility privileges required. Safe, private, and lightweight.": [.en: "Zero Accessibility privileges required. Safe, private, and lightweight.", .zhHans: "完全无需辅助功能等敏感权限，保护隐私，安全轻量。"],
            "Accessibility privileges needed. Safe, private & instant.": [.en: "Zero Accessibility privileges required. Safe, private, and lightweight.", .zhHans: "完全无需辅助功能等敏感权限，保护隐私，安全轻量。"],
            "No Special Permissions Required": [.en: "No Special Permissions Required", .zhHans: "无需辅助功能权限"],
            "Zero-Accessibility Risk": [.en: "No Special Permissions Required", .zhHans: "无需辅助功能权限"],
            "Open at Login": [.en: "Open at Login", .zhHans: "登录时启动"],
            "Start at login": [.en: "Open at Login", .zhHans: "登录时启动"],
            "Available in the background right after you log in.": [.en: "Available in the background right after you log in.", .zhHans: "开机登录后自动在后台就绪。"],
            "Ready when you open your Mac.": [.en: "Available in the background right after you log in.", .zhHans: "开机登录后自动在后台就绪。"],
            "More Settings...": [.en: "More Settings...", .zhHans: "更多设置..."],
            "View settings >": [.en: "More Settings...", .zhHans: "更多设置..."],
            "Customize fonts, themes, and shortcuts.": [.en: "Customize fonts, themes, and shortcuts.", .zhHans: "自定义字体、外观主题与快捷键。"],
            "Fonts, theme and shortcuts.": [.en: "Customize fonts, themes, and shortcuts.", .zhHans: "自定义字体、外观主题与快捷键。"],
            "Start Exploring": [.en: "Start Using QuickCookies", .zhHans: "开始使用 QuickCookies"],
            "Start Exploring QuickCookies": [.en: "Start Using QuickCookies", .zhHans: "开始使用 QuickCookies"],
            "Ready & Personalize": [.en: "Ready to Use", .zhHans: "准备就绪与偏好"],
            "Zero-Permission Mode Ready": [.en: "Ready to Use Without Extra Permissions", .zhHans: "免敏感权限模式已就绪"],
            "QuickCookies core features run without any accessibility permissions.": [.en: "QuickCookies runs securely without requiring Accessibility privileges.", .zhHans: "QuickCookies 核心功能无需任何辅助功能权限，保护隐私，安全轻量。"],
            "Personalized Settings": [.en: "Personalized Settings", .zhHans: "个性化设置"],
            "Starting...": [.en: "Starting...", .zhHans: "正在启动..."],

            // System Permissions
            "Full Disk Access": [.en: "Full Disk Access", .zhHans: "完全磁盘访问权限"],
            "Grant Full Disk Access to eliminate sandbox popups": [.en: "Grant Full Disk Access to eliminate sandbox popups", .zhHans: "授权完全磁盘访问，避免系统沙盒授权弹窗"],
            "Grant Access": [.en: "Grant Access", .zhHans: "前往授权"],
            "Authorized": [.en: "Authorized", .zhHans: "已授权"],
            "Enable": [.en: "Enable", .zhHans: "前往启用"],
            "Attempted": [.en: "Attempted", .zhHans: "已尝试启用"],
            "Finder Extension": [.en: "Finder Extension", .zhHans: "访达扩展"],

            // Appearance & HIG
            "Appearance": [.en: "Appearance", .zhHans: "外观"],
            "Theme Mode": [.en: "Theme Mode", .zhHans: "外观主题"],
            "Choose your preferred display mode": [.en: "Choose your preferred appearance", .zhHans: "选择偏好的外观显示模式"],
            "Light": [.en: "Light", .zhHans: "浅色"],
            "Dark": [.en: "Dark", .zhHans: "深色"],
            "System": [.en: "System", .zhHans: "跟随系统"],
            "Colors": [.en: "Colors", .zhHans: "主题配色"],

            // Typography
            "Monospace font for previewing and editing": [.en: "Monospace font for previewing and editing", .zhHans: "用于预览与编辑的等宽字体"],
            "Font Size": [.en: "Font Size", .zhHans: "字体大小"],
            "System Default (Inter)": [.en: "System Default (Inter)", .zhHans: "系统默认 (Inter)"],
            "Typography Preview": [.en: "Typography Preview", .zhHans: "排版效果实时预览"],
            "Text": [.en: "Text", .zhHans: "文本与排版"],
            "Font": [.en: "Font", .zhHans: "字体"],
            "%@ glyphs": [.en: "%@ glyphs", .zhHans: "%@ 个字形"],

            // Shortcuts & Keybindings
            "KEYBINDINGS": [.en: "KEYBINDINGS", .zhHans: "快捷键"],
            "Keybindings": [.en: "Keybindings", .zhHans: "快捷键"],
            "Shortcuts": [.en: "Shortcuts", .zhHans: "快捷键"],
            "Global Preview": [.en: "Global Preview", .zhHans: "全局快捷键预览"],
            "Global Preview Hotkey": [.en: "Global Preview Hotkey", .zhHans: "全局唤起热键"],
            "GLOBAL HOTKEY": [.en: "GLOBAL HOTKEY", .zhHans: "全局唤起热键"],
            "Toggle overlay instantly when files are selected in Finder": [.en: "Toggle overlay instantly when files are selected in Finder", .zhHans: "在访达中选中文件后快速呼出或收起预览"],
            "Click keys on the right to record custom hotkey": [.en: "Click keys on the right to record custom hotkey", .zhHans: "点击右侧按键录制自定义快捷键"],
            "Press new shortcut keys...": [.en: "Press new shortcut keys...", .zhHans: "请在键盘上按下新快捷键..."],
            "Reset Hotkey": [.en: "Reset Hotkey", .zhHans: "恢复默认快捷键"],
            "Workflow Shortcuts": [.en: "Workflow Shortcuts", .zhHans: "常用操作快捷键"],
            "WORKFLOW SHORTCUTS": [.en: "WORKFLOW SHORTCUTS", .zhHans: "常用操作快捷键"],
            "Frequently used keystrokes in preview overlay": [.en: "Frequently used shortcuts in preview overlay", .zhHans: "预览浮层内的常用操作快捷键"],
            "Find in File": [.en: "Find in File", .zhHans: "在文件中查找"],
            "Search in text, code and Markdown": [.en: "Search in text, code and Markdown", .zhHans: "在代码、纯文本或 Markdown 中搜索"],
            "Previous / Next Match": [.en: "Previous / Next Match", .zhHans: "上一个 / 下一个匹配项"],
            "Jump between search results": [.en: "Jump between search results", .zhHans: "在搜索结果之间跳转"],
            "Find in file (⌥F)": [.en: "Find in file (⌥F)", .zhHans: "在文件中查找 (⌥F)"],
            "Find in file...": [.en: "Find in file...", .zhHans: "在文件中查找..."],
            "Previous Match (Shift+Enter)": [.en: "Previous Match (Shift+Enter)", .zhHans: "上一个匹配项 (Shift+Enter)"],
            "Next Match (Enter)": [.en: "Next Match (Enter)", .zhHans: "下一个匹配项 (Enter)"],
            "Go to Line": [.en: "Go to Line", .zhHans: "跳转到行"],
            "Jump to specific line number in code or text": [.en: "Jump to specific line number in code or text", .zhHans: "在代码或纯文本中快速跳转到指定行"],
            "Line number...": [.en: "Line number...", .zhHans: "输入行号..."],
            "Jump to Line (Enter)": [.en: "Jump to Line (Enter)", .zhHans: "跳转到该行 (Enter)"],
            "Invalid line number": [.en: "Invalid line number", .zhHans: "无效行号"],
            "Quick Telemetry Inspector (⌘I)": [.en: "Quick Telemetry Inspector (⌘I)", .zhHans: "工程元数据洞察 (⌘I)"],
            "Toggle engineering metadata telemetry bar": [.en: "Toggle engineering metadata telemetry bar", .zhHans: "呼出或收起工程元数据洞察微 HUD"],
            "Lines": [.en: "Lines", .zhHans: "行数"],
            "LoC": [.en: "LoC", .zhHans: "代码行"],
            "Comments": [.en: "Comments", .zhHans: "注释"],
            "Blank": [.en: "Blank", .zhHans: "空行"],
            "Format": [.en: "Format", .zhHans: "换行符"],
            "Encoding": [.en: "Encoding", .zhHans: "编码"],
            "Keys": [.en: "Keys", .zhHans: "键数"],
            "Items": [.en: "Items", .zhHans: "元素数"],
            "Depth": [.en: "Depth", .zhHans: "层级深度"],
            "Resolution": [.en: "Resolution", .zhHans: "物理分辨率"],
            "Scale": [.en: "Scale", .zhHans: "显示比例"],
            "Color Space": [.en: "Color Space", .zhHans: "色彩空间"],
            "Bit Depth": [.en: "Bit Depth", .zhHans: "位深"],
            "Alpha": [.en: "Alpha", .zhHans: "透明通道"],
            "Sample Rate": [.en: "Sample Rate", .zhHans: "采样率"],
            "Channels": [.en: "Channels", .zhHans: "声道"],
            "FPS": [.en: "FPS", .zhHans: "帧率"],
            "Analyzing...": [.en: "Analyzing...", .zhHans: "正在分析元数据..."],
            "No telemetry available": [.en: "No telemetry available", .zhHans: "暂无可用元数据"],
            "Copy Telemetry (⌘C)": [.en: "Copy Telemetry (⌘C)", .zhHans: "拷贝元数据 (⌘C)"],
            "Copied": [.en: "Copied", .zhHans: "已拷贝"],
            "Open with Default App": [.en: "Open with Default App", .zhHans: "用默认应用打开"],
            "Open current file in external editor": [.en: "Open current file in external editor", .zhHans: "在关联应用或外部专业编辑器中打开"],
            "Default": [.en: "Default", .zhHans: "默认"],
            "Reveal in Finder": [.en: "Reveal in Finder", .zhHans: "在访达中显示"],
            "Locate and highlight current file in Finder": [.en: "Locate and highlight current file in Finder", .zhHans: "在访达中定位并高亮当前文件"],
            "Copy File Path": [.en: "Copy File Path", .zhHans: "拷贝文件路径"],
            "Copy full path to clipboard": [.en: "Copy full path to clipboard", .zhHans: "将完整文件路径拷贝到剪贴板"],
            "Copy full physical path to clipboard": [.en: "Copy full path to clipboard", .zhHans: "将完整文件路径拷贝到剪贴板"],
            "Path Copied": [.en: "Path Copied", .zhHans: "已拷贝路径"],
            "Navigate Files in Finder": [.en: "Navigate Files in Finder", .zhHans: "在访达中切换浏览"],
            "Switch to previous or next file seamlessly": [.en: "Switch to previous or next file seamlessly", .zhHans: "向上或向下快速切换浏览文件"],
            "Navigate History": [.en: "Navigate History", .zhHans: "历史往复导航"],
            "Switch to previously previewed files": [.en: "Switch to previously previewed files", .zhHans: "在当前会话中往复切换已预览的文件"],
            "Back (⌘[)": [.en: "Back (⌘[)", .zhHans: "后退 (⌘[)"],
            "Forward (⌘])": [.en: "Forward (⌘])", .zhHans: "前进 (⌘])"],
            "Select a file in Finder to preview instantly": [.en: "Select a file in Finder to preview instantly", .zhHans: "在访达中选中文件后按快捷键快速预览"],
            "Preview Selection": [.en: "Preview Selection", .zhHans: "选中预览"],
            "Clipboard": [.en: "Clipboard", .zhHans: "剪贴板"],
            "Clipboard: %@ Code (Click to inspect)": [.en: "Clipboard: %@ Code (Click to inspect)", .zhHans: "剪贴板：%@ 代码（点击预览）"],
            "Clipboard: JSON Data (Click to inspect)": [.en: "Clipboard: JSON Data (Click to inspect)", .zhHans: "剪贴板：JSON 数据（点击预览）"],
            "Clipboard: Markdown (Click to inspect)": [.en: "Clipboard: Markdown (Click to inspect)", .zhHans: "剪贴板：Markdown（点击预览）"],
            "Clipboard: Image (Click to inspect)": [.en: "Clipboard: Image (Click to inspect)", .zhHans: "剪贴板：图片（点击预览）"],
            "Clipboard: Text (Click to inspect)": [.en: "Clipboard: Text (Click to inspect)", .zhHans: "剪贴板：文本内容（点击预览）"],
            "Clipboard: %@ (Click to inspect)": [.en: "Clipboard: %@ (Click to inspect)", .zhHans: "剪贴板：%@（点击预览）"],
            "Close Preview (Esc)": [.en: "Close Preview (Esc)", .zhHans: "关闭预览窗口 (Esc)"],
            "Dismiss Window": [.en: "Close Preview (Esc)", .zhHans: "关闭预览窗口 (Esc)"],
            "Close overlay and return focus to Finder": [.en: "Close preview overlay and return to Finder", .zhHans: "关闭预览浮层并返回访达"],
            "Close (Esc)": [.en: "Close (Esc)", .zhHans: "关闭 (Esc)"],

            // Settings Navigation & About
            "General": [.en: "General", .zhHans: "通用"],
            "Style": [.en: "Style", .zhHans: "外观排版"],
            "About": [.en: "About", .zhHans: "关于"],
            "Behavior": [.en: "Behavior", .zhHans: "运行行为"],
            "Permissions": [.en: "Permissions", .zhHans: "系统权限"],
            "Actions": [.en: "Actions", .zhHans: "操作与支持"],
            "License": [.en: "License", .zhHans: "开源许可"],
            "Reset": [.en: "Reset", .zhHans: "偏好重置"],
            "Restore Default Settings": [.en: "Restore Default Settings", .zhHans: "恢复默认设置"],
            "QuickCookies Ready": [.en: "QuickCookies Ready", .zhHans: "QuickCookies 已就绪"],
            "Running in Finder with zero high-risk privileges": [.en: "Running in Finder with zero high-risk privileges", .zhHans: "与访达紧密协同，无需高危系统权限"],
            "Press anywhere in Finder to preview files instantly": [.en: "Press shortcut in Finder to preview files instantly", .zhHans: "在访达中随时按下快捷键，即可快速预览"],
            "Instant Card Preview for macOS": [.en: "Instant Card Preview for macOS", .zhHans: "macOS 极速卡片文件预览工具"],
            "Zero-Accessibility Architecture": [.en: "Zero-Accessibility Architecture", .zhHans: "无需辅助功能权限的轻量架构"],
            "Architecture & Capabilities": [.en: "Architecture & Capabilities", .zhHans: "架构与特性"],
            "Fast Syntax Highlighting": [.en: "Fast Syntax Highlighting", .zhHans: "高效流式语法高亮"],
            "0ms Instant Streaming Highlight": [.en: "Fast Syntax Highlighting", .zhHans: "高效流式语法高亮"],
            "Seamless Editor Handoff": [.en: "Seamless Editor Handoff", .zhHans: "外部编辑器无缝接力"],
            "External App Seamless Handoff": [.en: "Seamless Editor Handoff", .zhHans: "外部编辑器无缝接力"],
            "Re-open Onboarding": [.en: "Re-open Onboarding", .zhHans: "重新打开新手引导向导"],
            "View on GitHub": [.en: "View on GitHub", .zhHans: "访问 GitHub 开源项目主页"],
            "Released under the MIT License": [.en: "Released under the MIT License", .zhHans: "基于 MIT 协议开源发布"],
            "Released under the GNU GPL v3 License": [.en: "Released under the GNU GPL v3 License", .zhHans: "基于 GNU GPL v3 协议开源发布"],
            
            // System & Menu
            "Automatically start QuickCookies in the background when you log in": [.en: "Automatically start QuickCookies in the background when you log in", .zhHans: "登录 macOS 系统时自动在后台启动 QuickCookies"],
            "Language": [.en: "Language", .zhHans: "语言"],
            "LANGUAGE": [.en: "LANGUAGE", .zhHans: "语言"],
            "Choose display language": [.en: "Choose display language", .zhHans: "选择界面的显示语言"],
            "Interface Language": [.en: "Interface Language", .zhHans: "界面语言"],
            "Open Selected File": [.en: "Open Selected File", .zhHans: "打开选中文件"],
            "Settings": [.en: "Settings", .zhHans: "设置"],
            "Quit": [.en: "Quit", .zhHans: "退出"],
            "Double-press Option or click here to open the selected Finder file": [.en: "Use the global preview hotkey or click here to open the selected Finder file", .zhHans: "使用全局预览快捷键，或点击此处打开访达选中的文件"],
            
            // Content View & Overlay Actions
            "Locating selected file in Finder...": [.en: "Locating selected file in Finder...", .zhHans: "正在定位访达选中的文件..."],
            "OK": [.en: "OK", .zhHans: "好"],
            "Failed to Get": [.en: "Failed to Get", .zhHans: "获取失败"],
            "Locating...": [.en: "Locating...", .zhHans: "定位中..."],
            "Size": [.en: "Size", .zhHans: "大小"],
            "Pos": [.en: "Pos", .zhHans: "位置"],
            "Unsupported file type": [.en: "Unsupported file type", .zhHans: "不支持的文件类型"],
            "Focused": [.en: "Focused", .zhHans: "已聚焦"],
            "Source": [.en: "Source", .zhHans: "来源"],
            "Unsupported file type (detail)": [.en: "Unsupported file type", .zhHans: "不支持此文件类型"],
            "Unsupported file format": [.en: "Unsupported file format", .zhHans: "不支持的文件格式"],
            "Vector Graphics (SVG)": [.en: "Vector Graphics (SVG)", .zhHans: "矢量图形 (SVG)"],
            "Reload": [.en: "Reload", .zhHans: "重新载入"],
            "Ignore": [.en: "Ignore", .zhHans: "忽略"],
            "Loading remaining content...": [.en: "Loading remaining content...", .zhHans: "正在载入后续内容..."],
            "Loading content...": [.en: "Loading content...", .zhHans: "正在载入内容..."],
            "PDF exported successfully": [.en: "PDF exported successfully", .zhHans: "PDF 导出成功"],
            "Export PDF": [.en: "Export PDF", .zhHans: "导出 PDF"],
            "Export": [.en: "Export", .zhHans: "导出"],
            "macOS version too low, PDF generation is not supported": [.en: "macOS version too low, PDF generation is not supported", .zhHans: "当前 macOS 版本过低，不支持生成 PDF"],
            
            // Archive Inspection
            "Analyzing archive contents...": [.en: "Analyzing archive contents...", .zhHans: "正在解析压缩包内容..."],
            "Empty Archive": [.en: "Empty Archive", .zhHans: "空压缩包"],
            "files": [.en: "files", .zhHans: "个文件"],
            "folders": [.en: "folders", .zhHans: "个文件夹"],
            "Archive file not found": [.en: "Archive file not found", .zhHans: "未找到压缩包文件"],
            "Unsupported archive format": [.en: "Unsupported archive format", .zhHans: "不支持的压缩包格式"],
            "Encrypted or corrupted archive": [.en: "Encrypted or corrupted archive", .zhHans: "压缩包受密码保护或文件已损坏"],
            "Subfile too large (%@)": [.en: "Subfile too large (%@)", .zhHans: "子文件过大（%@）"],
            "File '%@' not found in archive": [.en: "File '%@' not found in archive", .zhHans: "在压缩包中未找到文件“%@”"],
            "Code": [.en: "Code", .zhHans: "代码"],
            "Documents": [.en: "Documents", .zhHans: "文档"],
            "Images": [.en: "Images", .zhHans: "图片"],
            "Config": [.en: "Config", .zhHans: "配置"],
            "Other": [.en: "Other", .zhHans: "其他"],
            "Compression Ratio": [.en: "Compression Ratio", .zhHans: "压缩率"],
            "Name": [.en: "Name", .zhHans: "名称"],
            "Structure": [.en: "Structure", .zhHans: "结构"],
            "Tree": [.en: "Tree", .zhHans: "树形"],
            "Copy Value": [.en: "Copy Value", .zhHans: "拷贝值"],
            "Folder": [.en: "Folder", .zhHans: "文件夹"],
            "Scanning folder contents...": [.en: "Scanning folder contents...", .zhHans: "正在扫描文件夹内容..."],
            "Open in Terminal": [.en: "Open in Terminal", .zhHans: "在终端中打开"],
            "Open": [.en: "Open", .zhHans: "打开"],
            "Copy Path": [.en: "Copy Path", .zhHans: "拷贝路径"],
            "Copy Relative Path": [.en: "Copy Relative Path", .zhHans: "拷贝相对路径"],
            "Full Screen": [.en: "Full Screen", .zhHans: "全屏浏览"],
            "Exit Full Screen": [.en: "Exit Full Screen", .zhHans: "退出全屏"],
            "Visual Preview": [.en: "Visual Preview", .zhHans: "图形预览"],
            "Source Code": [.en: "Source Code", .zhHans: "源码模式"],
            "Preview": [.en: "Preview", .zhHans: "预览"],
            "Copy SVG Code": [.en: "Copy SVG Code", .zhHans: "拷贝 SVG 源码"],
            "SVG code copied to clipboard": [.en: "SVG code copied to clipboard", .zhHans: "SVG 源码已拷贝到剪贴板"],
            
            // Live Tail & Watching
            "Live Tail: Auto-scrolling (Click to pause)": [.en: "Live Tail: Auto-scrolling (Click to pause)", .zhHans: "实时追尾：自动跟随滚屏 (点击暂停)"],
            "Live Tail: Paused (Click to follow)": [.en: "Live Tail: Paused (Click to follow)", .zhHans: "实时追尾：已暂停 (点击恢复跟随)"],
            
            // Hex Inspector & Binary Inspection
            "OFFSET": [.en: "OFFSET", .zhHans: "偏移量"],
            "DECODED TEXT": [.en: "DECODED TEXT", .zhHans: "解码文本"],
            "Copy Hex String": [.en: "Copy Hex String", .zhHans: "拷贝十六进制字符串"],
            "Copy Decoded Text": [.en: "Copy Decoded Text", .zhHans: "拷贝解码文本"],
            "Copy Full Row": [.en: "Copy Full Row", .zhHans: "拷贝整行数据"],
            "Load More Bytes": [.en: "Load More Bytes", .zhHans: "加载更多字节"],
            "Inspect in Hex": [.en: "Inspect in Hex", .zhHans: "以十六进制检视"],
            "Summary": [.en: "Summary", .zhHans: "概览"]
        ]
        return dict[key]?[lang] ?? key
    }
}

extension String {
    func localized() -> String {
        return Localization.translate(self, lang: Settings.currentLanguage)
    }
}

extension NSFont {
    /// 获取指定名称的字体，若系统未安装则安全降级到系统默认等宽字体
    static func editorFont(name: String, size: CGFloat) -> NSFont {
        if name == "System Default (Inter)" {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        var targetName = name
        if name == "JetBrains Mono" {
            targetName = "JetBrainsMono-Regular"
        }
        if let font = NSFont(name: targetName, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
